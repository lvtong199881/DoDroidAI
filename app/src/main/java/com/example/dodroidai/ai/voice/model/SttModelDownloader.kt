package com.example.dodroidai.ai.voice.model

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * 下载语音模型（逐文件下载，带进度与大小校验）
 */
class SttModelDownloader(private val context: Context) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(600, TimeUnit.SECONDS)
        .writeTimeout(120, TimeUnit.SECONDS)
        .build()

    suspend fun download(
        model: SttModel,
        source: SttModelSource,
        onProgress: (downloadedBytes: Long, totalBytes: Long) -> Unit
    ) = withContext(Dispatchers.IO) {
        val repository = SttModelRepository(context)
        val dir = repository.modelDir(model)
        if (!dir.exists() && !dir.mkdirs()) {
            throw IOException("无法创建模型目录")
        }

        val total = model.totalBytes
        var completed = 0L
        for (file in model.files) {
            completed += downloadFile(dir, model, file, source, completed, total, onProgress)
        }
        Log.i(TAG, "模型下载完成: ${model.id}")
    }

    private fun downloadFile(
        dir: File,
        model: SttModel,
        file: SttModelFile,
        source: SttModelSource,
        completedBefore: Long,
        total: Long,
        onProgress: (Long, Long) -> Unit
    ): Long {
        val url = downloadUrl(source, model.repo, file.name)
        val part = File(dir, "${file.name}.part")
        if (part.exists()) part.delete()

        val request = Request.Builder().url(url).build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw IOException("HTTP ${response.code}: ${file.name}")
            }
            val body = response.body ?: throw IOException("响应为空: ${file.name}")

            body.byteStream().use { input ->
                FileOutputStream(part).use { output ->
                    val buffer = ByteArray(64 * 1024)
                    var downloaded = 0L
                    while (true) {
                        val read = input.read(buffer)
                        if (read <= 0) break
                        output.write(buffer, 0, read)
                        downloaded += read
                        onProgress(completedBefore + downloaded, total)
                    }
                }
            }
        }

        if (!SttModelRepository.sizeMatches(part.length(), file.sizeBytes)) {
            part.delete()
            throw IOException("文件大小不匹配: ${file.name}")
        }

        val target = File(dir, file.name)
        if (target.exists()) target.delete()
        if (!part.renameTo(target)) {
            part.delete()
            throw IOException("保存文件失败: ${file.name}")
        }
        return target.length()
    }

    companion object {
        private const val TAG = "SttModelDownloader"
    }
}
