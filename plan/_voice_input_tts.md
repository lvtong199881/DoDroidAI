# 语音输入 + TTS 输出实现计划

## Context
TodoTasks.md P1 级任务 #6，实现全语音交互，解放双手。

**实现要点**：
- 语音输入：使用 Android `SpeechRecognizer`（联网）或 `Whisper.cpp`（离线）
- TTS 输出：使用 Android `TextToSpeech`，支持中文、可调语速/音调
- UI 按钮（麦克风图标）触发语音输入
- Agent 回复后自动朗读（可配置开关）
- 需要 `RECORD_AUDIO` 权限

## 实现方案

### 1. 权限配置
**文件**: `app/src/main/AndroidManifest.xml`

添加权限：
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### 2. 集成 Whisper.cpp
**文件**: `app/src/main/java/com/example/dodroidai/ai/voice/VoiceInputManager.kt`（新增）

使用 Whisper.cpp 库进行离线语音识别：
- 依赖 `whisper.cpp` native library
- 使用 `VoiceRecognitionCallback` 回调识别结果

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

## 验证方案

1. 语音输入：
   - 切换到语音模式
   - 按住 voiceHint 区域说话
   - 验证语音转为文字显示在输入框
2. TTS 输出：
   - 发送消息让 AI 回复
   - 验证 AI 回复后自动朗读
3. 权限：
   - 首次使用语音功能时验证权限请求