# AGENTS.md

本文件是仓库的工程约定与代码地图，面向 AI 编码代理与新加入的开发者。
用户向文档见 [README.md](README.md)（英文）和 [README_zh.md](README_zh.md)（中文）。

## 1. 项目是什么

DoDroidAI 是一个 Android Agent 应用：用户用自然语言下指令，应用把指令发给 LLM，由 LLM 通过
tool calling 调用手机系统能力（闹钟、日历、短信、笔记、联网搜索、剪贴板、通讯录）完成任务。

**当前实现：Flutter（`flutter_app/`）**。原生 Kotlin/XML 版本已于 2026-11 完整移除，
git 历史中仍可查阅。

一次完整请求的数据流：

```
用户输入
  └─> ChatController.send()
        ├─ 取全部历史消息，超模型窗口 80% 时滚动压缩（见 4.2 上下文压缩）
        ├─ 按开关决定是否把 web_search 放进工具列表
        ├─ system prompt 注入长期记忆（相关性检索）
        ├─ ChatApi.stream() → POST /v1/chat/completions 或 /v1/messages（SSE 流式）
        ├─ 解析 content / reasoning / tool_calls 增量，写入有序内容块
        ├─ tool_call → ToolRegistry.execute()
        │     ├─ HIGH 风险：先弹应用内确认框
        │     ├─ 缺运行时权限：permission_handler 申请
        │     └─ 结果作为 tool 消息回填
        ├─ 带工具结果再次请求（最多 5 轮）
        ├─ 最终回复写入 sqflite（sessions/messages）
        └─ 后台异步提炼新记忆（失败静默，不阻塞 UI）
```

- 包名：`com.mohanlv.dodroidai`
- 技术栈：Flutter 3.47 / Dart 3.13、Riverpod、dio 5（SSE）、sqflite、sherpa_onnx 2.0.1（FFI）、
  record、audioplayers、workmanager、flutter_local_notifications
- 构建产物：仅 `arm64-v8a` 单包（release 约 49MB）

## 2. 构建与验证

| 目的 | 命令（在 `flutter_app/` 下） |
| --- | --- |
| 分析 | `flutter analyze` |
| 单测 | `flutter test` |
| Debug APK | `flutter build apk --debug` |
| Release APK | `flutter build apk --release` |
| 安装 | `adb install -r build/app/outputs/flutter-apk/app-debug.apk` |
| 集成测试 | `flutter test integration_test -d <device>` |

环境前提：

- Flutter SDK（本机在 `~/flutter`）
- 安装内部测试时用 `adb install -r -d`（`-d` 允许版本降级，否则会被系统拒绝但静默失败）
- 构建后务必确认输出 `✓ Built` 再 install；install 后确认 `Success`

验证约定：

- 最低标准：`flutter analyze` 无 error + `flutter test` 全绿 + 真机回归相关流程
- 改语音相关逻辑时重点回归：录音权限、TTS 首包延迟、播放连贯性
- 改聊天/工具逻辑时重点回归：流式输出、思考块渲染、工具确认弹窗、权限拒绝分支、会话恢复

## 3. 代码地图

