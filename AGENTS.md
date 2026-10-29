# AGENTS.md

本文件是本仓库的工程约定与代码地图，面向 AI 编码代理（Claude Code / Codex / Cursor 等）以及新加入的开发者。
动手改代码前请先读完；用户向文档见 [README.md](README.md)（英文）和 [README_zh.md](README_zh.md)（中文）。

## 1. 项目是什么

DoDroidAI 是一个 Android Agent 应用：用户在聊天界面用自然语言下指令，应用把指令发给 LLM，由 LLM 通过
tool calling 调用手机系统能力（闹钟、日历、短信、笔记、联网搜索）完成任务。

一次完整请求的数据流：

```
用户输入
  └─> ChatViewModel.sendMessage()
        ├─ 取最近 20 条消息（MAX_CONTEXT_MESSAGES）
        ├─ 按开关决定是否把 web_search 放进工具列表
        ├─ ApiRequestFactory → POST /v1/messages（Anthropic）或 /v1/chat/completions（OpenAI）
        │    （对应 SSE 流式解析）
        ├─ 解析 content / thinking / tool_use 增量
        ├─ tool_use → ToolExecutor.execute()
        │     ├─ HIGH 风险：先弹应用内确认框
        │     ├─ 缺运行时权限：先请求权限
        │     └─ 结果封装为 tool_result（role = tool）
        ├─ 带工具结果再次请求（最多 5 轮，MAX_TOOL_CALL_DEPTH）
        └─ 最终回复写入 ChatRepository（DataStore）
```

- 包名 / applicationId / namespace：`com.example.dodroidai`
- 模块：`:app`（应用）、`:webview-sdk`（可独立复用的 WebView 组件库）
- 架构：单 Activity + Fragment + MVVM（ViewModel + DataStore Repository）；没有 DI 框架，没有 Room
- UI：XML Views + Material 3，ViewBinding 未启用（使用 `findViewById`）
- 语言：Kotlin 2.0.21；C/C++（whisper.cpp + ggml，JNI）
- 构建：Gradle 9.1.0（wrapper）/ AGP 9.0.1 / JDK 17 / compileSdk 36 / minSdk 24
- 原生 ABI：仅 `arm64-v8a`、`armeabi-v7a`

## 2. 构建与验证

| 目的 | 命令 |
| --- | --- |
| 构建 Debug APK | `./gradlew assembleDebug` |
| 只构建 app | `./gradlew :app:assembleDebug` |
| 只构建 webview-sdk | `./gradlew :webview-sdk:assembleDebug` |
| 构建 Release APK | `./gradlew assembleRelease` |
| Android Lint | `./gradlew lintDebug` |
| 清理 | `./gradlew clean` |
| 安装到设备 | `adb install -r app/build/outputs/apk/debug/app-debug.apk` |

环境前提：

- `local.properties` 中的 `sdk.dir` 指向本机 Android SDK。该文件已被 git 忽略，不要提交。
- JDK 17。
- NDK + CMake：whisper/ggml 通过 `externalNativeBuild` 编译，首次构建或清理后构建明显变慢。
- Gradle wrapper 的发行版地址是腾讯云镜像（`gradle/wrapper/gradle-wrapper.properties`）；换网络环境时按需修改。
- 只打包 `arm64-v8a` / `armeabi-v7a`。x86_64 模拟器通常无法直接安装，调试请用 ARM 设备或支持 ARM 转译的镜像。

验证约定（重要）：

- 仓库当前**没有**单元测试/仪器测试（`app/src` 下只有 `main`），CI 也没有 PR 自动检查。
- 最低验证标准：改动模块 `assembleDebug` 通过 + `lintDebug` 无新增严重问题 + 真机回归相关流程。
- 改 `:webview-sdk` 时同时构建 `:webview-sdk:assembleDebug` 和 `:app:assembleDebug`（app 依赖该模块）。
- 改 AI / 工具逻辑时重点回归：流式输出、thinking 展示、工具确认弹窗、权限拒绝分支、会话保存与恢复。
- 改 native 代码时至少构建一次带 NDK 的 `:app:assembleDebug`，否则 JNI 问题不会暴露。

