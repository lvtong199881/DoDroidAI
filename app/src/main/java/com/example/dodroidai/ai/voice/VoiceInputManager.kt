package com.example.dodroidai.ai.voice

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.*

/**
 * 语音输入管理器
 * 使用 Whisper.cpp 实现离线语音识别
 */
class VoiceInputManager(private val context: Context) {

    /**
     * 语音识别回调
     */
    interface VoiceRecognitionCallback {
        fun onReadyForSpeech()
        fun onBeginningOfSpeech()
        fun onEndOfSpeech()
        fun onPartialResult(text: String)
        fun onResult(text: String)
        fun onError(error: String)
        fun onRmsChanged(rmsdB: Float)
    }

    private var whisperContext: WhisperContext? = null
    private var recorder: WhisperRecorder? = null
    private var isListening = false
    private var currentCallback: VoiceRecognitionCallback? = null
    private var initJob: Job? = null

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    /**
     * 初始化 Whisper 模型
     */
    fun initializeIfNeeded(onReady: () -> Unit) {
        if (whisperContext != null) {
            onReady()
            return
        }

        initJob?.cancel()
        initJob = scope.launch(Dispatchers.IO) {
            try {
                whisperContext = WhisperContext.createContextFromAsset(
                    context.assets,
                    "models/ggml-tiny-q8_0.bin"
                )
                withContext(Dispatchers.Main) {
                    onReady()
                }
            } catch (e: Exception) {
                Log.e(TAG, "模型加载失败", e)
                withContext(Dispatchers.Main) {
                    currentCallback?.onError("模型加载失败: ${e.message}")
                }
            }
        }
    }

    /**
     * 检查是否有录音权限
     */
    fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 开始语音识别
     */
    fun startListening(callback: VoiceRecognitionCallback) {
        if (isListening) {
            stopListening()
        }

        if (!hasPermission()) {
            callback.onError("缺少录音权限")
            return
        }

        currentCallback = callback
        isListening = true

        initializeIfNeeded {
            startRecordingInternal()
        }
    }

    private fun startRecordingInternal() {
        recorder = WhisperRecorder(context)

        currentCallback?.onReadyForSpeech()

        recorder?.startRecording { rmsdB ->
            currentCallback?.onRmsChanged(rmsdB)
        }

        Log.i(TAG, "开始录音")
    }

    /**
     * 停止语音识别
     */
    fun stopListening() {
        if (!isListening) {
            return
        }

        isListening = false
        currentCallback?.onEndOfSpeech()

        val audioData = recorder?.stopRecording() ?: FloatArray(0)

        if (audioData.isNotEmpty()) {
            performTranscription(audioData)
        } else {
            currentCallback?.onError("未录制到音频数据")
        }
    }

    private fun performTranscription(audioData: FloatArray) {
        val context = whisperContext ?: return

        scope.launch(Dispatchers.IO) {
            try {
                val text = context.transcribeData(audioData)
                withContext(Dispatchers.Main) {
                    if (text.isNotBlank()) {
                        currentCallback?.onResult(text)
                    } else {
                        currentCallback?.onError("未识别到语音")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "转写失败", e)
                withContext(Dispatchers.Main) {
                    currentCallback?.onError("语音转写失败: ${e.message}")
                }
            }
        }
    }

    /**
     * 释放资源
     */
    fun destroy() {
        stopListening()
        initJob?.cancel()
        scope.cancel()
        currentCallback = null
    }

    /**
     * 是否正在录音
     */
    fun isListening(): Boolean = isListening

    companion object {
        private const val TAG = "VoiceInputManager"
    }
}