| 职责 | 位置 |
| --- | --- |
| 应用入口、启动初始化（UI 优先，后台服务异步） | `lib/main.dart` |
| 主题、语言、MaterialApp | `lib/app.dart` |
| 主题色与排版 | `lib/theme/app_theme.dart` |
| AI 配置模型、多配置持久化 | `lib/ai/ai_config.dart` |
| 请求构建与 SSE 解析 | `lib/ai/chat_api.dart` |
| 上下文压缩（滚动增量摘要） | `lib/ai/context_compressor.dart` |
| 长期记忆自动提炼 | `lib/ai/memory_extractor.dart` |
| 轻量文本嵌入（哈希 n-gram + 余弦） | `lib/ai/text_embedding.dart` |
| 工具契约、注册、执行 | `lib/ai/tools.dart` |
| 会话检索工具（只读，5 个 session_*） | `lib/ai/session_tools.dart` |
| 联网搜索 | `lib/ai/web_search.dart` |
| TTS（Matcha/MeloTTS，逐句合成 + 合并播放） | `lib/ai/sherpa_tts.dart` |
| ASR（SenseVoice） | `lib/ai/sherpa_asr.dart` |
| 语音引擎常驻 isolate | `lib/ai/speech_worker.dart` |
| 模型目录与下载 | `lib/ai/model_catalog.dart`、`lib/ai/model_manager.dart` |
| 全局下载管理器（页面退出后继续） | `lib/ai/download_manager.dart` |
| 请求追踪 | `lib/ai/request_trace.dart` |
| 消息模型（有序内容块） | `lib/models/chat_message.dart` |
| 聊天状态机、工具循环、流式写入 | `lib/screens/chat/chat_provider.dart` |
| 聊天页、会话抽屉、输入框 | `lib/screens/chat/` |
| 消息气泡（折叠块 + 状态 tag） | `lib/screens/chat/widgets/message_bubble.dart` |
| 设置页与二级页 | `lib/screens/settings/` |
| 笔记 / 记忆 / 定时任务 | `lib/screens/notes/`、`memory/`、`tasks/` |
| 数据库（会话、消息、笔记、记忆、任务、审计） | `lib/data/` |
| 本地化 | `lib/l10n/` |

## 4. 必须遵守的约定

### 4.1 消息内容块

`ChatMessage.blocks` 是消息内容的唯一数据源：

```dart
enum MessageBlockKind { reasoning, toolCall, text }
class MessageBlock { kind, text, ToolCallInfo? tool, seconds }
```

- 流式写入时按事件类型分块：reasoning 增量进 reasoning 块、content 增量进 text 块、
  一轮结束产生的工具调用按顺序进 toolCall 块
- 渲染顺序即 blocks 顺序，保证「思考 → 工具 → 思考 → 正文」的真实时序
- 除正文外所有内容都用 `_CollapsibleBlock`（箭头 + 标题 + 可折叠内容），工具状态用 `_StatusTag`
- `content` 仍是正文汇总字段（朗读、复制、请求编码依赖它）
- `toolCalls` 是从 blocks 派生的 getter，不要改回独立字段

### 4.2 AI 协议

- 支持两种格式，由 `AIConfig.apiFormat` 选择：
  - `anthropicMessages`：`{base}/v1/messages`，`X-Api-Key`
  - `openaiChatCompletions`：`{base}/v1/chat/completions`，`Authorization: Bearer`
- `baseUrl` 统一视为根地址，`normalizeBaseUrl()` 会去掉尾部 `/v1` 等后缀
- 深度思考开关：OpenAI 格式传 `reasoning_effort`（high/none），Anthropic 传 `thinking`
- 上下文管理见 4.2.1（超窗口滚动摘要，不再固定取最近 20 条）；工具循环最多 5 轮
- OpenCode Go 需要 `x-opencode-session` header（稳定 session id，用于路由与 prompt cache）

### 4.2.1 上下文压缩与长期记忆

- 上下文压缩由 `lib/ai/context_compressor.dart` 完成：消息总 token 超过
  `contextWindow * 0.8` 时触发，保留最近约 40% 预算的消息，其余压缩成一条摘要
  user 消息；dart-define `CTX_TRIGGER` 可覆盖触发阈值（调试用，此时保留预算为其 50%）
- **滚动增量摘要**：已摘要的部分（条数 + 摘要文本）持久化在
  `session_context` 表；下一轮只摘要「新增落入旧段的消息」，旧段没变化直接复用，
  不再全量重摘。摘要失败降级为占位文本且不覆盖已存摘要
- 长期记忆 `memory.db`：`MemoryRepository.insert` 自带语义去重（余弦 ≥ 0.88 视为
  重复）；`searchRelevant` 用 `lib/ai/text_embedding.dart` 的哈希字符 n-gram 嵌入
  （0.65 语义 + 0.35 词面 Jaccard 混合评分），旧数据缺向量时懒回填
- system prompt 记忆注入：记忆 ≤ 20 条全量注入；更多时按最近一条用户消息做
  相关性检索取 8 条 + 最近 4 条（去重）
- 每轮对话结束后后台提炼新记忆（`lib/ai/memory_extractor.dart`，最多 3 条 JSON），
  走 `MemoryRepository.insert` 自动去重；默认开启，`SharedPreferences` 键
  `memory_auto_extract`（`false` 关闭），失败静默

