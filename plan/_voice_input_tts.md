# 语音输入 + TTS 输出实现计划

## Context
TodoTasks.md P1 级任务 #6，实现全语音交互，解放双手。

**当前状态**：已完成基础语音输入和 TTS 输出（使用 SpeechRecognizer 联网识别）。
**本次更新**：将 SpeechRecognizer 替换为 Whisper.cpp，实现离线语音识别。

**问题**：SpeechRecognizer 依赖网络，无法在无网环境下工作。
**解决方案**：使用 whisper.cpp 在设备端离线执行语音识别。

## 实现方案

### 1. 权限配置
**文件**: `app/src/main/AndroidManifest.xml`

已有 RECORD_AUDIO 权限，无需修改。

### 2. 集成 Whisper.cpp（本次修改重点）
**文件**: `app/src/main/java/com/example/dodroidai/ai/voice/VoiceInputManager.kt`（修改）

#### 关键设计决策

| 问题 | 决策 | 理由 |
|------|------|------|
| 模块集成方式 | 复制 whisper.android/lib 模块 | 避免外部依赖 |
| 模型存储 | `assets/models/ggml-base.bin` | APK 内置，开箱即用 |
| 模型选择 | `ggml-base.bin` (142 MiB) | 平衡准确率与性能 |
| 音频格式 | 16kHz, mono, PCM 16bit | Whisper 训练数据格式 |
| 回调接口 | 保持现有 `VoiceRecognitionCallback` | 无需修改 ChatFragment |

#### 新增文件

| 文件 | 用途 |
|------|------|
| `app/src/main/java/com/example/dodroidai/ai/voice/WhisperRecorder.kt` | 音频录制（AudioRecord） |
| `app/src/main/java/com/example/dodroidai/ai/voice/AudioDataProcessor.kt` | PCM ShortArray → FloatArray |
| `app/src/main/java/com/example/dodroidai/ai/voice/WhisperContext.kt` | WhisperContext Kotlin 封装 |
| `app/src/main/java/com/example/dodroidai/ai/voice/WhisperCpuConfig.kt` | CPU 核心数配置 |
| `app/src/main/jni/whisper/*.cpp,h` | Whisper 原生源码 |
| `app/src/main/jni/ggml/*` | GGML 库源码 |
| `app/src/main/jni/whisper/jni.c` | JNI 桥接 |
| `app/src/main/assets/models/ggml-base.bin` | 模型文件 |
| `app/src/main/jni/whisper/CMakeLists.txt` | CMake 构建配置 |

#### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `app/build.gradle.kts` | 添加 CMake 构建配置 |
| `app/src/main/java/com/example/dodroidai/ai/voice/VoiceInputManager.kt` | 重写为 Whisper 实现 |

#### 实现步骤

**Step 1: 配置 build.gradle.kts**
```kotlin
android {
    defaultConfig {
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
        externalNativeBuild {
            cmake {
                path = "src/main/jni/whisper/CMakeLists.txt"
            }
        }
    }
}
```

**Step 2: 复制 JNI 源码**
从 `/tmp/whisper.cpp-repo/examples/whisper.android/lib/src/main/jni/` 复制：
- `whisper/` 目录（whisper.cpp, whisper.h, jni.c, CMakeLists.txt）
- `ggml/` 目录（ggml 库源码）

修改 `jni.c` 中的包名：
```
Java_com_whispercpp_whisper_WhisperLib_00024Companion_* 
→ 
Java_com_example_dodroidai_ai_voice_WhisperLib_00024Companion_*
```

**Step 3: 创建 WhisperRecorder.kt**
使用 `AudioRecord` 录制 16kHz mono PCM 16bit 音频：
```kotlin
val sampleRate = 16000
val channelConfig = AudioFormat.CHANNEL_IN_MONO
val audioFormat = AudioFormat.ENCODING_PCM_16BIT
```

**Step 4: 创建 WhisperContext.kt**
封装 JNI 调用，提供 `transcribeData(data: FloatArray): String` 方法。

**Step 5: 重写 VoiceInputManager.kt**
保持 `VoiceRecognitionCallback` 接口不变，内部实现替换为 Whisper。

**Step 6: 下载模型**
```bash
curl -L -o app/src/main/assets/models/ggml-base.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
```

#### 音频参数

| 参数 | 值 |
|------|------|
| 采样率 | 16000 Hz |
| 声道 | MONO |
| 位深 | PCM 16bit |
| 缓冲区 | minBufferSize * 4 |

