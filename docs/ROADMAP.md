# DoDroidAI 迭代路线图

> 状态：草案 v0.1（2026-10-29）
> 依据：当前代码快照（v1.0，`versionCode = 1`）、`TodoTasks.md` 遗留项、`plan/` 历史设计、2026-10 的外部平台与竞品调研
> 用法：本文档用于排期与取舍讨论，不承诺具体日期。外部平台信息（尤其 alpha API 与商店政策）实施前需复核。

---

## 0. 摘要

**当前定位**：一个轻量、自带 API Key、以系统工具调用为核心的 Android Agent；已具备流式对话、6 个工具、
离线 Whisper 语音、多 AI 配置、会话持久化、桌面小组件和可复用的 `webview-sdk`。

**三个基本判断**：

1. **先补“已承诺但没做完”的功能**，再谈新能力。附件目前不会发给模型、`add_note` 是占位实现、
   没有停止生成、没有测试——这些直接影响信任，优先级高于任何新方向。
2. **记忆与自动化是下一阶段的分水岭**。用户真正想要的是“记得我、替我做”，而不是更多聊天皮肤。
   但记忆必须先解决存储层（Room）与隐私控制。
3. **跨 App 自动化要谨慎**。Android 17（API 37）把系统 Agent 能力收拢到 AppFunctions/Android MCP，
   同时 Google Play 在 2026 年明显收紧了 AccessibilityService 的用途审核。把“无障碍自动化”作为
   Play 主功能风险很高，建议放到侧载/开发者模式，或改走 AppFunctions/Shizuku。

**建议节奏**：

| 版本 | 主题 | 范围 | 预估 |
| --- | --- | --- | --- |
| v1.1 | 可靠性与信任 | P0 全部 | 4–6 周 |
| v1.2 | 记忆与自动化 | P1 前半（存储迁移、记忆、定时、工具扩展） | 6–8 周 |
| v1.3 | 多模态与语音 | P1 后半（图片、语音、会话管理、可观测性） | 6–8 周 |
| v2.0 | 平台化 | P2 选做（AppFunctions、插件/MCP、本地模型、WebView SDK） | 8–12 周 |

---

## 1. 现状评估

### 1.1 能力盘点

| 能力 | 状态 | 证据 / 说明 |
| --- | --- | --- |
| 流式对话（Anthropic Messages + SSE） | ✅ 可用 | `StreamingChatClient`、`AnthropicSseListener` |
| 多 AI 配置（增删改、克隆、激活、旧数据迁移） | ✅ 可用 | `AppConfigManager`、`ui/setting/AIConfigList*` |
| 思考过程展示 | ✅ 可用 | `thinking_delta` → `reasoningContent`，可折叠 |
| 工具调用（6 个） | 🟡 部分 | 闹钟/日历/短信/时间/搜索可用；`add_note` 占位 |
| 高风险确认与运行时权限 | ✅ 可用 | `executeToolCalls()`；仅 `HIGH` 弹确认 |
| 离线语音识别 | 🟡 部分 | Whisper tiny q8_0，录完再识别，无流式/VAD |
| TTS 播报 | ✅ 可用 | 回复完成自动朗读，但不可打断 |
| 会话持久化 | 🟡 部分 | DataStore 全量 JSON，无搜索/导出/分页 |
| 附件（图片/PDF/Word/TXT） | ❌ 未接入 | 可选择预览，`ChatFragment` 丢弃 attachments |
| 多模态理解 | ❌ 缺失 | 不支持图片/截图输入 |
| 长期记忆 | ❌ 缺失 | `TodoTasks.md` P0 遗留 |
| 定时/触发任务 | ❌ 缺失 | 仅单次 `set_alarm` 工具 |
| 跨 App 操作 | ❌ 缺失 | 无 Accessibility/Shizuku |
| 本地对话模型 | ❌ 缺失 | 仅有 Whisper 端侧推理 |
| 测试与 CI 门禁 | ❌ 缺失 | 无 `src/test`；CI 仅手动发布 |
| 可观测性 | ❌ 缺失 | 仅 Logcat，无请求/工具 trace |
| 混淆与签名工程 | 🟡 部分 | 混淆关闭、无 ProGuard 文件、测试 keystore 入库 |
| 国际化 | 🟡 部分 | zh-rTW 缺约 37 条；部分文案硬编码 |
| WebView SDK | ✅ 可用 | H5 Bridge、滚动联动、edge-to-edge |

### 1.2 主要短板（按影响排序）

1. 附件链路断裂，多模态能力为零。
2. 工具承诺不完整（`add_note`），且工具种类少、无“总是允许/每次询问”策略。
3. 无记忆：每次会话都是“陌生人”，跨会话无法积累偏好。
4. 无可靠性与质量保障：没有测试、没有停止生成、错误处理粗糙。
5. 存储层是单 JSON 全量读写，会话一多就会成为瓶颈。
6. 无自动化/触发能力，Agent 只能在用户打开 App 时工作。
7. 安全工程不足：API Key 明文存 DataStore、日志打印消息内容、测试签名。
8. 无跨 App 能力，与“操作手机”的定位存在预期差（但受平台政策约束，见 §1.3）。

