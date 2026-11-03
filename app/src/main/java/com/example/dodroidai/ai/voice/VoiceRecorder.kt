package com.example.dodroidai.ai.voice

import android.Manifest
import android.content.Context
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import androidx.core.content.ContextCompat
import com.k2fsa.sherpa.onnx.SileroVadModelConfig
import com.k2fsa.sherpa.onnx.Vad
import com.k2fsa.sherpa.onnx.VadModelConfig
import kotlinx.coroutines.*
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * 音频录制器
 * 使用 AudioRecord 录制 16kHz mono PCM 16bit 音频
 */
class VoiceRecorder(private val context: Context) {

    private var audioRecord: AudioRecord? = null
    private var vad: Vad? = null
    private var hasSpeech = false
    private var silenceSamples = 0
    private var isRecording = false
    private val audioData = mutableListOf<Short>()
    private var recordingJob: Job? = null
    private val maxRecordingDurationSamples = SAMPLE_RATE * 30 // 最多30秒音频

    companion object {
        private const val TAG = "VoiceRecorder"
        const val SAMPLE_RATE = 16000
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val VAD_WINDOW = 512
        private const val AUTO_STOP_SILENCE_SECONDS = 0.8f
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
     * 开始录音
     * @param onRmsChanged 音量变化回调
     */
    @SuppressLint("MissingPermission")
    fun startRecording(onRmsChanged: (Float) -> Unit, onSilence: () -> Unit = {}) {
        if (isRecording) {
            stopRecording()
        }

        val bufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            CHANNEL_CONFIG,
            AUDIO_FORMAT
        ) * 4

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            CHANNEL_CONFIG,
            AUDIO_FORMAT,
            bufferSize
        )

        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            Log.e(TAG, "AudioRecord 初始化失败")
            audioRecord?.release()
            audioRecord = null
            return
        }

        audioData.clear()
        hasSpeech = false
        silenceSamples = 0
        vad = createVad()
        isRecording = true
        audioRecord?.startRecording()

        recordingJob = CoroutineScope(Dispatchers.IO).launch {
            val buffer = ShortArray(bufferSize / 2)
            while (isRecording && isActive) {
                val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                if (read > 0) {
                    synchronized(audioData) {
                        // 限制最大录制长度
                        val remaining = maxRecordingDurationSamples - audioData.size
                        if (remaining > 0) {
                            val toAdd = minOf(read, remaining)
                            for (i in 0 until toAdd) {
                                audioData.add(buffer[i])
                            }
                        } else {
                            isRecording = false // 达到最大长度，自动停止
                        }
                    }
                    onRmsChanged(calculateRms(buffer, read))

                    // VAD 自动断句：检测到语音后持续静音 0.8s 自动结束
                    val currentVad = vad
                    if (currentVad != null) {
                        var offset = 0
                        while (offset + VAD_WINDOW <= read) {
                            val window = FloatArray(VAD_WINDOW) { buffer[offset + it] / 32768f }
                            currentVad.acceptWaveform(window)
                            if (currentVad.isSpeechDetected()) {
                                hasSpeech = true
                                silenceSamples = 0
                            } else if (hasSpeech) {
                                silenceSamples += VAD_WINDOW
                            }
                            offset += VAD_WINDOW
                        }
                        if (hasSpeech && silenceSamples >= SAMPLE_RATE * AUTO_STOP_SILENCE_SECONDS) {
                            isRecording = false
                            onSilence()
                        }
                    }
                }
            }
        }

        Log.i(TAG, "开始录音，缓冲区大小: $bufferSize，最大采样数: $maxRecordingDurationSamples")
    }

    /**
     * 停止录音并返回音频数据
     */
    fun stopRecording(): FloatArray {
        isRecording = false
        recordingJob?.cancel()
        recordingJob = null

        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        vad?.release()
        vad = null

        val shortArray = synchronized(audioData) {
            audioData.toShortArray()
        }

        Log.i(TAG, "停止录音，采样数: ${shortArray.size}")

        return shortsToFloats(shortArray)
    }

    /**
     * 是否正在录音
     */
    fun isRecording(): Boolean = isRecording

    private fun createVad(): Vad? = try {
        Vad(
            assetManager = context.assets,
            config = VadModelConfig(
                sileroVadModelConfig = SileroVadModelConfig(
                    model = "models/silero_vad.onnx",
                    threshold = 0.5f,
                    minSilenceDuration = 0.25f,
                    minSpeechDuration = 0.25f,
                    windowSize = VAD_WINDOW
                ),
                sampleRate = SAMPLE_RATE,
                numThreads = 1
            )
        )
    } catch (e: Throwable) {
        Log.w(TAG, "VAD 初始化失败，退化为手动停止: ${e.javaClass.simpleName}")
        null
    }

    /**
     * 计算 RMS 分贝值
     */
    private fun calculateRms(buffer: ShortArray, length: Int): Float {
        var sum = 0.0
        for (i in 0 until length) {
            val sample = buffer[i].toDouble()
            sum += sample * sample
        }
        val rms = sqrt(sum / length)
        return if (rms > 0) {
            (20 * log10(rms / 32767.0)).toFloat()
        } else {
            -160f
        }
    }

    /**
     * ShortArray 转 FloatArray
     */
    private fun shortsToFloats(shorts: ShortArray): FloatArray {
        return FloatArray(shorts.size) { shorts[it] / 32767.0f }
    }
}