package com.example.dodroidai.ai.voice.model

/**
 * 可下载的语音识别模型清单
 */
data class SttModelFile(
    val name: String,
    val sizeBytes: Long
)

data class SttModel(
    val id: String,
    val displayName: String,
    val repo: String,
    val files: List<SttModelFile>,
    val languages: String
) {
    val totalBytes: Long = files.sumOf { it.sizeBytes }
}

object SttModelCatalog {

    val defaultModel = SttModel(
        id = "sense_voice_2025_09_09",
        displayName = "SenseVoice Small",
        repo = "csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09",
        files = listOf(
            SttModelFile("tokens.txt", 315_894L),
            SttModelFile("model.int8.onnx", 237_115_547L)
        ),
        languages = "中文 / 英文 / 粤语 / 日语 / 韩语"
    )

    val all: List<SttModel> = listOf(defaultModel)

    fun model(id: String?): SttModel =
        all.firstOrNull { it.id == id } ?: defaultModel
}

enum class SttModelSource {
    HF_MIRROR,
    HUGGINGFACE
}

fun downloadUrl(source: SttModelSource, repo: String, fileName: String): String =
    when (source) {
        SttModelSource.HF_MIRROR -> "https://hf-mirror.com/$repo/resolve/main/$fileName"
        SttModelSource.HUGGINGFACE -> "https://huggingface.co/$repo/resolve/main/$fileName"
    }