### 1.3 外部环境（2026-10）

- **Android 17（API 37，2026-06 发布）** 把系统定位为 “intelligence system”。
  `AppFunctions` 让应用把能力暴露为可编排的 “tools”，底层是 Android MCP；Jetpack 库
  `androidx.appfunctions` 仍为 alpha（1.0.0-alpha11，2026-08）。目前主要面向系统/特权 Agent 发现与执行，
  普通第三方 App 作为“调用方”的能力仍受限。
- **Gemini Nano / ML Kit GenAI** 提供端侧文本与多模态 Prompt API（alpha），可用于意图分类、参数抽取、
  摘要和离线兜底；设备覆盖有限（Pixel 与部分旗舰，以官方支持列表为准），必须做能力检测与降级。
- **Gemini Live API** 支持低延迟双向语音/视频流，适合实时语音对话；但绑定 Gemini 云端（可通过 Firebase AI Logic 或 Gemini API 接入），
  与当前“多 provider、自带 Key”的架构不同。
- **Google Play 政策**：AccessibilityService 仅允许面向残障用户的服务声明 `isAccessibilityTool`；
  2026 年起对自动化类应用的审核明显收紧。跨 App 自动化的上架风险需要按“不可用”来规划。
- **竞品参考**：
  - Operit（调研时约 9k stars）：本地模型（MNN/GGUF）、无障碍/Shizuku/Root 自动化、图记忆、插件市场、
    MCP、工作流、连续语音、悬浮窗——功能极全，但体量大、复杂度高。
  - Mobilerun（`droidrun/mobilerun`）：无障碍树 + 截图、vision/reasoning 模式、app cards、结构化输出、
    trace 与 benchmark，偏“移动端自动化框架/QA”。
  - 两者都验证了“记忆 + 工具 + 自动化 + 可观测性”是 Agent 的核心拼图，但也说明全量铺开需要很大投入。

### 1.4 约束与假设

- 工程量按 **1 名熟悉该代码库的 Android 工程师** 估算；不含设计、测试专岗。
- 只打包 `arm64-v8a` / `armeabi-v7a`；新增端侧模型要考虑包体与低端机内存。
- 现有架构是 XML Views + 单 Activity，不建议为了“现代化”整体重写 Compose。
- 发布渠道未定：若上 Google Play，跨 App 无障碍自动化基本不可行；若以 GitHub/侧载为主，可另做开发者版。

---

## 2. 优先级方法

每个方向按四个维度主观评分（1–5）：

- **用户价值 V**：对核心任务完成度/留存的影响。
- **工程量 C**：实现与维护成本（5 = 最大）。
- **风险 R**：政策、兼容性、alpha API、数据安全等不确定性。
- **战略契合 S**：是否强化“轻量、可信、可扩展的系统 Agent”定位。

排序规则：`V` 与 `S` 优先；`C` 与 `R` 作为降档因素。最终落到四档：

- **P0**：不做会持续伤害信任或阻塞后续迭代，4–6 周内必须完成。
- **P1**：直接提升核心价值，1–3 个月内分批交付。
- **P2**：平台化/差异化，需要前置条件或外部 API 成熟，3–6 个月评估。
- **暂缓/不做**：收益低、风险高或偏离定位，明确记录理由。

---

## 3. 路线图总览