## 3. 代码地图

| 职责 | 位置 |
| --- | --- |
| 应用入口、Drawer、主题/语言注入、快捷方式跳转 | `app/src/main/java/com/example/dodroidai/MainActivity.kt` |
| Application、全局 ChatRepository / ToolExecutor | `app/src/main/java/com/example/dodroidai/DoDroidAIApplication.kt` |
| AI 配置模型、多配置持久化与旧数据迁移 | `ai/config/AIConfig.kt`、`ai/config/AppConfigManager.kt` |
| 协议选择、URL 规范化与请求构建 | `ai/model/ApiFormat.kt`、`ai/model/ApiEndpoint.kt`、`ai/model/ApiRequestFactory.kt`、`ai/model/RequestFactory.kt` |
| 附件模型、编码与请求构建 | `ai/model/ChatAttachment.kt`、`ai/model/ChatRequestBuilder.kt`、`ai/model/OpenAiChatRequestBuilder.kt`、`ai/attachments/` |
| Anthropic 请求体构造 | `ai/model/RequestFactory.kt`、`ai/model/AnthropicModels.kt` |
| SSE 客户端与事件解析 | `ai/streaming/StreamingChatClient.kt`、`ai/streaming/AnthropicSseListener.kt`、`ai/streaming/OpenAiSseListener.kt`、`ai/streaming/OpenAiSseParser.kt` |
| 聊天状态机、流式更新、工具循环 | `ui/chat/ChatViewModel.kt` |
| 聊天页面与列表 | `ui/chat/ChatFragment.kt`、`ui/chat/ChatListFragment.kt`、`ui/chat/adapter/`、`ui/chat/input/` |
| 工具抽象、注册、Schema | `ai/tools/Tool.kt`、`ai/tools/ToolExecutor.kt`、`ai/tools/ToolsDefinition.kt`、`ai/tools/*Tool.kt` |
| 语音识别（whisper）与 TTS | `ai/voice/` |
| 会话模型与存储 | `data/model/ChatSession.kt`、`data/repository/ChatRepository.kt` |
| 闹钟触发接收器 | `alarm/AlarmReceiver.kt` |
| 桌面小组件（1x2 / 1x4 / 2x2） | `widget/` |
| 设置页、AI 配置列表、关于页 | `ui/setting/` |
| 通用弹窗、Toolbar、设置项 | `ui/common/` |
| WebView 组件库 | `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/` |
| whisper.cpp 源码 | 仓库根 `src/`、`include/` |
| whisper JNI / CMake / ggml | `app/src/main/jni/whisper/`、`app/src/main/jni/ggml/` |
| 内置 Whisper 模型（约 43 MB） | `app/src/main/assets/models/ggml-tiny-q8_0.bin` |
| 版本目录 | `gradle/libs.versions.toml` |
| 历史设计文档 | `plan/` |
| 手动发布流水线 | `.github/workflows/appbuildfjhfjh.yml` |

## 4. 必须遵守的约定

### 4.1 新增 / 修改工具

工具是 LLM 的契约，改动要三处同步：

1. 在 `ai/tools/` 新增 `Tool` 实现：`name`、`requiredPermissions`、`riskLevel`、`hasPermissions`、
   `requestPermissions`、`execute`。
2. 在 `ToolExecutor` 的 `tools` 列表注册，并同步 `ToolExecutor.TOOL_NAMES`。
3. 在 `ToolsDefinition.getTools()` 增加对应的 `ToolDefinition`（description 和 JSON Schema 决定 LLM 何时调用）。

约定：

- `execute` 必须先检查权限，失败返回 `ToolResult(success = false, error = "...")`，不要抛异常给上层。
- 会改变用户数据或对外发送的操作（短信、笔记等）应设为 `RiskLevel.HIGH`，让 UI 弹确认；
  闹钟、日历这类可撤销的操作用 `MEDIUM`；只读操作 `LOW`。