RMS 计算（用于波形显示）：
```kotlin
20 * log10(rms / 32767.0)
```

#### 关键参考文件

- Whisper Android 示例：`/tmp/whisper.cpp-repo/examples/whisper.android/`
- Kotlin 封装参考：`/tmp/whisper.cpp-repo/examples/whisper.android/lib/src/main/java/com/whispercpp/whisper/LibWhisper.kt`
- JNI 实现参考：`/tmp/whisper.cpp-repo/examples/whisper.android/lib/src/main/jni/whisper/jni.c`
- 录音实现参考：`/tmp/whisper.cpp-repo/examples/whisper.android/app/src/main/java/com/whispercppdemo/recorder/Recorder.kt`

### 3. TTS 服务
**文件**: `app/src/main/java/com/example/dodroidai/ai/voice/TtsManager.kt`（新增）

```kotlin
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

    fun initialize(listener: InitListener) {
        tts = TextToSpeech(context) { status ->
            isInitialized = status == TextToSpeech.SUCCESS
            if (isInitialized) {
                tts?.language = Locale.CHINESE
                listener.onInitSuccess()
            } else {
                listener.onInitError("TTS 初始化失败")
            }
        }
    }

    fun speak(text: String, queueMode: Int = TextToSpeech.QUEUE_FLUSH) {
        if (isInitialized) {
            tts?.speak(text, queueMode, null, null)
        }
    }

    fun stop() {
        tts?.stop()
    }

    fun setSpeechRate(rate: Float) {
        tts?.setSpeechRate(rate)
    }

    fun shutdown() {
        tts?.shutdown()
    }
}
```

### 4. ChatInputBox 绑定语音事件
**文件**: `app/src/main/java/com/example/dodroidai/ui/chat/input/ChatInputBox.kt`

现有模式切换已实现，只需绑定语音事件：
- `voiceHint` 按下（ACTION_DOWN）开始语音识别
- `voiceHint` 抬起（ACTION_UP）停止语音识别
- 通过 `onVoiceInputListener` 回调通知 ChatFragment

```kotlin
// voiceHint 按下开始
voiceHint.setOnTouchListener { _, event ->
    when (event.action) {
        MotionEvent.ACTION_DOWN -> {
            onVoiceInputListener?.onVoiceStart()
            true
        }
        MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
            onVoiceInputListener?.onVoiceEnd()
            true
        }
        else -> false
    }
}
```

### 5. 修改 ChatFragment
**文件**: `app/src/main/java/com/example/dodroidai/ui/chat/ChatFragment.kt`

1. 初始化 VoiceInputManager 和 TtsManager
2. 实现 ChatInputBox.OnVoiceInputListener 回调
3. 语音识别结果转为文字后发送到聊天
4. AI 回复完成后自动朗读

## 文件清单

| 操作 | 文件路径 |
|------|----------|
| 修改 | `AndroidManifest.xml` - 添加 RECORD_AUDIO 权限 |
| 新增 | `ai/voice/VoiceInputManager.kt` - 语音输入管理 |
| 新增 | `ai/voice/TtsManager.kt` - TTS 管理 |
| 修改 | `ui/chat/input/ChatInputBox.kt` - 绑定语音按下/抬起事件 |
| 修改 | `ui/chat/ChatFragment.kt` - 集成语音服务 |

## 实现状态

已完成以下工作：

- [x] 配置 build.gradle.kts 添加 CMake 构建
- [x] 复制 whisper.cpp 和 ggml 源码到 app/src/main/jni/
- [x] 修改 jni.c 包名为 `com.example.dodroidai.ai.voice`
- [x] 创建 WhisperRecorder.kt（音频录制）
- [x] 创建 WhisperContext.kt（Whisper JNI 封装）
- [x] 创建 WhisperCpuConfig.kt（CPU 核心数配置）
- [x] 重写 VoiceInputManager.kt 为 Whisper 实现
- [x] 下载 ggml-base.bin 模型到 assets/models/

## 验证计划

1. **编译验证**：CMake 构建成功，SO 库正确生成
2. **录音验证**： WhisperRecorder 录制的数据格式正确
3. **模型加载验证**：首次打开语音输入时模型加载成功
4. **端到端测试**：完整语音输入流程，验证识别结果
5. **离线测试**：飞行模式下测试语音输入