| ID | 方向 | 优先级 | 价值 | 工程量 | 风险 | 目标版本 |
| --- | --- | --- | --- | --- | --- | --- |
| P0-1 | 附件真正进入模型请求（图片/PDF/TXT）✅ | P0 | 高 | 中 | 中 | v1.1 |
| P0-2 | 停止生成、失败重试、超时与断线提示 ✅ | P0 | 高 | 低 | 低 | v1.1 |
| P0-3 | 安全与配置修复（Key 加密、URL、转义、日志、签名）✅ | P0 | 高 | 中 | 低 | v1.1 |
| P0-4 | 测试与 CI 门禁 ✅ | P0 | 高 | 中 | 低 | v1.1 |
| P0-5 | `add_note` 落库 + 引入 Room ✅ | P0 | 中 | 中 | 低 | v1.1 |
| P0-6 | 支持 OpenAI Chat Completions 格式 ✅ | P0 | 高 | 中 | 中 | v1.1 |
| P1-1 | 存储层迁移 Room（会话/消息分页与搜索）🟡 存储已完成 | P1 | 高 | 高 | 中 | v1.2 |
| P1-2 | 长期记忆 MVP（事实 + 摘要 + 检索）✅ | P1 | 高 | 高 | 中 | v1.2 |
| P1-3 | 定时/触发任务（WorkManager + 通知）✅ | P1 | 高 | 中 | 中 | v1.2 |
| P1-4 | 工具扩展第一批（联系人/剪贴板 ✅，文件/地图/媒体暂缓） | P1 | 高 | 中 | 中 | v1.2 |
| P1-5 | 工具权限策略与审计日志 ✅ | P1 | 中 | 中 | 低 | v1.2 |
| P1-6 | 图片理解与相机/截图输入 ❌ 不做（用户判断价值不足） | P1 | 低 | 中 | 中 | — |
| P1-7 | 语音升级（引擎替换 ✅；VAD、流式、可打断 TTS 待做） | P1 | 高 | 高 | 中 | v1.3 |
| P1-8 | 会话管理（搜索/导出导入/重命名/置顶）✅ | P1 | 中 | 中 | 低 | v1.3 |
| P1-9 | 可观测性（请求/工具 trace、诊断包） | P1 | 中 | 中 | 低 | v1.3 |
| P1-10 | i18n 补齐与文案资源化 | P1 | 中 | 低 | 低 | v1.3 |
| P2-1 | AppFunctions / Android MCP 暴露 | P2 | 中高 | 高 | 高 | v2.0 |
| P2-2 | 自定义工具与远程 MCP 客户端 | P2 | 高 | 高 | 中 | v2.0 |
| P2-3 | 跨 App 自动化（Shizuku 优先，无障碍仅侧载） | P2 | 高 | 高 | 高 | 开发者版 |
| P2-4 | 本地对话模型（llama.cpp GGUF） | P2 | 中 | 高 | 中 | v2.0 |
| P2-5 | Gemini Nano 端侧路由/摘要 | P2 | 中 | 中 | 中 | v2.0 |
| P2-6 | WebView SDK 产品化（AAR + 文档 + demo） | P2 | 中 | 中 | 低 | v2.0 |
| P2-7 | 多步骤计划执行（manager-executor） | P2 | 中高 | 高 | 中 | v2.0 |
| X-1 | Gemini Live 实时语音模式 | 探索 | 中 | 中 | 中 | 待评估 |
| X-2 | 视觉屏幕理解（截图 + 多模态） | 探索 | 中 | 高 | 高 | 待评估 |
| X-3 | 语音唤醒词 | 探索 | 低中 | 高 | 高 | 待评估 |
| X-4 | 平板/折叠屏适配 | 探索 | 低中 | 低 | 低 | 待评估 |

---

## 4. 详细卡片

### P0-1 附件真正进入模型请求 ✅（2026-10 已实现，待随 v1.1 发布）

**现状**：`ChatInputBox` 能收集图片/PDF/Word/TXT 并预览，但 `ChatFragment` 的
`onSendClick = { message, _ -> ... }` 丢弃了附件列表；`ChatMessage.content` 只有纯文本。

**目标**：用户发图片后模型能理解并回答；PDF/TXT 能作为上下文；超限有清晰提示，不静默失败。

**方案要点**：

1. `ChatMessage` 增加 `attachments: List<AttachmentRef> = emptyList()`（Gson 默认值兼容历史会话）。
2. 发送前在 IO 线程解析并压缩：
   - 图片：限制长边（如 1568 px）与体积，转 base64；多图限制数量。
   - PDF：用 PDFBox-Android 等库抽文本层（`PdfRenderer` 只能渲染位图，不能抽文本）；扫描件明确提示“暂不支持 OCR”。
   - TXT：直接读取，限制字符数；Word 先明确提示不支持，避免假承诺。
3. `RequestFactory` 生成 Anthropic content blocks（`image` / `document` / `text`）；
   对不支持多模态的网关做能力标记，降级为文本说明 + 附件元信息。
4. UI：附件卡片展示解析状态/失败原因；发送中禁用重复发送。

**改动**：`ChatMessage`、`RequestFactory`、`AnthropicModels`、`ChatViewModel`、`ChatFragment`、
`ui/chat/input/`。

**验收**：发一张图问“图里有什么”能得到基于图片的回答；重启后历史消息仍有附件缩略图；
超出大小限制时提示且不崩溃；纯文本网关下退回文本模式不报错。

**风险**：兼容网关对 image/document block 支持不一；token 成本上升；PDF 抽取质量。

**估时**：4–6 天。

---

### P0-2 停止生成与失败恢复 ✅（2026-10 已实现）

**实现**：发送按钮在加载中变为停止；`stopGeneration()` 取消 SSE 并保留已生成内容；
网络/超时/鉴权/限流/5xx 分类提示；失败消息带重试，重试不产生重复消息；OkHttp 连接 15s / 读取 120s。

**现状**：`StreamingChatClient` 只在新请求时取消上一条连接；UI 没有停止按钮。
网络失败/超时只有一条错误提示，没有重试。

**目标**：用户可随时中止生成；失败可一键重试；超时与断线有明确状态。

**方案要点**：

1. `StreamingChatClient.cancel()` 暴露给 `ChatViewModel.stopGeneration()`；取消后保留已生成内容。
2. 发送按钮在 `isLoading` 时变为“停止”，长按/点击都可中止。
3. 请求设置连接/读取超时（当前 OkHttp 配置需核对），错误分类：网络、鉴权、限流、服务端、解析。
4. 失败消息保留“重试”入口，重试复用原始用户消息，不重复入库。
5. 工具循环中取消要中断后续轮次，避免后台继续调用工具。

**改动**：`StreamingChatClient`、`ChatViewModel`、`ChatFragment`、`ChatInputBox`、`CustomDialog`。