- 工具名是模型可见的稳定标识，改名属于破坏性变更，需评估历史会话与提示词。
- 参数解析失败统一返回失败结果，不要让 Gson 异常冒泡。

### 4.2 AI 协议

- 支持两种格式，由 `AIConfig.apiFormat` 选择：
  - `ANTHROPIC_MESSAGES`：`{base}/v1/messages`，`X-Api-Key`，由 `AnthropicSseListener` 解析。
  - `OPENAI_CHAT_COMPLETIONS`：`{base}/v1/chat/completions`，`Authorization: Bearer`，由
    `OpenAiSseListener` + `OpenAiSseParser` 解析。
- `baseUrl` 统一视为根地址；`ApiEndpoint.normalizeBaseUrl()` 会自动去掉尾部 `/v1`、
  `/v1/messages`、`/v1/chat/completions`，不要让用户填完整路径。
- Anthropic 事件：`content_block_start/delta/stop`、`message_delta`、`message_stop`，异常走
  `onFailure`。
- OpenAI 事件：`choices[].delta.content`、`reasoning_content`/`reasoning`、分片
  `tool_calls`（按 index 合并 arguments）、`finish_reason`、`[DONE]`；错误体 `{"error":{...}}`。
- OpenAI 工具循环必须包含 assistant `tool_calls` 消息，再接 `role=tool` 消息；
  Anthropic 保持只追加 `tool_result`。`ChatMessage.toolCallPayloads` 只用于请求构建，
  UI 仍用 `ChatMessage.toolCalls`。
- 上下文窗口固定取最近 20 条（`getRecentMessages()`）；工具循环上限 5 轮。
- 新增第三种格式时：`ApiFormat` 增加枚举 → `ApiRequestFactory` 分支 → 新 listener/parser →
  对应请求与解析单测；不要把多种协议塞进一个巨型条件分支。
- 新增 provider 预设只需在 `AIConfig.default()` 增加分支（provider 枚举 + baseUrl + 模型名 +
  apiFormat），不要改协议实现。

### 4.3 配置与持久化

- `AppConfigManager` 是 `object`，必须在 `Application.onCreate` 调用 `init(this)`；否则 DataStore 访问会失败。
- `MainActivity.attachBaseContext` 只能同步读取 `cachedLanguage` / `cachedTheme`（SharedPreferences 镜像），
  不要在那里访问 DataStore 或调用 suspend 方法，否则会阻塞启动。
- 多配置存储为 `configs`（JSON 数组）+ `activeConfigId`；旧版单配置键的迁移在 `migrateIfNeeded()`。
  改 `AIConfig` 字段时保留默认值和迁移路径，Gson 反序列化依赖字段名。
- 配置以明文保存在 app 私有 DataStore 中。不要新增会打印 API Key、token 的日志；现有日志会打印消息内容，
  排查问题时注意脱敏。
- `ChatRepository` 每次读改写整个 sessions JSON（`filter` 掉同 id 再追加），没有增量存储。
  会话数量增长时注意主线程外 IO 与写放大。

### 4.4 Chat UI / 状态

- `ChatViewModel` 持有 `ChatUiState`（StateFlow）驱动消息列表；流式增量通过 `streamingMessagePosition` /
  `streamingContentUpdate` 直达对应 ViewHolder，避免每次增量都全量 `notifyDataSetChanged`。
- `ChatViewModel` 构造时接收 `Fragment` 引用（用于工具确认弹窗和权限请求）。不要在这个方向上再增加
  长生命周期持有；如果重构，优先改为通过 UI 事件回调。
- `checkAndRequestPermissions()` 是遗留的未调用方法；实际权限请求在 `executeToolCalls()` 内完成，
  不要重复实现一套。
- 工具调用消息以 `ToolCallDisplay` 存在 `ChatMessage.toolCalls` 中，用于 UI 折叠展示；修改数据结构要兼容
  已持久化的历史消息（Gson + 默认值）。

### 4.5 语音

