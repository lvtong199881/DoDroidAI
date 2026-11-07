# DoDroidAI

一个用 Flutter 实现的原生 Android Agent 应用。用自然语言下指令，应用通过 LLM 的 tool calling
操作手机：闹钟、日历、短信、笔记、通讯录、剪贴板、定时提醒、联网搜索。语音输入输出基于
`sherpa-onnx` 完全离线运行。

> English version: [README.md](README.md)

---

## 功能

- **对话**：SSE 流式输出、有序内容块（思考 → 工具 → 思考 → 正文）、停止生成、重试、复制、朗读
- **工具调用**：11 个工具，按风险等级弹确认框，缺权限时申请运行时权限
- **会话**：sqflite 本地存储、懒创建、搜索、导出 Markdown
- **离线语音**
  - 识别：SenseVoice Small（按住说话 + 波形弹窗）
  - 合成：Matcha（默认，首包约 350ms）与 MeloTTS，整段连贯播放
  - 模型在应用内下载，支持后台下载
- **记忆与笔记**：可长期记忆的事实与笔记
- **定时任务**：基于 WorkManager 的相对时间提醒
- **联网搜索**：可配置搜索源，由开关控制
- **设置**：多套 AI 配置、主题、语言、工具审计、诊断、请求追踪
- **桌面小组件**与应用快捷方式

## 构建

```bash
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter build apk --release   # 只产出 arm64-v8a 单包，约 49MB
```

安装（降级时务必加 `-d`，否则 Android 会拒绝安装且不报错）：

```bash
adb install -r -d build/app/outputs/flutter-apk/app-release.apk
```

环境要求：Flutter 3.47+、JDK 17、Android SDK（**compileSdk 37**）。

## 项目结构

```
flutter_app/
├── lib/
│   ├── ai/          # 配置、对话 API（SSE）、工具、语音、模型管理
│   ├── data/        # sqflite 数据库（会话、笔记、记忆、任务、审计）
│   ├── models/      # ChatMessage 与有序内容块
│   ├── screens/     # 对话、设置、笔记、记忆、任务
│   ├── theme/       # 深浅色主题
│   └── l10n/        # 中英文文案
├── android/         # Android 宿主（仅 arm64-v8a，debug 签名）
└── test/            # 单元测试与集成测试
```

## 架构说明

- **消息内容块**：`ChatMessage.blocks` 是渲染顺序的唯一数据源，多轮工具对话里每段思考都在
  原位展示，不会被合并
- **语音在 isolate 里跑**：sherpa-onnx 调用不会阻塞 UI
- **下载是全局的**：离开语音设置页后 `DownloadManager` 仍在继续
- **流式刷新有节流**：流式期间最多每 50ms 刷新一次，每轮结束强制刷新

## 原生版本

原 Kotlin/XML 实现在完成功能对齐后已于 2026 年 11 月移除，可从 git 历史查阅。