### 4.3 工具

新增工具：

1. 在 `lib/ai/tools.dart` 的 `definitions` 里加 JSON Schema
2. 在 `execute()` 的 switch 里加分支
3. 高风险工具加进 `highRiskTools`（短信、笔记等），执行前会弹确认
4. 需要运行时权限的加进 `permissionsFor`（短信/通讯录/日历）

约定：

- 工具名是模型可见的稳定标识，改名属于破坏性变更
- 工具执行结果直接返回字符串给模型，不要抛异常
- 每次执行写入 `tool_audit_log`（工具名/参数摘要/结果）
- 原生侧桥接用 `MethodChannel('dodroidai/native')`（目前只有 `searchContacts`）
- 会话检索工具（`session_search` / `session_event_search` / `session_event_read` /
  `session_trace` / `session_event_trace`）全部只读，执行逻辑在 `lib/ai/session_tools.dart`；
  当前会话 id 由 `ToolRegistry.execute(..., sessionId:)` 传入，省略时用当前会话
- `web_search` 的 `queries` 接受 1-4 个关键词：串行请求（Brave 免费版约 1 QPS）、
  结果按 query 分节并全局 URL 去重，单个查询失败不影响其他查询；旧 `query` 参数仍兼容
- 记忆工具：`remember_fact`（语义去重，重复时返回已有条目）、`recall_memory`
  （相关性检索）、`forget_memory`（检索 score ≥ 0.5 才删，删前列出确认）；执行逻辑
  在 `lib/ai/tools.dart`，检索/去重在 `lib/data/memory_database.dart`

### 4.3.1 交互式工具 `ask_user_question`

模型需要确认、选择或补充信息时调用，对齐 DSH 的 timed 模式：

- 参数：`questions[]`（`id`/`question` 必填，`header`/`options[]{label,description}`/`multi_select` 可选）
  + `timeout`（秒，默认 120，`-1` 无限，合法 `-1` 或 `1..2147483`）
- 结果两种形态：
  - 按时回答 `{"answers":[{"id","selected":[],"custom"?}]}`，**跳过 = 空 `selected` 且无 `custom`**
  - 超时 `{"pending":true,"callId","message"}`，模型继续做独立工作
- 挂起机制：`ChatState.pendingQuestions` + `Completer<AskOutcome>` + `Timer(deadline)`，
  UI 由 `ask_question_sheet.dart` 渲染（倒计时、单选/多选/自定义、逐题跳过）
- 超时后问题落库 `pending_questions` 表，输入框上方显示待答横幅，补答时注入带
  `[answer_to_pending_question callId=...]` 标记的 user 消息并触发新一轮
- 新增交互式工具走同一路径：`ToolRegistry.isInteractive()` + `ChatController._askQuestions()`

### 4.4 语音

语音是主交互形式：输入框默认语音模式（按住说话），助手回复默认自动朗读（可在对话设置关闭，持久化在 `auto_read`）。

- ASR：sherpa-onnx + SenseVoice，按住说话，16kHz 单声道
- TTS：Matcha（默认，首包 ~350ms，依赖 `vocos-16khz-univ.onnx`）与 MeloTTS（备选）
- 合成在常驻 isolate（`SpeechWorker`）里执行，**不要在 UI isolate 直接调 sherpa**
- 播放策略：首句先播，其余句子合成后合并成一个 wav，整段只切换一次
- 朗读可打断：`SherpaTts.stop()` 自增 `_speakSeq` 并使进行中的朗读在检查点退出；开始录音前会先停朗读，避免麦克风录入外放
- 模型不随包；`VoiceBootstrap.ensureModels()` 在启动时自动准备：已就绪直接预热，Wi-Fi/以太网下自动下载缺失模型（ASR 默认 SenseVoice、TTS 默认 Matcha），
  蜂窝/无网时不下载并在输入区提示等待 Wi-Fi。下载在 `DownloadManager` 全局进行（退出页面不中断），输入区状态条展示进度