- `VoiceInputManager` 从 assets 加载 `models/ggml-tiny-q8_0.bin`；替换模型要同步文件名、CMake 与 assets。
- whisper.cpp 源码在仓库根 `src/`、`include/`；JNI 入口是 `app/src/main/jni/whisper/jni.c`；
  CMake 通过 `FetchContent(SOURCE_DIR ...)` 引用 `app/src/main/jni/ggml`。
- 只编译 `arm64-v8a` / `armeabi-v7a`；CMake 对两个 ABI 分别设置 `-march=armv8.2-a+fp16` 与
  `-mfpu=neon-vfpv4`。新增 ABI 需要同时改 `app/build.gradle.kts` 和 `CMakeLists.txt`。
- 语音识别全程离线；不要引入需要联网的识别依赖，除非需求明确。

### 4.6 webview-sdk

- 它是独立 library module，**故意**不引用 app 的 `libs.versions.toml`（自管依赖版本），不要“顺手统一”。
- 对外入口是 `WebViewEntry.show(activity | fragmentManager, containerId, url)`；不要把 app 的容器 id
  硬编码进 sdk。
- H5 与 Native 的协议在 `WebToolbarBridge`（JS 全局对象 `WVToolbar`）：`setTitle`、`setTitleColor`、
  `setCloseVisible`、`setBackgroundGradient`、`setAlpha`、`setScrollAlphaRule`、`disableScrollAlpha`。
  改协议要同步 `webview-sdk/src/main/assets/wv/lookaround.html` 示例页与 `plan/` 中的设计文档。
- `WebFragment` 会临时把 Window 切到 edge-to-edge（`decorFitsSystemWindows = false`、透明状态栏、
  调整祖先 padding/margin），并在 `onDestroyView` 还原。改这段必须验证宿主 Activity 的其他 Fragment 不受影响。
- 返回键优先 `webView.goBack()`，不能再返回时才 `popBackStack()`。

### 4.7 资源、主题、本地化

- 字符串资源三套：`values/strings.xml`（英文，基准）、`values-zh-rCN`（已对齐）、
  `values-zh-rTW`（约 56/93 条，尚不完整）。新增字符串请三处同步；zh-rTW 缺失会回退英文。
- 主题：`values/themes.xml`（Material3 Light）+ `values-night/themes.xml`（Material3 Dark）；
  自定义颜色属性（`colorCardBackground` 等）在 `values/attrs.xml` 定义，新增控件时两套主题都要检查。
- 部分提示文案（工具确认框、错误信息等）是代码内中文硬编码。新增文案优先放进 `strings.xml`；
  若跟随所在文件的现有风格硬编码，至少保持语言一致，不要中英混排。
- 图标命名沿用现有前缀（`ic_*`、`bg_*`、`wv_ic_*`）。

### 4.8 附件

- `ChatMessage.attachments` 声明为 nullable（Gson 不会应用 Kotlin 默认值），读取统一 `orEmpty()`。
- `ChatAttachment.uri` 使用 String；输入框仍用 `AttachmentItem`（Uri），发送时通过
  `AttachmentLimits.toChatAttachment()` 转换。
- 图片：长边 ≤1568 px、JPEG ≤3 MB、base64 使用 `android.util.Base64`（minSdk 24 不能用
  `java.util.Base64`）；压缩/EXIF 方向处理在 `AttachmentEncoder`。
- PDF：PDFBox-Android 抽取文本层，`DoDroidAIApplication.onCreate` 必须调用
  `PDFBoxResourceLoader.init()`；扫描件不支持，Word 不支持。
- `AnthropicMessage.content` 是 `JsonElement`：纯文本用 `JsonPrimitive`，含附件或 `tool_result`
  时用 `JsonArray`；`tool_result` 必须用 `JsonObject` 构造，禁止字符串拼接 JSON。
- 附件预算、历史窗口、数量/大小限制集中在 `AttachmentLimits`；调整时同步更新 README 与本文档。
- 附件会发送给用户配置的 AI 服务商；不要在日志里打印 base64 或附件正文。

## 5. 已知问题与坑

按影响排序，修 bug 或重构时优先关注：

