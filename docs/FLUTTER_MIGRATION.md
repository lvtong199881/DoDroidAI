# DoDroidAI Flutter 迁移计划

## 目标

把现有 Kotlin/XML 原生 Android 应用完整迁移到 Flutter（Android 平台，后续可扩展到 iOS），
保持功能对等：聊天、流式输出、工具调用、语音输入/输出、会话管理、设置、笔记、记忆、定时任务。

## 现状

- 125 个 Kotlin 文件、43 个布局
- 单 Activity + Fragment + MVVM；Room（v7）+ DataStore；无 DI
- AI：OpenAI Chat Completions / Anthropic Messages SSE 流式 + 工具调用循环
- 语音：sherpa-onnx（SenseVoice ASR + MeloTTS TTS，预编译 .so）
- 其他：小组件（AppWidget）、WebView SDK、WorkManager 定时任务、AlarmManager

## 迁移策略

**并列新建 `flutter_app/`**，原 `app/` 保留作为参照与回归基线；功能对等后再切换发布。
**纯 Flutter 优先**：能纯 Flutter 实现的不做 MethodChannel 桥接——语音用 `sherpa_onnx` Dart FFI、
电池用 `battery_plus`、闹钟用 `android_intent_plus`、短信用 `url_launcher`、定时任务用 `workmanager`、
小组件用 `home_widget`、快捷方式用 `quick_actions`。仅 Android 标准声明（AppWidget receiver）保留原生类。
WebView 经决策不迁移。需要桥接的能力必须先确认。

## 技术选型

| 原生 | Flutter |
| --- | --- |
| Room | drift（SQLite + 代码生成，支持复杂查询/迁移） |
| DataStore | shared_preferences / 自建 KV（drift 表） |
| OkHttp + SSE | dio + 自写 SSE 解析（或 `flutter_client_sse`） |
| Markwon | `flutter_markdown` + 自定义代码块组件 |
| Material 3 (XML) | Material 3 ThemeData（含 Dynamic Color） |
| Fragment + Navigation | go_router |
| ViewModel + StateFlow | Riverpod（Notifier/AsyncNotifier） |
| sherpa-onnx | `sherpa_onnx` Dart FFI（纯 Flutter，ASR + TTS + VAD） |
| AppWidget | `home_widget` + 标准 `AppWidgetProvider`（1x2 / 1x4 / 2x2） |
| AlarmManager | `android_intent_plus`（`AlarmClock.ACTION_SET_ALARM`） |
| WorkManager | `workmanager` + `flutter_local_notifications` 提醒 |
| WebView SDK | 不迁移（用户决策） |

## 阶段计划

### P0 工程骨架（进行中）
- `flutter create flutter_app`（Android）
- 主题（Material 3、DeepSeek 蓝 #4D6BFE、深色模式）
- go_router 路由：聊天、会话列表（抽屉）、设置、关于
- 聊天页静态骨架（消息气泡、输入框、思考/工具折叠占位）

### P1 聊天核心
- 消息模型 + 列表渲染（Markdown、代码块、思考过程、工具调用折叠）
- 输入框（深度思考/智能搜索 chips、附件、语音按钮）
- 流式输出（SSE 解析 + 增量渲染）
- 会话列表与切换、新建对话

### P2 数据层
- drift 表：sessions / messages / notes / memory_facts / scheduled_tasks / permission_policy / tool_audit
- 迁移脚本（对应 Room v7 结构）
- 仓库层（Repository）

### P3 AI 与工具
- 配置（多配置、Keystore 加密 → `flutter_secure_storage`）
- OpenAI/Anthropic 请求构建、SSE、工具调用循环
- 工具执行：系统能力（闹钟/日历/SMS/笔记）通过 MethodChannel 调原生
- 确认弹窗、权限请求

### P4 语音
- ASR：MethodChannel → 原生 sherpa-onnx（录音 VAD、识别）
- TTS：MethodChannel → 原生 MeloTTS，回退系统 TTS
- 模型下载/管理页面

### P5 设置与辅助功能
- AI 配置、语言、外观、语音输入/输出、对话设置、诊断、工具审计
- 笔记、记忆、定时任务页面

### P6 收尾
- 桌面小组件、WebView SDK（或复用原生 WebView 容器）
- 数据迁移（原生 Room → Flutter drift）
- 打包、签名、README 更新

## 验收

- 功能对等 checklist 逐项验证（对照原 Android 版本）
- 流式输出、工具调用、语音识别/朗读、会话持久化在真机可用
- 无阻断性性能回归（长列表滚动、流式渲染）

## 风险

- 完整迁移工作量以月计，按阶段交付，每阶段可独立运行
- 原生能力（语音/小组件）依赖 MethodChannel，需保持原生模块可编译（现有 `jniLibs` 保留）
- Room → drift 数据迁移需要一次性脚本与回滚方案

## 迁移完成度（2026-11）

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| 聊天页 | ✅ | SSE 流式、思考折叠、Markdown、工具调用卡片、操作栏 |
| 会话 | ✅ | sqflite 持久化、切换/删除、首条消息自动命名 |
| 语音输出 | ✅ | 纯 Flutter `sherpa_onnx` + MeloTTS，`audioplayers` 播放 |
| 语音输入 | ✅ | 纯 Flutter `sherpa_onnx` SenseVoice + `record` 录音 |
| 工具调用 | ✅ | 工具循环（上限 5 轮）、工具卡片、确认弹窗 |
| 工具实现 | ✅ | `get_battery_level` / `set_alarm` / `send_sms` / `get_current_time`（纯 Flutter） |
| 附件 | ✅ | 图片（选图/多模态/持久化）、文本文件（拼接内容） |
| 设置 | ✅ | API 配置、外观、语言、笔记、记忆、工具审计、定时任务 |
| 定时任务 | ✅ | CRUD + `workmanager` 15 分钟检查 + 本地通知 |
| 工具审计 | ✅ | sqflite 记录 + 列表 + 清空 + 权限策略重置 |
| 权限策略 | ✅ | 录音权限拒绝记忆 |
| 桌面小组件 | ✅ | 1x2 / 1x4 / 2x2，会话标题 + 最新回复 |
| 快捷方式 | ✅ | 新对话 / 设置 |
| i18n | ✅ | 中/英，主要页面全覆盖 |
| 单元测试 | ✅ | 14 个（SSE 解析、工具执行、文案、仓储层） |
| 数据迁移 | ⏳ | 决策：不迁移（跨包沙箱无法读取原生 Room） |
| WebView | ⏳ | 决策：不迁移 |
