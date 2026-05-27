# Android Agent APP 开发任务清单

## 项目现状
- ✅ 已实现：对话循环（用户输入 → 发送给LLM → 接收回复 → 展示）
- ✅ 已实现：保留最近20条消息作为短期上下文
- ⏳ 待实现：以下按优先级排列

---

## P0 级任务（必须实现，否则 Agent 不完整）

### 1. 工具调用 / Function Calling ✅
**目标**：让 LLM 能够调用安卓系统能力（闹钟、日历、短信、笔记等）。

**实现要点**：
- 在请求 LLM 时，传入 `tools` 参数（JSON Schema 格式），定义可用工具列表。
- 解析 LLM 返回的 `tool_calls` 字段，获取工具名称和参数。
- 在安卓端实现 `ToolExecutor`，根据工具名调用对应系统 API。
- 将执行结果封装成 `ToolResult`，通过 `role: "tool"` 消息返回给 LLM，生成最终回复。

**涉及工具**（初期）：
- `set_alarm`：设置闹钟
- `add_calendar_event`：添加日历事件
- `send_sms`：发送短信
- `add_note`：添加笔记
- `get_current_time`：获取当前时间

**代码位置**：
- `ToolsDefinition.kt`：定义工具 Schema
- `ToolExecutor.kt`：执行工具并返回结果
- `ConversationManager.kt`：处理工具调用流程

---

### 2. 流式输出（Streaming） ✅
**目标**：逐字显示 LLM 回复，提升用户体验。

**实现要点**：
- 使用 OkHttp 或 Retrofit 开启 SSE（Server-Sent Events）连接。
- 监听 `delta.content` 字段，每收到一个片段就追加到 TextView。
- 若返回 `tool_calls`，则不显示中间内容，静默执行。
- 处理流结束、错误重连等边缘情况。

**技术依赖**：
- OkHttp `EventSource`
- 或 Retrofit + `@Streaming` 注解

---

### 3. 本地长期记忆
**目标**：记住用户偏好和重要信息，跨会话可用。

**实现要点**：
- **结构化记忆**：用 Room 存储键值对，如 `key: "user_home_city"`, `value: "北京"`。
- **非结构化记忆**：用向量数据库（`LiteVectordb` 或 `SQLiteVec`）存储语义片段。
- **检索时机**：每次用户输入后，检索 top-3 相关记忆，注入到 system prompt。
- **存储时机**：每次对话后，调用 LLM 判断是否有值得记住的新信息（如“我住在上海”），自动写入记忆库。

**依赖库**：
- `androidx.room:room-ktx`
- `com.github.ammarptn:LiteVectordb:1.0.0` 或 `SQLiteVec`

---

### 4. 敏感操作确认与权限管理 ✅
**目标**：防止误操作，保护用户隐私和数据安全。

**实现要点**：
- 在 `ToolExecutor` 中定义风险等级：`HIGH`（发送短信、删除笔记）、`MEDIUM`（添加日历）、`LOW`（获取时间）。
- 高风险工具执行前，弹出 `AlertDialog` 让用户确认。
- 动态申请敏感权限（发送短信、读取日历等），使用 `ActivityResultContracts.RequestPermission`。
- 记录用户对每个工具的信任授权，下次可免确认（可选）。

---

## P1 级任务（强烈推荐，大幅提升实用性）

### 5. 联网搜索（Web Search） ✅
**目标**：获取实时信息（天气、新闻、股票等）。

**实现要点**：
- 选择一个搜索 API（推荐 Brave Search，每月 2000 次免费）。
- 定义 `web_search` 工具，参数 `query`。
- 在 `ToolExecutor` 中实现 HTTP 请求，解析 JSON 结果。
- 格式化结果为前 3-5 条（标题 + 链接 + 摘要），返回给 LLM。
- 添加缓存（相同关键词 10 分钟内复用结果），节省配额。

---

### 6. 语音输入 + TTS 输出 ✅
**目标**：全语音交互，解放双手。