**验收**：生成中点击停止后 1 秒内停止更新；网络断开提示可重试；重试成功后消息不重复。

**估时**：2–3 天。

---

### P0-3 安全与配置修复 ✅（2026-10 已实现）

**实现**：Key 用 Android Keystore AES-GCM 加密（`enc:v1:`）；baseUrl 保存前规范化并校验 HTTPS；
tool_result 转义测试；日志脱敏；R8 混淆 + 资源压缩（TypeToken/PDFBox keep）；签名支持环境变量；
移除 Retrofit 与 `RECEIVE_BOOT_COMPLETED`；关闭 `allowBackup`。

**现状**：API Key 明文存 DataStore；日志打印消息内容；`baseUrl` 与 `/v1/messages` 拼接存在冲突；
`tool_result` 用字符串拼 JSON；release 使用仓库内测试 keystore；混淆关闭且无 ProGuard 文件。

**目标**：消除已知高危项，达到“可交给真实用户”的基线。

**方案要点**：

1. **Key 加密**：用 Android Keystore 生成 AES-GCM 密钥，加密后存入 DataStore；
   避免依赖已标记 deprecated 的 `androidx.security-crypto`。迁移旧明文数据后清除。
2. **URL 规范化**：`AIConfig` 保存前统一去除尾部 `/`、`/v1`、`/v1/messages`；
   启动时校验 HTTPS，非法值给出可操作提示。
3. **JSON 安全**：`tool_result` 改用 Gson 结构化序列化，禁止字符串拼接；补充转义测试。
4. **日志脱敏**：消息内容、工具参数、Key 一律不落 Logcat；调试日志用开关控制。
5. **签名与混淆**：仓库内 keystore 改为仅 debug/CI 测试用，release 走 CI secret；
   创建 `proguard-rules.pro` 并开启 `isMinifyEnabled`（先 dry-run 验证）。
6. **依赖与权限**：清理未使用的 Retrofit 依赖；复核 `RECEIVE_BOOT_COMPLETED` 是否需要。

**改动**：`AppConfigManager`、`AIConfig`、`RequestFactory`、`app/build.gradle.kts`、`.github/workflows/`。

**验收**：Key 在 `adb shell run-as` 导出的 DataStore 中不可读；恶意/异常工具结果不导致请求失败；
release 可正常出包并混淆；日志中搜不到 Key 与消息正文。

**估时**：4–5 天。

---

### P0-4 测试与 CI 门禁

**现状**（2026-11 更新）：已有 53 个 JVM 单测（`app/src/test`）；`.github/workflows/ci.yml` 已在 push/PR 跑单测 + lint。

**目标**：核心逻辑有回归保护；PR 能自动发现编译、lint、单测问题。

**方案要点**：

1. 新增 `src/test`，优先覆盖：
   - `RequestFactory` 的请求体结构（消息、工具、tool_result）。
   - `AnthropicSseListener` 的事件解析（把纯解析逻辑抽成可测函数）。
   - 各 `Tool` 的参数解析与失败分支。
   - `AppConfigManager` 的旧数据迁移。
   - `ChatRepository` 的增删改（用临时 DataStore 或抽象接口 + fake）。
2. 依赖：JUnit4/5、kotlinx-coroutines-test、Truth/AssertJ、Robolectric（按需）。
3. 新增 `.github/workflows/ci.yml`：`pull_request` 触发 `testDebugUnitTest lintDebug assembleDebug`；
   缓存 Gradle；失败阻断合并。
4. 为关键 UI 流程（发送、工具确认）补 1–2 个 Espresso 冒烟用例（可选）。

**验收**：CI 在 PR 上稳定通过/失败；核心类行覆盖率有基线（先不设硬阈值）。

**估时**：4–6 天（含补测试）。

---

### P0-5 `add_note` 落库与 Room 引入

**现状**（2026-11 更新）：已引入 Room 2.7.2，`notes` 表 + `NoteRepository` + 笔记列表页；`AddNoteTool` 已落库。

**目标**：工具承诺兑现；为记忆/会话迁移建立存储基础。

**方案要点**：

1. 引入 Room（runtime/ktx/compiler + KSP），建 `notes` 表（id、title、content、createdAt、updatedAt）。
2. `NoteRepository` + 笔记列表/详情/搜索/删除页面（入口放设置或侧边栏）。
3. `AddNoteTool` 写入 Room；失败返回明确错误；工具定义补充“笔记会保存在本地”的描述。
4. 迁移策略：Room schema v1，后续记忆/会话复用同一数据库。

**验收**：对模型说“记一条笔记：周五交报告”，重启后在笔记页可见；可删除；`add_note` 失败不返回假成功。

**估时**：4–5 天。

---


### P0-6 支持 OpenAI Chat Completions 格式 ✅（2026-10 已实现，待随 v1.1 发布）