- 下载后校验文件大小（±5% 容差，HF revision 波动不影响），失败清理半成品；仅在无可用激活模型时自动启用
- ASR/TTS 启动预热：`SherpaAsr.warmUp()` / `SherpaTts.warmUp()`，失败或模型未就绪时清空缓存，下载完成后可再次预热
- 模型切换与手动下载仍在「设置 → 语音」页（本页不加新区块）

### 4.5 数据与持久化

- 会话/消息：`dodroidai_flutter.db`（sqflite，当前 version 6），`messages.blocks` 存 JSON，
  `pending_questions` 存超时未答的问题；v6 新增 `session_context` 表
  （session_id/summary/summarized_count/updated_at，滚动摘要持久化）
- 记忆：独立 `memory.db`（当前 version 2），`memory_facts` 表 v2 新增 `embedding`
  TEXT 列（JSON 向量，懒回填）；语义去重与检索依赖该列
- 数据库版本变更必须写 `onUpgrade` 迁移，且 `onCreate` 与迁移列保持一致
- 新会话懒创建：只有发送第一条消息时才写库，启动和点「+」不落库
- 笔记/记忆/定时任务各自独立表

### 4.6 UI

- 深浅色都要检查（`lib/theme/app_theme.dart` 的 surface 分别是 `#FFFFFF` / `#161920`）
- 启动背景色（`android/app/src/main/res/values{,-night}/styles.xml`）必须与 surface 一致，否则黑屏闪烁
- 设置页结构：AI / 应用（语言、外观、联网搜索、工具审计、语音、诊断、请求追踪、关于、对话）
- 笔记/记忆/定时任务入口在侧边栏的两列网格，不在设置页

## 5. 已知问题与坑

1. **`adb install` 会静默失败**：版本降级时提示 `INSTALL_FAILED_VERSION_DOWNGRADE`，
   必须加 `-d`，否则你以为更新了其实跑的是旧包
2. **adb 触摸不可靠**：输入框区域的点击常常丢失；需要精确坐标时先 `uiautomator dump` 拿 bounds，
   不要靠截图估算
3. **`generateWithCallback` 对 Matcha 不返回**：改用逐句 `generate`
4. **`audioplayers` 的 `onPlayerComplete` 不稳定**：改为按 wav 文件头计算时长等待
5. **Matcha 必须配 vocos-16khz-univ.onnx**（54MB）：模型仓库根目录不含该文件，清单从 `wmghf2023/vocos-16khz-univ-mirror` 拉取；
   缺文件时 `SherpaTts.isReady()` 恒 false，自动朗读会静默失效
6. **模型文件大小校验用 ±5% 容差**：`model_catalog.dart` 里手写的是实测值，上游 revision 变化时不至于整包失败，同时能识别半截文件
7. **`onAmplitudeChanged` 是单订阅流**：第二次录音会抛 `Stream has already been listened to`，
   改用定时轮询 `getAmplitude()`
8. **compileSdk 必须 ≥37**：`permission_handler_android` 的 AAR 元数据要求
9. **`android/app/build.gradle.kts` 锁定了 `abiFilters` 只打 arm64-v8a**
10. **Release 用 debug 签名**，正式发布前需替换签名配置

## 6. 修改守则

Do：

- 小步提交，按模块验证；先 `flutter analyze`，再 `flutter test`，最后真机
- 新功能先复用现有抽象（`MessageBlock`、`ToolRegistry`、`AIConfig`、`DownloadManager`）
- 提交信息沿用 `feat:` / `fix:` / `perf:` / `chore:` + 中文描述

Don't：

- 不要修改 `applicationId`、包名（除非需求明确）
- 不要把 API Key 写进代码、日志或文档
- 不要提交 `build/`、`.dart_tool/`、`local.properties`
- 不要顺手格式化无关文件，避免 diff 噪声

## 7. 文档维护

- 本文件是工程约定的唯一来源；`CLAUDE.md` 通过 `@AGENTS.md` 引用，避免两份漂移
- 用户向文档是 `README.md` / `README_zh.md`；功能、命令、结构变化时同步更新
- `docs/FLUTTER_MIGRATION.md` 记录迁移过程，`docs/ui-compare/` 是 UI 对照素材
- `plan/` 是历史设计文档，`TodoTasks.md` 是开发任务清单；两者保留供追溯，内容可能落后于实现