**实现要点**：
- **语音输入**：使用 Android `SpeechRecognizer`（联网）或集成 `Whisper.cpp`（离线）。
- **TTS 输出**：使用 Android `TextToSpeech`，支持中文、可调语速/音调。
- 提供 UI 按钮（麦克风图标）触发语音输入。
- 在 Agent 回复后自动朗读（可配置开关）。

**注意**：
- 需要 `RECORD_AUDIO` 权限。
- TTS 初始化可能失败，需降级方案。

---

### 7. 支持多模型切换（自带 API Key） ✅
**目标**：用户可自由选择 OpenAI、Claude、MiniMax、DeepSeek 等模型。

**实现要点**：
- 设计统一的 `LLMProvider` 接口（`chat`、`streamChat` 方法）。
- 为每个模型实现适配器（`OpenAIAdapter`、`ClaudeAdapter` 等），处理不同的 API 格式。
- 创建 `ModelManager` 管理已配置的模型列表。
- 在设置页面提供“添加模型”界面，用户输入 API Key 和 Base URL。
- 使用 Android Keystore 加密存储 API Key。

---

## P2 级任务（体验优化，可后续迭代）

### 8. 深度思考过程展示 ✅
**目标**：当模型支持推理过程（如 DeepSeek R1、OpenAI o1）时，显示思考步骤。

**实现要点**：
- 解析流式响应中的 `reasoning_content` 或 `<think>` 标签。
- 在 UI 上用可折叠卡片展示思考过程，默认展开或折叠由用户设置。
- 思考结束后再显示最终答案。

---

### 9. 对话管理（多会话、历史导出） ✅
**目标**：支持多个对话 session，方便查阅和整理。

**实现要点**：
- 使用 Room 存储每个会话的消息列表。
- 提供会话列表页面（侧边栏），支持新建、重命名、删除会话。
- 导出对话为纯文本或 Markdown 文件（通过 `Intent.ACTION_CREATE_DOCUMENT`）。
- 搜索历史对话内容（可选，需要全文索引）。

---

### 10. 桌面小组件（Widget）
**目标**：主屏幕快速唤醒 Agent，无需打开 App。

**实现要点**：
- 创建 `AppWidgetProvider`，提供 1x4 或 2x2 布局。
- 点击小组件后打开语音输入界面或直接触发预设指令（如“你好”）。
- 注意小组件的刷新策略（避免频繁更新）。

---

### 11.页面交互重构
**目标**：将对话页作为主界面

**实现要点**:
- app改为默认进对话页，支持无sessionid进入，此时对话内容区域支持展示空白文字引导
- 改为用户发送消息时创建session
- 对话页左上角back按钮改成menu按钮，点击以侧边栏的形式展示对话列表页，使用Android官方侧边栏api

---

## 附录：推荐实现顺序

| 阶段 | 任务 | 预估工作量 |
|------|------|------------|
| 第1周 | 工具调用（核心3-5个工具） | 5天 |
| 第2周 | 流式输出 + 敏感操作确认 | 3天 |
| 第3周 | 长期记忆（结构化 + 向量） | 5天 |
| 第4周 | 语音输入 + TTS | 3天 |
| 第5周 | 联网搜索 | 2天 |
| 第6周 | 多模型切换 | 3天 |
| 后续 | 深度思考展示、对话管理、小组件 | 按需 |

---

## 技术依赖汇总（建议版本）

```gradle
dependencies {
    // 网络
    implementation 'com.squareup.okhttp3:okhttp:4.12.0'
    implementation 'com.squareup.retrofit2:retrofit:2.9.0'
    implementation 'com.squareup.retrofit2:converter-gson:2.9.0'
    
    // 数据库
    implementation 'androidx.room:room-runtime:2.6.1'
    implementation 'androidx.room:room-ktx:2.6.1'
    implementation 'com.github.ammarptn:LiteVectordb:1.0.0'
    
    // 安全存储
    implementation 'androidx.security:security-crypto:1.1.0-alpha06'
    
    // 协程
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3'
    
    // JSON
    implementation 'com.google.code.gson:gson:2.10.1'
}