**现状**：原实现只支持 Anthropic Messages，OpenAI 官方端点不可用。
**实现**：新增 `OPENAI_CHAT_COMPLETIONS` 与 `ApiEndpoint` 规范化；`OpenAiChatRequestBuilder`
生成文本/图片/工具调用请求；`OpenAiSseParser` 解析增量、reasoning 与分片 tool_calls；
AI 配置页可选择格式，OpenAI 预设改为官方 Chat Completions 端点。
**未做**：OpenAI Responses API、Assistants、Realtime。
**估时**：约 1 天（含测试）。

### P1-1 存储层迁移 Room

**现状**：`ChatRepository` 每次把整个 `sessions` JSON 读出来、过滤、再写回；会话增多后写放大明显，
无法分页/搜索/增量更新。

**目标**：会话/消息关系化存储，支持分页加载、全文搜索、增量写入与导出。

**方案要点**：

1. 表：`sessions(id, title, createdAt, updatedAt, pinned)`、`messages(id, sessionId, role, content,
   reasoning, timestamp, toolCallsJson, attachmentsJson)`；外键 + 索引（sessionId、updatedAt）。
2. DAO：`observeSessions()`、`loadMessages(sessionId, limit, offset)`、`appendMessage()`、
   `updateMessage()`、`deleteSession()`。
3. 迁移：读取旧 DataStore JSON，一次性写入 Room，成功后标记迁移完成；保留只读回退。
4. `ChatViewModel` 改为增量追加，不再每次替换整个列表。
5. 搜索：Room `@Fts4` 全文索引（消息内容 + 标题）。

**验收**：500 个会话、1 万条消息下列表滑动不卡；搜索 200 ms 内返回；旧数据升级不丢失。

**估时**：8–10 天。

---

### P1-2 长期记忆 MVP

**现状**：每次请求只带最近 20 条消息；跨会话没有用户偏好或历史事实。

**目标**：记住用户明确表达的偏好/事实，并在后续对话中按需使用；用户可查看、编辑、删除。

**方案要点**：

1. 先做**结构化记忆**，不做复杂向量库：
   - `memory_facts(id, key, value, sourceSessionId, confidence, createdAt, updatedAt)`。
   - 写入：每轮结束后异步让 LLM 抽取（JSON schema），或用户手动“记住这条”。
   - 读取：请求前按当前输入关键词 + 最近使用做粗排，取 top-N 注入 system prompt（token 预算内）。
2. 会话摘要：超过 N 条后生成摘要，替换最早的消息，控制上下文。
3. 隐私：记忆页支持查看/编辑/删除/全部清空；默认开启但首次使用时说明。
4. 向量检索作为后续增强（见 P2），MVP 用 FTS + 规则即可。

**验收**：用户说“我住在上海”后，新会话问“周末去哪玩”能体现该偏好；删除记忆后不再引用。

**风险**：错误记忆污染；抽取成本；注入导致 prompt 膨胀。

**估时**：8–10 天。

---

### P1-3 定时/触发任务

**现状**：只有单次闹钟工具，Agent 无法在后台按计划执行。

**目标**：用户可创建“每天早上 8 点播报天气”“每周五 18:00 提醒我写周报”这类任务，
结果写入会话并通过通知呈现。

**方案要点**：

1. 数据模型：`scheduled_tasks(id, prompt, cron/interval, enabled, lastRunAt, lastResult)`。
2. 调度：`WorkManager` 做周期任务（最小 15 分钟）；需要精确时间时用 `AlarmManager`
   （`SCHEDULE_EXACT_ALARM`，需引导授权）。
3. 执行：后台触发一次 Agent 调用，限制工具集（只读/低风险），结果存会话 + 通知；
   高风险工具在后台一律禁止或要求先确认。
4. UI：任务列表、新建（自然语言 + 时间解析）、启停、删除、最近运行结果。
5. 厂商后台限制：提供电池优化引导页。

**验收**：创建“1 分钟后提醒我喝水”，到点收到通知；重启设备后任务仍生效；失败有记录。

**估时**：7–9 天。

---

### P1-4 工具扩展第一批

按“高频 + 低敏感权限”优先：

| 工具 | 权限 | 风险 | 说明 |
| --- | --- | --- | --- |
| `get_clipboard` / `set_clipboard` | 无（前台） | 中 | Android 10+ 后台读取受限，仅前台可用 |
| `open_map_navigation` | 无（Intent） | 低 | `geo:` / 高德/百度 scheme，按国内可用性适配 |
| `read_file` / `write_file` | SAF 授权 | 中 | 用户选择目录，避免全盘权限 |
| `search_contacts` | `READ_CONTACTS` | 中 | 只读、按姓名/号码模糊匹配 |
| `media_control` | 通知使用权 | 中 | 播放/暂停/下一首，需 `NotificationListenerService` |
| `read_notifications` | 通知使用权 | 高 | 敏感；默认关闭，明确告知用途 |

**方案要点**：每个工具仍按 AGENTS.md 的“三处同步”接入；通知类工具要做“仅本次/总是允许/拒绝”策略
（见 P1-5），避免默认全量读取。

**估时**：每个 1–2 天，第一批 7–10 天。

---

### P1-5 工具权限策略与审计

**现状**：只有 `HIGH` 风险会弹确认；没有“总是允许”、没有调用记录。

