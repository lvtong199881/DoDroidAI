package com.example.dodroidai.ai.attachments

/**
 * 附件编码结果。
 *
 * [rawBytes] 用于请求预算统计（图片为压缩后字节数，文本为 UTF-8 字节数）；
 * [cacheBytes] 用于内存缓存容量估算。
 */
sealed interface EncodedAttachment {

    val label: String
    val rawBytes: Long
    val cacheBytes: Int

    data class Image(
        override val label: String,
        val mediaType: String,
        val base64: String,
        override val rawBytes: Long
    ) : EncodedAttachment {
        override val cacheBytes: Int get() = base64.length
    }

    data class Text(
        override val label: String,
        val text: String,
        val truncated: Boolean,
        override val rawBytes: Long
    ) : EncodedAttachment {
        override val cacheBytes: Int get() = text.length
    }

    data class Placeholder(
        override val label: String,
        val reason: PlaceholderReason
    ) : EncodedAttachment {
        override val rawBytes: Long get() = 0L
        override val cacheBytes: Int get() = 0
    }
}

enum class PlaceholderReason(val description: String) {
    UNSUPPORTED_FORMAT("unsupported format"),
    TOO_LARGE("file too large"),
    UNREADABLE("cannot read file"),
    NO_TEXT("no extractable text"),
    VISION_DISABLED("image input disabled"),
    BUDGET_EXCEEDED("request attachment budget exceeded"),
    HISTORY_LIMIT("older attachment omitted")
}
