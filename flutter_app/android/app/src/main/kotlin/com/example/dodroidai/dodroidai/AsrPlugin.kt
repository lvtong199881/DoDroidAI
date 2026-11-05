package com.example.dodroidai.dodroidai

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.example.dodroidai.ai.voice.SenseVoiceEngine
import com.example.dodroidai.ai.voice.VoiceRecorder
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File

/**
 * 暴露原生 sherpa-onnx SenseVoice ASR 给 Flutter：dodroidai/asr
 */
class AsrPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "dodroidai/asr"
        private const val TAG = "AsrPlugin"
        private const val MODEL_DIR = "stt_models/sense_voice_2025_09_09"
    }

    private var engine: SenseVoiceEngine? = null
    private var recorder: VoiceRecorder? = null
    private val scope = CoroutineScope(Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> init(result)
            "start" -> start(result)
            "stop" -> stop(result)
            else -> result.notImplemented()
        }
    }

    private fun init(result: MethodChannel.Result) {
        try {
            val dir = File(context.filesDir, MODEL_DIR)
            if (!File(dir, "model.int8.onnx").exists()) {
                result.error("init", "模型不存在: ${dir.absolutePath}", null)
                return
            }
            val e = SenseVoiceEngine(dir)
            if (!e.initialize()) {
                result.error("init", "初始化失败", null)
                return
            }
            engine = e
            Log.i(TAG, "ASR 初始化成功: ${dir.absolutePath}")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "ASR 初始化异常", e)
            result.error("init", e.message, null)
        }
    }

    private fun start(result: MethodChannel.Result) {
        val rec = recorder ?: VoiceRecorder(context).also { recorder = it }
        if (!rec.hasPermission()) {
            result.error("permission", "缺少录音权限", null)
            return
        }
        try {
            rec.startRecording(onRmsChanged = {}, onSilence = {})
            Log.i(TAG, "录音开始")
            result.success(true)
        } catch (e: Exception) {
            result.error("start", e.message, null)
        }
    }

    private fun stop(result: MethodChannel.Result) {
        val rec = recorder
        val e = engine
        if (rec == null || e == null) {
            result.error("stop", "未开始录音或 ASR 未初始化", null)
            return
        }
        scope.launch {
            try {
                val samples = rec.stopRecording()
                val text = e.transcribe(samples)
                Log.i(TAG, "识别完成: ${text.length} 字")
                mainHandler.post { result.success(text) }
            } catch (ex: Exception) {
                Log.e(TAG, "识别失败", ex)
                mainHandler.post { result.error("stop", ex.message, null) }
            }
        }
    }
}