**目标**：用户对每个工具拥有三态授权（总是允许/每次询问/拒绝），并可查看调用历史。

**方案要点**：

1. 设置页新增“工具权限”列表，按工具展示风险与授权状态。
2. 执行前查策略：`ALWAYS` 直接执行、`ASK` 弹窗、`DENY` 返回拒绝结果给模型。
3. `tool_audit_log` 表：时间、工具、参数摘要（脱敏）、结果、耗时、会话 id；本地保留 N 天。
4. 导出审计记录（脱敏 JSON），用于问题反馈。

**验收**：把 `send_sms` 设为“拒绝”后，模型调用得到明确的拒绝结果而不是崩溃；审计页能看到最近调用。

**估时**：5–7 天。

---

### P1-6 图片理解与相机/截图输入 ❌ 不做

**决策（2026-11）**：用户判断该方向价值不足，明确不做；附件链路保留既有图片/PDF/TXT 输入能力，不扩展相机/截图。

**现状**：P0-1 只解决“选图发送”；没有相机实时画面和截图输入。

**目标**：支持拍照提问、对当前屏幕截图提问；图片在会话中可回看。

**方案要点**：

1. 相机：复用现有拍照入口，拍完走 P0-1 的图片链路。
2. 截图：`MediaProjection` + 前台服务（Android 14+ 每次授权），截图后直接作为附件。
3. 多模态提示：明确“图片会发送给你配置的 AI 服务商”，隐私说明。
4. 大图压缩、EXIF 清理、失败降级。

**验收**：拍照问“这是什么植物”有回答；截图后问“这个页面怎么操作”有回答；授权拒绝时不崩溃。

**估时**：6–8 天（截图权限流程占大头）。

---

### P1-7 语音升级

**现状**：Whisper tiny q8_0 录完再识别；TTS 不可打断；没有连续对话。

**目标**：接近“对讲机”体验：说话时实时出字、可打断播报、连续多轮免手动。

**方案要点**：

1. VAD（能量/WebRTC VAD）分段，短句即识别，降低等待。
2. Whisper 分段推理 + partial result（复用 `WhisperContext`，注意线程与内存）。
3. TTS 队列管理：新回复打断旧播报；语速/音色设置持久化。
4. 连续对话模式：识别完成自动发送 → 播报 → 自动继续听；耳机/免提场景优化。
5. 可选云端流式 ASR（用户自行配置），与本地模式切换。

**验收**：说完 1 秒内开始出字；播报中再次说话能打断；连续 5 轮不点屏幕可完成对话。

**风险**：低端机推理延迟；后台录音限制；功耗。

**估时**：10–12 天。

---

### P1-8 会话管理

**目标**：搜索、导出/导入、重命名、置顶、批量删除；长会话可回看。

**方案要点**：依赖 P1-1 的 Room；导出 Markdown/JSON（含附件引用）；导入做版本校验；
置顶字段参与排序；批量操作加确认。

**验收**：1 万条消息下搜索可用；导出文件能在另一台设备导入并正常打开。

**估时**：5–7 天。

---

### P1-9 可观测性

**目标**：用户反馈问题时能提供“哪一步失败”；开发能定位慢在哪。

**方案要点**：

1. 本地 trace：请求开始/首 token/结束、token 用量、工具调用（名称、耗时、结果状态）、错误分类。
2. 设置页“诊断”入口：最近 20 次请求列表 + 详情；一键导出脱敏 JSON。
3. 性能埋点：首 token 延迟、工具执行耗时、崩溃/ANR（可接 Firebase Crashlytics，需隐私开关）。

**验收**：能看出一次失败是网络、鉴权还是工具异常；导出包不含 Key 与消息正文。

**估时**：4–6 天。

---

### P1-10 i18n 补齐与文案资源化

**现状**：`values-zh-rTW` 约 56/93 条；工具确认框、错误信息等存在硬编码中文。

**目标**：三语一致；新增文案全部走资源；工具描述可按语言切换。

**方案要点**：补齐 zh-rTW；扫描 `app/src/main/java` 中的中文字符串，迁移到 `strings.xml`；
统一日期/数字格式；CI 加“缺失翻译”检查脚本。

**估时**：2–3 天。

---

### P2-1 AppFunctions / Android MCP 暴露

**背景**：Android 17 的 AppFunctions 让应用把能力暴露给系统 Agent（Gemini），底层是 Android MCP；
Jetpack 库仍是 alpha，且主要面向系统/特权 Agent。

**目标（PoC → 可选功能）**：把 `set_alarm`、`add_calendar_event`、`add_note` 暴露为 AppFunctions，
让系统 Agent 在用户授权下直接调用，而不是仅靠 DoDroidAI 自己的聊天入口。

**方案要点**：

1. 升级 `compileSdk`/`targetSdk` 到 37，接入 `androidx.appfunctions`（alpha，注意 API 变动）。
2. 用注解/编译器生成 app function 描述；在 Google Connected Console 注册 connected app。
3. 只暴露低风险、幂等的工具；高风险操作仍要求应用内确认。
4. 先做 3–5 天 spike：官方 sample 跑通，评估设备覆盖与审核成本，再决定是否正式投入。

