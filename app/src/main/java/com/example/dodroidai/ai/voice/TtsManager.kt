package com.example.dodroidai.ai.voice

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.speech.tts.TextToSpeech
import android.util.Log
import com.example.dodroidai.ai.voice.model.TtsModelRepository
import com.k2fsa.sherpa.onnx.OfflineTts
import com.k2fsa.sherpa.onnx.OfflineTtsConfig
import com.k2fsa.sherpa.onnx.OfflineTtsModelConfig
import com.k2fsa.sherpa.onnx.OfflineTtsVitsModelConfig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.File
import java.util.Locale

/**
 * TTS 管理器：优先使用离线 sherpa-onnx 模型，未下载时回退系统 TTS
 */
class TtsManager(private val context: Context) {
    interface InitListener {
        fun onInitSuccess()
        fun onInitError(error: String)
    }

    private var tts: TextToSpeech? = null
    private var offlineTts: OfflineTts? = null
    private var audioTrack: AudioTrack? = null
    private var speakJob: Job? = null
    private var isInitialized = false
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val offlineRepository = TtsModelRepository(context)

    /**
     * 初始化 TTS 引擎：离线模型可用时优先加载，否则回退系统 TTS
     */
    fun initialize(listener: InitListener) {
        val dir = offlineRepository.activeModelDir()
        if (dir != null) {
            val loaded = runCatching { createOfflineTts(dir) }.getOrNull()
            if (loaded != null) {
                offlineTts = loaded
                isInitialized = true
                Log.i(TAG, "离线 TTS 已加载: ${dir.absolutePath}")
                listener.onInitSuccess()
                return
            }
            Log.w(TAG, "离线 TTS 加载失败，回退系统 TTS")
        }

        tts = TextToSpeech(context) { status ->
            isInitialized = status == TextToSpeech.SUCCESS
            if (isInitialized) {
                val result = tts?.setLanguage(Locale.CHINESE)
                if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                    Log.w(TAG, "Chinese language not supported")
                    listener.onInitError("中文语言包未安装")
                } else {
                    listener.onInitSuccess()
                }
            } else {
                listener.onInitError("TTS 初始化失败")
            }
        }
    }

    private fun createOfflineTts(dir: File): OfflineTts {
        val config = OfflineTtsConfig(
            model = OfflineTtsModelConfig(
                vits = OfflineTtsVitsModelConfig(
                    model = File(dir, "model.int8.onnx").absolutePath,
                    tokens = File(dir, "tokens.txt").absolutePath,
                    lexicon = File(dir, "lexicon.txt").absolutePath,
                    dictDir = File(dir, "dict").absolutePath
                ),
                numThreads = 2
            ),
            ruleFsts = listOf("date.fst", "new_heteronym.fst", "number.fst", "phone.fst")
                .joinToString(",") { File(dir, it).absolutePath }
        )
        return OfflineTts(config = config)
    }

    /**
     * 朗读文本
     * @param text 要朗读的文本
     * @param queueMode 队列模式（仅系统 TTS 使用）
     */
    fun speak(text: String, queueMode: Int = TextToSpeech.QUEUE_FLUSH) {
        if (text.isBlank()) return
        if (offlineTts != null) {
            speakOffline(text)
        } else if (isInitialized) {
            tts?.speak(text, queueMode, null, null)
        } else {
            Log.w(TAG, "TTS not initialized, speak ignored")
        }
    }

    private fun speakOffline(text: String) {
        speakJob?.cancel()
        stopAudio()
        speakJob = scope.launch {
            val engine = offlineTts ?: return@launch
            val audio = runCatching { engine.generate(text, 0, 1.0f) }
                .onFailure { Log.w(TAG, "离线合成失败", it) }
                .getOrNull() ?: return@launch
            if (audio.samples.isEmpty()) return@launch
            playPcm(audio.samples, audio.sampleRate)
        }
    }

    private fun playPcm(samples: FloatArray, sampleRate: Int) {
        stopAudio()
        val track = AudioTrack.Builder()
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
        track.write(samples, 0, samples.size, AudioTrack.WRITE_BLOCKING)
        track.play()
        audioTrack = track
    }

    private fun stopAudio() {
        audioTrack?.let { track ->
            runCatching { track.stop() }
            runCatching { track.release() }
        }
        audioTrack = null
    }

    /**
     * 停止朗读
     */
    fun stop() {
        speakJob?.cancel()
        stopAudio()
        tts?.stop()
    }

    /**
     * 设置语速（仅系统 TTS）
     */
    fun setSpeechRate(rate: Float) {
        tts?.setSpeechRate(rate)
    }

    /**
     * 释放 TTS 资源
     */
    fun shutdown() {
        stop()
        tts?.shutdown()
        tts = null
        offlineTts = null
        isInitialized = false
    }

    companion object {
        private const val TAG = "TtsManager"
    }
}
