package com.example.dodroidai.ai.voice

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.example.dodroidai.ai.voice.model.SttModelRepository
import kotlinx.coroutines.*
import java.io.File

/**
 * 语音输入管理器
 * 使用 sherpa-onnx + SenseVoice 实现离线语音识别
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

    private var engine: SenseVoiceEngine? = null
    private var engineModelDir: File? = null
    private var recorder: VoiceRecorder? = null
    private var isListening = false
    private var currentCallback: VoiceRecognitionCallback? = null
    private var initJob: Job? = null

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    /**
     * 初始化识别引擎；模型未下载时通过回调提示
     */
    fun initializeIfNeeded(onReady: () -> Unit) {
        val modelDir = SttModelRepository(context).activeModelDir()
        if (modelDir == null) {
            currentCallback?.onError("请先在设置中下载语音模型")
            return
        }
        if (engine != null && engineModelDir == modelDir) {
            onReady()
            return
        }

        initJob?.cancel()
        initJob = scope.launch {
            val newEngine = withContext(Dispatchers.IO) {
                engine?.release()
                engine = null
                engineModelDir = null
                val candidate = SenseVoiceEngine(modelDir)
                val ok = runCatching { candidate.initialize() }.getOrDefault(false)
                if (ok) candidate else null
            }
            if (newEngine == null) {
                currentCallback?.onError("模型加载失败，请尝试重新下载")
                return@launch
            }
            engine = newEngine
            engineModelDir = modelDir
            onReady()
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
        recorder = VoiceRecorder(context)

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
        recorder = null

        if (audioData.isNotEmpty()) {
            performTranscription(audioData)
        } else {
            currentCallback?.onError("未录制到音频数据")
        }
    }

    private fun performTranscription(audioData: FloatArray) {
        val currentEngine = engine ?: return

        scope.launch(Dispatchers.IO) {
            try {
                val text = currentEngine.transcribe(audioData)
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
     * 模型切换/删除后释放旧引擎
     */
    fun resetModel() {
        engine?.release()
        engine = null
        engineModelDir = null
    }

    /**
     * 释放资源
     */
    fun destroy() {
        stopListening()
        initJob?.cancel()
        scope.cancel()
        resetModel()
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