**风险**：alpha API 不稳定；Android 17 设备覆盖低；上架审核与隐私声明；作为调用方的能力未开放。

**估时**：PoC 3–5 天；正式 2–3 周。

---

### P2-2 自定义工具与远程 MCP 客户端

**目标**：用户可添加 HTTP 工具（JSON Schema）或连接远程 MCP Server，把个人服务接入 Agent。

**方案要点**：

1. 自定义工具模型：名称、描述、参数 schema、请求模板、鉴权头（加密存储）、超时。
2. MCP 客户端：Streamable HTTP/SSE，工具发现与调用；沙箱限制返回大小。
3. 安全：工具来源标记、权限声明、调用审计、危险操作二次确认；禁止自动执行未确认的新工具。
4. UI：工具市场不做，先做“手动添加 + 导入 JSON”。

**风险**：恶意工具/提示注入；MCP 规范演进；复杂度高。

**估时**：15–20 天。

---

### P2-3 跨 App 自动化（Shizuku 优先）

**背景**：Play 政策收紧，AccessibilityService 不能作为通用自动化上架。

**目标（开发者版/侧载）**：通过 Shizuku（ADB 授权）执行 `input tap/swipe/text`、`am start`、
读取前台应用、截图等，完成“打开设置并开启深色模式”这类跨 App 任务。

**方案要点**：

1. 集成 Shizuku API；检测服务状态并引导用户授权。
2. 工具集：`get_foreground_app`、`launch_app`、`tap`、`swipe`、`input_text`、`press_back/home`、`screencap`。
3. 规划层：需要 UI 树/截图理解才能可靠点击（依赖 P2-1 之外的视觉能力），先做“确定性脚本”而非全自动。
4. Accessibility 方案仅放在独立 flavor（侧载），不进入 Play 包；代码与文案明确风险。

**风险**：Shizuku 安装门槛；不同 ROM 兼容性；误操作；政策。

**估时**：PoC 1 周；可用版 3–4 周。

---

### P2-4 本地对话模型（llama.cpp GGUF）

**目标**：无网/隐私模式下可完成简单对话与工具路由；不内置大模型，按需下载。

**方案要点**：

1. 复用现有 ggml/CMake 基础接入 llama.cpp，评估与 Whisper 的 ggml 版本冲突。
2. 模型管理：下载、校验、存储、删除；推荐 1–3B 量化模型，按设备内存分级。
3. 用途优先级：意图分类/工具选择 → 简短问答 → 完整对话（最后）。
4. 性能保护：低端机禁用；推理超时降级到云端。

**风险**：包体/内存/发热；模型许可；维护成本。

**估时**：3–4 周。

---

### P2-5 Gemini Nano 端侧路由/摘要

**目标**：用 ML Kit GenAI Prompt API 在端侧做意图分类、参数抽取、会话摘要，降低云调用与延迟。

**方案要点**：能力检测（AICore/设备支持）→ 不支持则回退云端；先做“摘要”与“工具路由”两个场景；
注意 alpha API 与设备覆盖。

**估时**：1–2 周。

---

### P2-6 WebView SDK 产品化

**目标**：把 `webview-sdk` 做成可对外复用的组件：AAR 发布、接入文档、demo、语义化版本。

**方案要点**：发布到 GitHub Packages/JitPack；补 bridge 能力（文件上传/下载、定位、分享、错误页、深链）；
编写 H5 接入文档与示例页；拆分可选依赖；补单元测试与兼容性矩阵。

**估时**：2–3 周。

---

### P2-7 多步骤计划执行

**目标**：复杂任务先计划再执行（manager-executor），步骤可视、可中止、失败可重试。

**方案要点**：复用工具循环，增加 planner（输出步骤 JSON）、executor（逐步执行）、replanner（根据结果调整）；
步骤状态进入 trace 与 UI；高风险步骤强制确认；限制步数与总时长。

**估时**：3–4 周。

---

### 探索项（X）

| ID | 方向 | 判断 |
| --- | --- | --- |
| X-1 | Gemini Live 实时语音 | 体验好，但绑定 Gemini/Firebase，与多 provider 架构冲突；可作为“可选云端语音模式”验证 |
| X-2 | 视觉屏幕理解 | 依赖截图/无障碍，政策与成本高；先等 P2-3 的 Shizuku 路径成熟 |
| X-3 | 语音唤醒词 | 常驻监听功耗与隐私成本高，收益不确定；暂不做 |
| X-4 | 平板/折叠屏适配 | 成本低，随 Android 17 大屏适配要求推进（targetSdk 37 前必须处理） |

---

## 5. 版本与里程碑

### v1.1 可靠性与信任（P0，4–6 周）

- ✅ 附件真正可用（图片/PDF/TXT，2026-10 已实现）。
- 停止生成、失败重试、错误分类。
- Key 加密、URL 规范化、JSON 安全、日志脱敏、签名/混淆工程。
- 测试与 CI 门禁。
- `add_note` 落库 + Room 基础。

**退出标准**：核心流程无 P0/P1 缺陷；CI 绿灯；release 包可混淆出包；附件与工具承诺可演示。

