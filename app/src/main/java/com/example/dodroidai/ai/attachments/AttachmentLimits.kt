package com.example.dodroidai.ai.attachments

import com.example.dodroidai.ai.model.AttachmentKind
import com.example.dodroidai.ai.model.ChatAttachment

/**
 * 附件的硬性限制与格式判定。
 *
 * 数值参考 Anthropic Vision 约束（单图约 5 MB、单请求 32 MB），并留出余量。
 */
object AttachmentLimits {

    /** 单条消息最多附件数 */
    const val MAX_ATTACHMENTS_PER_MESSAGE = 5

    /** 图片压缩后的长边上限 */
    const val MAX_IMAGE_DIMENSION = 1568

    /** 单张图片压缩后的字节上限 */
    const val MAX_IMAGE_BYTES = 3 * 1024 * 1024

    /** 单条消息所有附件压缩后的字节上限 */
    const val MAX_MESSAGE_ATTACHMENT_BYTES = 8 * 1024 * 1024

    /** 一次请求所有消息附件压缩后的字节上限 */
    const val MAX_REQUEST_ATTACHMENT_BYTES = 12 * 1024 * 1024

    /** 允许添加的原始文件大小上限 */
    const val MAX_SOURCE_FILE_BYTES = 20L * 1024 * 1024

    /** PDF 最多抽取的页数 */
    const val MAX_PDF_PAGES = 30

    /** PDF/TXT 最多保留的字符数 */
    const val MAX_TEXT_CHARS = 50_000

    /** 参与附件编码的最近 user 消息条数 */
    const val ATTACHMENT_HISTORY_USER_MESSAGES = 3

    fun kindOf(mimeType: String): AttachmentKind = when {
        mimeType.startsWith("image/") -> AttachmentKind.IMAGE
        mimeType == MIME_PDF -> AttachmentKind.PDF
        mimeType.startsWith("text/plain") -> AttachmentKind.TEXT
        else -> AttachmentKind.OTHER
    }

    fun isSupported(mimeType: String): Boolean = when (kindOf(mimeType)) {
        AttachmentKind.IMAGE, AttachmentKind.PDF, AttachmentKind.TEXT -> true
        AttachmentKind.OTHER -> false
    }

    /**
     * 添加附件前的校验。
     *
     * @param existingCount 当前已添加的附件数量
     * @return 拒绝原因；null 表示可以添加
     */
    fun validateForAdd(
        existingCount: Int,
        size: Long,
        mimeType: String
    ): AttachmentRejection? = when {
        existingCount >= MAX_ATTACHMENTS_PER_MESSAGE -> AttachmentRejection.TOO_MANY
        size > MAX_SOURCE_FILE_BYTES -> AttachmentRejection.TOO_LARGE
        !isSupported(mimeType) -> AttachmentRejection.UNSUPPORTED
        else -> null
    }

    fun toChatAttachment(
        uri: String,
        name: String,
        mimeType: String,
        size: Long
    ): ChatAttachment = ChatAttachment(
        uri = uri,
        name = name,
        mimeType = mimeType,
        size = size,
        kind = kindOf(mimeType)
    )

    const val MIME_PDF = "application/pdf"
    const val MIME_TEXT = "text/plain"
    const val MIME_TEXT_UTF8 = "text/plain;charset=utf-8"
}

enum class AttachmentRejection {
    TOO_MANY,
    TOO_LARGE,
    UNSUPPORTED
}
