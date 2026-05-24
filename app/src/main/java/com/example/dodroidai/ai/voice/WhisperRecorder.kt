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
import kotlinx.coroutines.*
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * Whisper 音频录制器
 * 使用 AudioRecord 录制 16kHz mono PCM 16bit 音频
 */
class WhisperRecorder(private val context: Context) {

    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private val audioData = mutableListOf<Short>()
    private var recordingJob: Job? = null
    private val maxRecordingDurationSamples = SAMPLE_RATE * 30 // 最多30秒音频

    companion object {
        private const val TAG = "WhisperRecorder"
        const val SAMPLE_RATE = 16000
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
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
    fun startRecording(onRmsChanged: (Float) -> Unit) {
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