1. **baseUrl 约定**：配置里应填根地址；`ApiEndpoint.normalizeBaseUrl` 会自动去掉 `/v1` 等后缀。
   UI 提示仍应引导用户填根地址，避免误填完整路径。
2. **附件链路有边界**：图片作为 `image` block 发送，PDF/TXT 抽取文本；扫描件 PDF 不做 OCR，
   Word 不支持；只有最近 3 条 user 消息的附件会参与编码，更早的会降级为占位文本。
   请求构建在 `ChatRequestBuilder`，编码在 `AttachmentEncoder`。
3. **`add_note` 是占位实现**：`AddNoteTool` 只返回“笔记已添加”的字符串，没有真正写入任何笔记应用。
4. **没有测试与自动 CI 校验**：`.github/workflows/appbuildfjhfjh.yml` 仅手动触发，执行 `assembleRelease`
   并发布 GitHub Release。新增的单测在 `app/src/test`，尚未接入 CI。
5. **Release 使用仓库内测试 keystore**：`keystore/release.keystore`，口令硬编码在 `app/build.gradle.kts`。
   仅用于本地/CI 出包，正式发布必须换成自己的签名配置。
6. **Release 未开启混淆**：`isMinifyEnabled = false`，且仓库中没有 `proguard-rules.pro` 文件
   （`app/build.gradle.kts` 已引用该路径）。开启混淆前需先创建该文件并补 keep 规则
   （Gson 模型、JNI 方法、webview-sdk 回调）。
7. **`plan/` 是历史快照**：里面的方案可能与当前实现不一致，以代码为准。
8. **`checkAndRequestPermissions()` 未被调用**；`ChatViewModel` 持有 Fragment 引用。重构时留意。
9. **没有“停止生成”入口**：`StreamingChatClient` 只在新请求发起时取消上一条连接，UI 未暴露取消按钮。

## 6. 修改守则

Do：

- 小步提交，按模块验证；先跑 `assembleDebug`，再跑 `lintDebug`。
- 新功能先复用现有抽象（`Tool`、`AIConfig`、`AppConfigManager`、`ChatRepository`），不要另起一套。
- 改 AI 协议、工具名、会话 JSON 结构时视为兼容性变更，考虑已安装用户的历史数据与 `migrateIfNeeded`。
- 新增页面时遵循现有返回栈约定：MainActivity 的 `OnBackPressedCallback` 先关 Drawer；WebFragment 先
  处理 WebView 返回。
- 提交信息沿用历史风格：`feat: ...` / `fix: ...` / `docs: ...` / `chore: ...` + 中文描述。

Don't：

- 不要修改 `applicationId`、`namespace`、包名（除非需求明确）。
- 不要把 API Key、keystore 口令、访问 token 写进代码、日志或文档。
- 不要给 `:webview-sdk` 引入 app 的 version catalog 或 app 资源。
- 不要提交 `local.properties`、`.gradle/`、`build/`、`.idea/`、`*.iml`。
- 不要顺手格式化或重排无关文件，避免 diff 噪声。

## 7. 发布

- CI：`.github/workflows/appbuildfjhfjh.yml`（`workflow_dispatch` 手动触发）→ JDK 17 + Android SDK →
  `./gradlew assembleRelease` → 重命名 APK → 发布 GitHub Release，tag 为 `release-<run_number>`。
- 发布前手工核对：`versionCode` / `versionName`、签名配置、ABI、权限、内置 Whisper 模型是否随包、
  应用图标与快捷方式资源是否完整。

## 8. 文档维护

- 本文件是工程约定的唯一来源；`CLAUDE.md` 通过 `@AGENTS.md` 引用本文件，避免两份漂移。
- 用户向文档是 `README.md`（英文）和 `README_zh.md`（中文）；功能、命令、结构变化时同步更新两份。
- 产品迭代方向与优先级见 `docs/ROADMAP.md`；它是讨论稿，不代表已排期。
- `plan/` 存放设计过程文档（`.claude/settings.json` 中 `plansDirectory: "plan"`），不要当作当前实现的说明。
