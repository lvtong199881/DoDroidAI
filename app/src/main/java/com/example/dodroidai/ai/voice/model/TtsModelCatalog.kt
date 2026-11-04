package com.example.dodroidai.ai.voice.model

/**
 * 可下载的离线 TTS 模型清单（sherpa-onnx MeloTTS）
 */
data class TtsModelFile(
    val name: String,
    val sizeBytes: Long
)

data class TtsModel(
    val id: String,
    val displayName: String,
    val repo: String,
    val files: List<TtsModelFile>,
    val languages: String
) {
    val totalBytes: Long = files.sumOf { it.sizeBytes }
}

object TtsModelCatalog {

    val melo = TtsModel(
        id = "vits_melo_tts_zh_en",
        displayName = "MeloTTS 中英混合",
        repo = "csukuangfj/vits-melo-tts-zh_en",
        files = listOf(
            TtsModelFile("model.int8.onnx", 53_517_430L),
            TtsModelFile("tokens.txt", 655L),
            TtsModelFile("lexicon.txt", 6_837_671L),
            TtsModelFile("date.fst", 59_154L),
            TtsModelFile("new_heteronym.fst", 21_974L),
            TtsModelFile("number.fst", 64_482L),
            TtsModelFile("phone.fst", 88_630L),
            TtsModelFile("dict/hmm_model.utf8", 519_739L),
            TtsModelFile("dict/idf.utf8", 5_998_717L),
            TtsModelFile("dict/jieba.dict.utf8", 5_071_204L),
            TtsModelFile("dict/pos_dict/char_state_tab.utf8", 327_139L),
            TtsModelFile("dict/pos_dict/prob_emit.utf8", 1_687_686L),
            TtsModelFile("dict/pos_dict/prob_start.utf8", 4_347L),
            TtsModelFile("dict/pos_dict/prob_trans.utf8", 124_159L),
            TtsModelFile("dict/stop_words.utf8", 8_974L),
            TtsModelFile("dict/user.dict.utf8", 49L)
        ),
        languages = "中文 / 英文"
    )

    val all: List<TtsModel> = listOf(melo)

    fun model(id: String?): TtsModel =
        all.firstOrNull { it.id == id } ?: melo
}
