package com.example.dodroidai.ai.attachments

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.net.Uri
import android.util.Base64
import android.util.Log
import android.util.LruCache
import androidx.exifinterface.media.ExifInterface
import com.example.dodroidai.ai.model.AttachmentKind
import com.example.dodroidai.ai.model.ChatAttachment
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

/**
 * 把附件转换为可放进请求的内容。
 *
 * - 图片：解码、按 EXIF 纠正方向、缩放、压成 JPEG、base64。
 * - PDF：抽取文本层（不支持扫描件 OCR）。
 * - TXT：按 UTF-8 读取并截断。
 *
 * 所有失败都返回 [EncodedAttachment.Placeholder]，不抛异常给上层。
 */
class AttachmentEncoder(private val context: Context) {

    private val cache = object : LruCache<String, EncodedAttachment>(CACHE_MAX_BYTES) {
        override fun sizeOf(key: String, value: EncodedAttachment): Int = value.cacheBytes
    }

    suspend fun encode(attachment: ChatAttachment): EncodedAttachment = withContext(Dispatchers.IO) {
        val key = cacheKey(attachment)
        cache.get(key)?.let { return@withContext it }

        val result = try {
            when (attachment.kind) {
                AttachmentKind.IMAGE -> encodeImage(attachment)
                AttachmentKind.PDF -> encodePdf(attachment)
                AttachmentKind.TEXT -> encodeText(attachment)
                AttachmentKind.OTHER -> EncodedAttachment.Placeholder(
                    attachment.name,
                    PlaceholderReason.UNSUPPORTED_FORMAT
                )
            }
        } catch (e: OutOfMemoryError) {
            Log.w(TAG, "encode OOM: ${attachment.name}")
            EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.TOO_LARGE)
        } catch (e: Exception) {
            Log.w(TAG, "encode failed: ${attachment.name}", e)
            EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.UNREADABLE)
        }

        cache.put(key, result)
        result
    }

    private fun encodeImage(attachment: ChatAttachment): EncodedAttachment {
        val uri = Uri.parse(attachment.uri)
        val resolver = context.contentResolver

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        try {
            resolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, bounds)
            }
        } catch (e: Exception) {
            return EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.UNREADABLE)
        }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            return EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.UNREADABLE)
        }

        val options = BitmapFactory.Options().apply {
            inSampleSize = calculateInSampleSize(
                bounds.outWidth,
                bounds.outHeight,
                AttachmentLimits.MAX_IMAGE_DIMENSION
            )
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = (try {
            resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
        } catch (e: OutOfMemoryError) {
            null
        } catch (e: Exception) {
            null
        }) ?: return EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.UNREADABLE)

        var bitmap = decoded
        try {
            val orientation = readExifOrientation(uri)
            bitmap = applyOrientation(decoded, orientation)
            bitmap = scaleDown(bitmap, AttachmentLimits.MAX_IMAGE_DIMENSION)
            bitmap = flattenAlpha(bitmap)

            val jpeg = compressToJpeg(bitmap)
                ?: return EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.TOO_LARGE)
            val base64 = Base64.encodeToString(jpeg, Base64.NO_WRAP)
            return EncodedAttachment.Image(
                label = attachment.name,
                mediaType = "image/jpeg",
                base64 = base64,
                rawBytes = jpeg.size.toLong()
            )
        } finally {
            if (!bitmap.isRecycled) bitmap.recycle()
        }
    }

    private fun readExifOrientation(uri: Uri): Int {
        return try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                ExifInterface(input).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL
                )
            } ?: ExifInterface.ORIENTATION_NORMAL
        } catch (e: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }
    }

    private fun applyOrientation(source: Bitmap, orientation: Int): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(270f)
                matrix.postScale(-1f, 1f)
            }
            else -> return source
        }
        return try {
            Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
                .also { if (it !== source) source.recycle() }
        } catch (e: OutOfMemoryError) {
            source
        }
    }

    private fun scaleDown(source: Bitmap, maxDimension: Int): Bitmap {
        val maxSide = maxOf(source.width, source.height)
        if (maxSide <= maxDimension) return source
        val scale = maxDimension.toFloat() / maxSide
        val width = (source.width * scale).toInt().coerceAtLeast(1)
        val height = (source.height * scale).toInt().coerceAtLeast(1)
        return try {
            Bitmap.createScaledBitmap(source, width, height, true)
                .also { if (it !== source) source.recycle() }
        } catch (e: OutOfMemoryError) {
            source
        }
    }

    private fun flattenAlpha(source: Bitmap): Bitmap {
        if (!source.hasAlpha()) return source
        return try {
            val output = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(output)
            canvas.drawColor(Color.WHITE)
            canvas.drawBitmap(source, 0f, 0f, null)
            source.recycle()
            output
        } catch (e: OutOfMemoryError) {
            source
        }
    }

    private fun compressToJpeg(bitmap: Bitmap): ByteArray? {
        var quality = 85
        var bytes: ByteArray
        while (true) {
            val output = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, output)
            bytes = output.toByteArray()
            if (bytes.size <= AttachmentLimits.MAX_IMAGE_BYTES || quality <= 40) break
            quality -= 15
        }
        return if (bytes.size <= AttachmentLimits.MAX_IMAGE_BYTES) bytes else null
    }

    private fun encodePdf(attachment: ChatAttachment): EncodedAttachment {
        val uri = Uri.parse(attachment.uri)
        return try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                PDDocument.load(input).use { document ->
                    if (document.isEncrypted) {
                        return EncodedAttachment.Placeholder(
                            attachment.name,
                            PlaceholderReason.UNREADABLE
                        )
                    }
                    val stripper = PDFTextStripper().apply {
                        startPage = 1
                        endPage = minOf(document.numberOfPages, AttachmentLimits.MAX_PDF_PAGES)
                    }
                    val text = stripper.getText(document).trim()
                    if (text.isBlank()) {
                        return EncodedAttachment.Placeholder(
                            attachment.name,
                            PlaceholderReason.NO_TEXT
                        )
                    }
                    val truncated = text.length > AttachmentLimits.MAX_TEXT_CHARS
                    val kept = text.take(AttachmentLimits.MAX_TEXT_CHARS)
                    EncodedAttachment.Text(
                        label = attachment.name,
                        text = kept,
                        truncated = truncated,
                        rawBytes = kept.toByteArray(Charsets.UTF_8).size.toLong()
                    )
                }
            } ?: EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.UNREADABLE)
        } catch (e: OutOfMemoryError) {
            EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.TOO_LARGE)
        } catch (e: Exception) {
            Log.w(TAG, "pdf parse failed: ${attachment.name}", e)
            EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.UNREADABLE)
        }
    }

    private fun encodeText(attachment: ChatAttachment): EncodedAttachment {
        val uri = Uri.parse(attachment.uri)
        return try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                val reader = input.bufferedReader(Charsets.UTF_8)
                val buffer = CharArray(AttachmentLimits.MAX_TEXT_CHARS + 1)
                var read = 0
                while (read < buffer.size) {
                    val count = reader.read(buffer, read, buffer.size - read)
                    if (count < 0) break
                    read += count
                }
                if (read == 0) {
                    return EncodedAttachment.Placeholder(
                        attachment.name,
                        PlaceholderReason.NO_TEXT
                    )
                }
                val truncated = read > AttachmentLimits.MAX_TEXT_CHARS
                val kept = String(buffer, 0, minOf(read, AttachmentLimits.MAX_TEXT_CHARS))
                EncodedAttachment.Text(
                    label = attachment.name,
                    text = kept,
                    truncated = truncated,
                    rawBytes = kept.toByteArray(Charsets.UTF_8).size.toLong()
                )
            } ?: EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.UNREADABLE)
        } catch (e: Exception) {
            Log.w(TAG, "text read failed: ${attachment.name}", e)
            EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.UNREADABLE)
        }
    }

    private fun cacheKey(attachment: ChatAttachment): String =
        "${attachment.uri}|${attachment.size}|${attachment.name}"

    private fun calculateInSampleSize(width: Int, height: Int, maxDimension: Int): Int {
        var sampleSize = 1
        while (width / sampleSize > maxDimension || height / sampleSize > maxDimension) {
            sampleSize *= 2
        }
        return sampleSize
    }

    companion object {
        private const val TAG = "AttachmentEncoder"
        private const val CACHE_MAX_BYTES = 16 * 1024 * 1024
    }
}
