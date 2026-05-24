package com.example.dodroidai.ai.voice

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat

/**
 * 语音输入管理器
 * 使用 Android SpeechRecognizer 实现联网语音识别
 * TODO: 集成 Whisper.cpp 实现离线语音识别
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

    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var currentCallback: VoiceRecognitionCallback? = null

    /**
     * 检查是否有录音权限
     */
    fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 检查是否支持语音识别
     */
    fun isSpeechRecognizerAvailable(): Boolean {
        return SpeechRecognizer.isRecognitionAvailable(context)
    }

    /**
     * 初始化语音识别器
     */
    private fun initSpeechRecognizer(): SpeechRecognizer? {
        return try {
            SpeechRecognizer.createSpeechRecognizer(context)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create SpeechRecognizer", e)
            null
        }
    }

    /**
     * 开始语音识别
     * TODO: 替换为 Whisper.cpp 实现
     */
    fun startListening(callback: VoiceRecognitionCallback) {
        if (!hasPermission()) {
            callback.onError("缺少录音权限")
            return
        }

        if (!isSpeechRecognizerAvailable()) {
            callback.onError("语音识别不可用")
            return
        }

        if (isListening) {
            stopListening()
        }

        currentCallback = callback
        speechRecognizer = initSpeechRecognizer()

        speechRecognizer?.let { recognizer ->
            recognizer.setRecognitionListener(createRecognitionListener(callback))
            recognizer.startListening(createIntent())
            isListening = true
            callback.onReadyForSpeech()
            Log.i(TAG, "Start listening")
        } ?: run {
            callback.onError("语音识别器初始化失败")
        }
    }

    /**
     * 创建语音识别 Intent
     */
    private fun createIntent(): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
    }

    /**
     * 创建 RecognitionListener
     */
    private fun createRecognitionListener(callback: VoiceRecognitionCallback): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                callback.onReadyForSpeech()
            }

            override fun onBeginningOfSpeech() {
                callback.onBeginningOfSpeech()
            }

            override fun onRmsChanged(rmsdB: Float) {
                callback.onRmsChanged(rmsdB)
            }

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                callback.onEndOfSpeech()
            }

            override fun onError(error: Int) {
                val errorMessage = getErrorMessage(error)
                Log.e(TAG, "Speech recognition error: $errorMessage")
                callback.onError(errorMessage)
                isListening = false
            }

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull() ?: ""
                if (text.isNotBlank()) {
                    callback.onResult(text)
                }
                isListening = false
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull() ?: ""
                if (text.isNotBlank()) {
                    callback.onPartialResult(text)
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }
    }

    /**
     * 获取错误消息
     */
    private fun getErrorMessage(errorCode: Int): String {
        return when (errorCode) {
            SpeechRecognizer.ERROR_AUDIO -> "音频录制错误"
            SpeechRecognizer.ERROR_CLIENT -> "客户端错误"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "权限不足"
            SpeechRecognizer.ERROR_NETWORK -> "网络错误"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "网络超时"
            SpeechRecognizer.ERROR_NO_MATCH -> "未识别到语音"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "识别服务忙"
            SpeechRecognizer.ERROR_SERVER -> "服务器错误"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "未检测到语音"
            else -> "未知错误"
        }
    }

    /**
     * 停止语音识别
     */
    fun stopListening() {
        if (isListening) {
            speechRecognizer?.stopListening()
            isListening = false
            Log.i(TAG, "Stop listening")
        }
    }

    /**
     * 释放资源
     */
    fun destroy() {
        stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null
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