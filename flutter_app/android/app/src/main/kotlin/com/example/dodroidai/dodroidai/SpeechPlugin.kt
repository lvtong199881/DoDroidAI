package com.example.dodroidai.dodroidai

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.k2fsa.sherpa.onnx.OfflineTts
import com.k2fsa.sherpa.onnx.OfflineTtsConfig
import com.k2fsa.sherpa.onnx.OfflineTtsModelConfig
import com.k2fsa.sherpa.onnx.OfflineTtsVitsModelConfig
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 暴露原生 sherpa-onnx TTS 给 Flutter：dodroidai/speech
 */
class SpeechPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "dodroidai/speech"
        private const val TAG = "SpeechPlugin"
        private const val MODEL_DIR = "tts_models/vits_melo_tts_zh_en"
    }

    private var tts: OfflineTts? = null
    private var track: AudioTrack? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> init(call.argument("modelDir"), result)
            "speak" -> speak(call.argument("text"), result)
            "stop" -> {
                stop()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun init(modelDir: String?, result: MethodChannel.Result) {
        try {
            val base = File(
                modelDir ?: File(context.filesDir, MODEL_DIR).absolutePath
            )
            if (!File(base, "model.int8.onnx").exists()) {
                result.error("init", "模型不存在: ${base.absolutePath}", null)
                return
            }
            tts = OfflineTts(
                config = OfflineTtsConfig(
                    model = OfflineTtsModelConfig(
                        vits = OfflineTtsVitsModelConfig(
                            model = File(base, "model.int8.onnx").absolutePath,
                            tokens = File(base, "tokens.txt").absolutePath,
                            lexicon = File(base, "lexicon.txt").absolutePath,
                            dictDir = File(base, "dict").absolutePath
                        ),
                        numThreads = 2
                    ),
                    ruleFsts = listOf("date.fst", "new_heteronym.fst", "number.fst", "phone.fst")
                        .joinToString(",") { File(base, it).absolutePath }
                )
            )
            Log.i(TAG, "TTS 初始化成功: ${base.absolutePath}")
            result.success(tts?.sampleRate())
        } catch (e: Exception) {
            Log.e(TAG, "TTS 初始化失败", e)
            result.error("init", e.message, null)
        }
    }

    private fun speak(text: String?, result: MethodChannel.Result) {
        val engine = tts
        if (engine == null) {
            result.error("speak", "TTS 未初始化", null)
            return
        }
        if (text.isNullOrBlank()) {
            result.success(0)
            return
        }
        Thread {
            try {
                val audio = engine.generate(text, 0, 1.0f)
                play(audio.samples, audio.sampleRate)
                Log.i(TAG, "朗读完成: ${audio.samples.size} samples")
                Handler(Looper.getMainLooper()).post { result.success(audio.samples.size) }
            } catch (e: Exception) {
                Log.e(TAG, "朗读失败", e)
                Handler(Looper.getMainLooper()).post { result.error("speak", e.message, null) }
            }
        }.start()
    }

    private fun play(samples: FloatArray, sampleRate: Int) {
        stop()
        val t = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(samples.size * 4)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
        t.write(samples, 0, samples.size, AudioTrack.WRITE_BLOCKING)
        t.play()
        track = t
    }

    private fun stop() {
        track?.let { t ->
            runCatching { t.stop() }
            runCatching { t.release() }
        }
        track = null
    }
}
