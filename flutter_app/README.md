# DoDroidAI Flutter

Flutter 版 DoDroidAI（Android），功能对齐原生版（除 WebView SDK）。

## 构建

```bash
flutter pub get
flutter build apk --debug
```

需要 Flutter 3.x；语音模型放在 `filesDir/tts_models`（MeloTTS）与 `filesDir/stt_models`（SenseVoice）。

## 测试

```bash
flutter test
```

## 结构

| 目录 | 内容 |
| --- | --- |
| `lib/ai/` | AI 配置、SSE 客户端、工具注册与执行、sherpa_onnx TTS/ASR |
| `lib/data/` | sqflite 仓储（聊天、笔记、记忆、定时任务、工具审计、权限策略） |
| `lib/l10n/` | 中英文案与 LocalizationsDelegate |
| `lib/models/` | 消息模型 |
| `lib/screens/` | 聊天、设置、笔记、记忆、定时任务、工具审计 |
| `lib/settings/` | 主题与语言状态 |
| `lib/theme/` | Material 3 主题 |
| `third_party/record_linux_stub/` | 覆盖 record 包损坏的 Linux 实现（纯 Dart） |

迁移计划与完成度见仓库根目录 `docs/FLUTTER_MIGRATION.md`。