### v1.2 记忆与自动化（P1 前半，6–8 周）

- 会话/消息迁移 Room。
- 记忆 MVP（事实 + 摘要 + 检索）。
- 定时任务。
- 工具扩展第一批 + 权限策略/审计。

**退出标准**：跨会话记忆可验证；定时任务可靠触发；工具权限可配置。

### v1.3 多模态与语音（P1 后半，6–8 周）

- 图片/相机/截图输入。
- 语音 VAD、流式、可打断、连续对话。
- 会话管理、可观测性、i18n。

**退出标准**：语音连续 5 轮无手动操作；诊断包可定位失败原因；三语完整。

### v2.0 平台化（P2 选做，8–12 周）

- AppFunctions PoC/正式（视平台成熟度）。
- 自定义工具/远程 MCP。
- 本地模型或 Gemini Nano 路由（二选一，先验证）。
- WebView SDK 发布。
- 跨 App 自动化开发者版（独立分发）。

**退出标准**：至少一个平台化能力被真实用户使用；不引入无法维护的复杂度。

---

## 6. 不建议做 / 暂缓

| 方向 | 理由 |
| --- | --- |
| 全量 Compose 重写 | XML Views 稳定，收益低、风险高；可局部引入 Compose |
| 插件市场/角色卡/虚拟形象 | 偏离“轻量系统 Agent”定位，运营成本高（Operit 的路线不适合小团队复制） |
| 内置大语言模型 | APK 体积与低端机体验不可控；按需下载更合理 |
| 自建向量数据库/复杂 RAG | 先用事实表 + FTS + 摘要，验证需求后再引入 embedding |
| 跨 App 无障碍自动化作为 Play 主功能 | 2026 年政策收紧，审核风险高；改走 Shizuku/侧载 |
| 多端（iOS/Wear/Auto） | 当前团队与代码基础不适合发散 |
| 实时视频通话式交互 | 成本高，与当前使用场景不匹配 |

---

## 7. 衡量指标

**北极星候选**：周活跃用户中“完成过一次多步任务”的比例。

| 类别 | 指标 | 目标（v1.3 前） |
| --- | --- | --- |
| 激活 | 首次配置完成率 | > 70% |
| 质量 | 崩溃率 / ANR | < 1% / < 0.5% |
| 性能 | 首 token 延迟 P50 | < 2 s（网络正常） |
| 任务 | 工具调用成功率 | > 95%（不含用户拒绝） |
| 任务 | 端到端任务成功率（人工评测 50 条） | > 80% |
| 留存 | 7 日 / 30 日 | 基线 + 10% |
| 成本 | 平均 token/会话 | 有基线并可观测 |
| 信任 | 高风险确认取消率 | 可解释（过高说明误触发） |

评测方法：维护 50 条真实指令集（闹钟、日历、短信、搜索、笔记、多步组合），每版回归一次；
记录成功/失败原因，进入 `docs/eval/`（后续建立）。

---

## 8. 开放问题（需要产品决策）

1. **发布渠道**：Google Play / GitHub / 国内商店？直接决定跨 App 自动化与通知权限的形态。
2. **目标用户**：极客（可接受 Shizuku、自带 Key）还是普通用户（需要开箱即用、托管额度）？
3. **商业模式**：长期自带 Key，还是提供托管代理/订阅？影响成本控制与合规。
4. **国内生态**：是否优先接高德/百度导航、微信/支付宝分享？涉及 SDK 与合规。
5. **端侧模型投入**：是否接受为离线能力增加 1–3 GB 存储与下载管理？
6. **记忆默认值**：默认开启还是首次询问？涉及隐私预期。

---

## 9. 调研来源

**平台能力**

- [AppFunctions 概览（Android Developers）](https://developer.android.com/ai/appfunctions)
- [androidx.appfunctions 版本记录](https://developer.android.com/jetpack/androidx/releases/appfunctions)
- [Android intelligence system](https://developer.android.com/ai/intelligence-system)
- [Gemini Nano](https://developer.android.com/ai/gemini-nano)
- [ML Kit GenAI Prompt API](https://developers.google.com/ml-kit/genai/prompt/android)
- [Gemini Live API](https://developer.android.com/ai/gemini/live)
- [Android 17 Beta（API 37）](https://android-developers.googleblog.com/2026/02/the-first-beta-of-android-17.html)

**政策**

- [Google Play：AccessibilityService API 的使用](https://support.google.com/googleplay/android-developer/answer/10964491)
- [Google 收紧无障碍 API（Malwarebytes，2026-03）](https://www.malwarebytes.com/blog/mobile/2026/03/google-cracks-down-on-android-apps-abusing-accessibility)

**竞品与工具**

- [Operit AI（GitHub）](https://github.com/AAswordman/Operit)
- [Mobilerun / Droidrun（GitHub）](https://github.com/droidrun/mobilerun)
- [Shizuku](https://shizuku.rikka.app/)

> 外部链接内容可能随版本变化；涉及 alpha API、商店政策与设备支持范围时，实施前请重新核对官方文档。
