package com.example.dodroidai.ai.voice

import android.content.res.AssetManager
import android.os.Build
import android.util.Log
import kotlinx.coroutines.*
import java.io.File
import java.io.InputStream
import java.util.concurrent.Executors

private const val LOG_TAG = "WhisperContext"

class WhisperContext private constructor(private var ptr: Long) {
    private val scope: CoroutineScope = CoroutineScope(
        Executors.newSingleThreadExecutor().asCoroutineDispatcher()
    )

    suspend fun transcribeData(audioData: FloatArray, printTimestamp: Boolean = false): String =
        withContext(scope.coroutineContext) {
            require(ptr != 0L)
            val numThreads = WhisperCpuConfig.preferredThreadCount
            Log.d(LOG_TAG, "Selecting $numThreads threads")
            WhisperLib.fullTranscribe(ptr, numThreads, audioData)
            val textCount = WhisperLib.getTextSegmentCount(ptr)
            return@withContext buildString {
                for (i in 0 until textCount) {
                    if (printTimestamp) {
                        val textTimestamp =
                            "[${toTimestamp(WhisperLib.getTextSegmentT0(ptr, i))} --> ${toTimestamp(WhisperLib.getTextSegmentT1(ptr, i))}]"
                        val textSegment = WhisperLib.getTextSegment(ptr, i)
                        append("$textTimestamp: $textSegment\n")
                    } else {
                        append(WhisperLib.getTextSegment(ptr, i))
                    }
                }
            }
        }

    suspend fun release() = withContext(scope.coroutineContext) {
        if (ptr != 0L) {
            WhisperLib.freeContext(ptr)
            ptr = 0
        }
    }

    protected fun finalize() {
        runBlocking {
            release()
        }
    }

    companion object {
        fun createContextFromAsset(
            assetManager: AssetManager,
            assetPath: String
        ): WhisperContext? {
            val ptr = WhisperLib.initContextFromAsset(assetManager, assetPath)
            if (ptr == 0L) {
                Log.e(LOG_TAG, "Couldn't create context from asset $assetPath")
                return null
            }
            return WhisperContext(ptr)
        }

        fun createContextFromFile(filePath: String): WhisperContext? {
            val ptr = WhisperLib.initContext(filePath)
            if (ptr == 0L) {
                Log.e(LOG_TAG, "Couldn't create context with path $filePath")
                return null
            }
            return WhisperContext(ptr)
        }

        fun createContextFromInputStream(stream: InputStream): WhisperContext? {
            val ptr = WhisperLib.initContextFromInputStream(stream)
            if (ptr == 0L) {
                Log.e(LOG_TAG, "Couldn't create context from input stream")
                return null
            }
            return WhisperContext(ptr)
        }
    }
}

private class WhisperLib {
    companion object {
        init {
            Log.d(LOG_TAG, "Primary ABI: ${Build.SUPPORTED_ABIS[0]}")
            System.loadLibrary("whisper")
        }

        external fun initContextFromInputStream(inputStream: InputStream): Long
        external fun initContextFromAsset(assetManager: AssetManager, assetPath: String): Long
        external fun initContext(modelPath: String): Long
        external fun freeContext(contextPtr: Long)
        external fun fullTranscribe(contextPtr: Long, numThreads: Int, audioData: FloatArray)
        external fun getTextSegmentCount(contextPtr: Long): Int
        external fun getTextSegment(contextPtr: Long, index: Int): String
        external fun getTextSegmentT0(contextPtr: Long, index: Int): Long
        external fun getTextSegmentT1(contextPtr: Long, index: Int): Long
    }
}

private fun toTimestamp(t: Long, comma: Boolean = false): String {
    var msec = t * 10
    val hr = msec / (1000 * 60 * 60)
    msec -= hr * (1000 * 60 * 60)
    val min = msec / (1000 * 60)
    msec -= min * (1000 * 60)
    val sec = msec / 1000
    msec -= sec * 1000

    val delimiter = if (comma) "," else "."
    return String.format("%02d:%02d:%02d%s%03d", hr, min, sec, delimiter, msec)
}