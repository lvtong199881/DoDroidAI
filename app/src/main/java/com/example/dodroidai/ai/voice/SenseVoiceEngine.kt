package com.example.dodroidai.ai.voice

import android.util.Log
import com.k2fsa.sherpa.onnx.FeatureConfig
import com.k2fsa.sherpa.onnx.OfflineModelConfig
import com.k2fsa.sherpa.onnx.OfflineRecognizer
import com.k2fsa.sherpa.onnx.OfflineRecognizerConfig
import com.k2fsa.sherpa.onnx.OfflineSenseVoiceModelConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * SenseVoice 离线识别引擎（sherpa-onnx）
 *
 * 模型目录需包含 model.int8.onnx 与 tokens.txt
 */
class SenseVoiceEngine(private val modelDir: File) {

    private var recognizer: OfflineRecognizer? = null

    fun initialize(): Boolean {
        if (recognizer != null) return true

        val modelFile = File(modelDir, "model.int8.onnx")
        val tokensFile = File(modelDir, "tokens.txt")
        if (!modelFile.exists() || !tokensFile.exists()) {
            Log.w(TAG, "模型文件缺失: $modelDir")
            return false
        }

        return try {
            val config = OfflineRecognizerConfig(
                featConfig = FeatureConfig(sampleRate = 16000, featureDim = 80),
                modelConfig = OfflineModelConfig(
                    senseVoice = OfflineSenseVoiceModelConfig(
                        model = modelFile.absolutePath,
                        language = "auto",
                        useInverseTextNormalization = true
                    ),
                    tokens = tokensFile.absolutePath,
                    numThreads = 2,
                    debug = false
                )
            )
            recognizer = OfflineRecognizer(config = config)
            true
        } catch (e: Throwable) {
            Log.e(TAG, "初始化失败: ${e.javaClass.simpleName}")
            recognizer = null
            false
        }
    }

    suspend fun transcribe(samples: FloatArray): String = withContext(Dispatchers.IO) {
        val r = recognizer ?: error("recognizer not initialized")
        val stream = r.createStream()
        try {
            stream.acceptWaveform(samples, SAMPLE_RATE)
            r.decode(stream)
            r.getResult(stream).text.trim()
        } finally {
            stream.release()
        }
    }

    fun release() {
        recognizer?.release()
        recognizer = null
    }

    companion object {
        private const val TAG = "SenseVoiceEngine"
        const val SAMPLE_RATE = 16000
    }
}
