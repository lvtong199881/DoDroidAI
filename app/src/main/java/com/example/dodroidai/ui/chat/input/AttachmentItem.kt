package com.example.dodroidai.ui.chat.input

import android.net.Uri

/**
 * 附件数据模型
 */
data class AttachmentItem(
    val uri: Uri,
    val name: String,
    val size: Long,
    val mimeType: String
) {
    val isImage: Boolean
        get() = mimeType.startsWith("image/")
}