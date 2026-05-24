package com.example.dodroidai.ai.voice

import android.content.Context
import android.util.Log
import android.speech.tts.TextToSpeech
import java.util.Locale

/**
 * TTS 管理器，支持中文朗读
 */
class TtsManager(private val context: Context) {
    interface InitListener {
        fun onInitSuccess()
        fun onInitError(error: String)
    }

    private var tts: TextToSpeech? = null
    private var isInitialized = false

    /**
     * 初始化 TTS 引擎
     */
    fun initialize(listener: InitListener) {
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

    /**
     * 朗读文本
     * @param text 要朗读的文本
     * @param queueMode 队列模式，QUEUE_FLUSH 会中断当前朗读，QUEUE_ADD 会加入队列
     */
    fun speak(text: String, queueMode: Int = TextToSpeech.QUEUE_FLUSH) {
        if (isInitialized) {
            tts?.speak(text, queueMode, null, null)
        } else {
            Log.w(TAG, "TTS not initialized, speak ignored")
        }
    }

    /**
     * 停止朗读
     */
    fun stop() {
        tts?.stop()
    }

    /**
     * 设置语速
     * @param rate 1.0 为正常语速，0.5 为半速，2.0 为两倍速
     */
    fun setSpeechRate(rate: Float) {
        tts?.setSpeechRate(rate)
    }

    /**
     * 释放 TTS 资源
     */
    fun shutdown() {
        tts?.shutdown()
        tts = null
        isInitialized = false
    }

    companion object {
        private const val TAG = "TtsManager"
    }
}