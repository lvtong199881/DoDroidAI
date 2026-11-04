package com.example.dodroidai.ai.voice.model

import android.content.Context
import java.io.File

class TtsModelRepository(private val context: Context) {

    private val rootDir = File(context.filesDir, "tts_models")
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun modelDir(model: TtsModel): File = File(rootDir, model.id)

    fun isDownloaded(model: TtsModel): Boolean = model.files.all { file ->
        val target = File(modelDir(model), file.name)
        target.exists() && sizeMatches(target.length(), file.sizeBytes)
    }

    fun activeModel(): TtsModel =
        TtsModelCatalog.model(prefs.getString(KEY_ACTIVE, null))

    /** 当前模型目录；未下载/不完整时返回 null */
    fun activeModelDir(): File? {
        val model = activeModel()
        return if (isDownloaded(model)) modelDir(model) else null
    }

    fun setActive(model: TtsModel) {
        prefs.edit().putString(KEY_ACTIVE, model.id).apply()
    }

    fun source(): SttModelSource =
        SttModelSource.entries.firstOrNull { it.name == prefs.getString(KEY_SOURCE, null) }
            ?: SttModelSource.HF_MIRROR

    fun setSource(source: SttModelSource) {
        prefs.edit().putString(KEY_SOURCE, source.name).apply()
    }

    fun delete(model: TtsModel) {
        modelDir(model).deleteRecursively()
    }

    companion object {
        private const val PREFS = "tts_models"
        private const val KEY_ACTIVE = "active_model_id"
        private const val KEY_SOURCE = "source"

        /** 允许 3% 偏差（镜像文件大小可能略有差异） */
        fun sizeMatches(actual: Long, expected: Long): Boolean {
            if (expected <= 0) return true
            return actual >= expected * 0.97 && actual <= expected * 1.03
        }
    }
}
