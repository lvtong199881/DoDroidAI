package com.example.dodroidai.ui.chat.input

import android.net.Uri
import com.google.gson.annotations.SerializedName

/**
 * 附件数据模型
 */
data class AttachmentItem(
    @SerializedName("uri")
    val uri: Uri,
    @SerializedName("name")
    val name: String,
    @SerializedName("size")
    val size: Long,
    @SerializedName("mimeType")
    val mimeType: String
) {
    val isImage: Boolean
        get() = mimeType.startsWith("image/")
}