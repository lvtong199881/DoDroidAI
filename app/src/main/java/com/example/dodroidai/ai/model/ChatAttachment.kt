package com.example.dodroidai.ai.model

import com.google.gson.annotations.SerializedName

/**
 * 附件类型
 */
enum class AttachmentKind {
    IMAGE,
    PDF,
    TEXT,
    OTHER
}

/**
 * 已发送/待发送的附件元数据。
 *
 * 只保存 URI 与基础信息，不保存文件内容，避免会话 JSON 膨胀。
 * [uri] 使用 String 而非 android.net.Uri，便于纯 JVM 单元测试与 Gson 序列化。
 */
data class ChatAttachment(
    @SerializedName("uri")
    val uri: String,
    @SerializedName("name")
    val name: String,
    @SerializedName("mimeType")
    val mimeType: String,
    @SerializedName("size")
    val size: Long,
    @SerializedName("kind")
    val kind: AttachmentKind
) {
    val isImage: Boolean
        get() = kind == AttachmentKind.IMAGE || mimeType.startsWith("image/")
}
