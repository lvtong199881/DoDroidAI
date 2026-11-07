# DoDroidAI

An on-device Android agent built with Flutter. Talk to it in natural language and it operates your
phone through LLM tool calling: alarms, calendar events, SMS, notes, contacts, clipboard, scheduled
reminders and web search. Speech input and output run fully offline on top of `sherpa-onnx`.

> 中文说明见 [README_zh.md](README_zh.md)。

---

## Features

- **Chat**: SSE streaming, ordered content blocks (reasoning → tool → reasoning → reply), stop
  generation, retry, copy, read-aloud
- **Tool calling**: 11 tools with risk-based confirmation and runtime permission handling
- **Sessions**: local sqflite storage, lazy creation, search, export as Markdown
- **Offline speech**
  - ASR: SenseVoice Small (press-and-hold, waveform overlay)
  - TTS: Matcha (default, ~350 ms first audio) and MeloTTS, gapless playback
  - Models downloaded in-app; downloads continue in the background
- **Memory & notes**: long-term facts and notes the agent can write and read
- **Scheduled tasks**: relative reminders via WorkManager
- **Web search**: configurable provider, gated by a toggle
- **Settings**: multi-provider AI configs, theme, language, tool audit, diagnostics, request traces
- **Home screen widgets** and app shortcuts

## Build

```bash
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter build apk --release   # single arm64-v8a APK, ~49 MB
```

Install (use `-d` when downgrading, otherwise Android rejects it silently):

```bash
adb install -r -d build/app/outputs/flutter-apk/app-release.apk
```

Requirements: Flutter 3.47+, JDK 17, Android SDK with **compileSdk 37**.

## Project structure

```
flutter_app/
├── lib/
│   ├── ai/          # config, chat API (SSE), tools, TTS/ASR, model management
│   ├── data/        # sqflite databases (sessions, notes, memory, tasks, audit)
│   ├── models/      # ChatMessage with ordered content blocks
│   ├── screens/     # chat, settings, notes, memory, tasks
│   ├── theme/       # light/dark themes
│   └── l10n/        # zh / en strings
├── android/         # Android host (arm64-v8a only, debug signing)
└── test/            # unit and integration tests
```

## Architecture notes

- **Message blocks**: `ChatMessage.blocks` is the single source of truth for rendering order, so
  multi-round tool conversations show every reasoning segment in place instead of merging them.
- **Speech runs in an isolate**: sherpa-onnx calls never block the UI isolate.
- **Downloads are global**: `DownloadManager` keeps running after you leave the voice settings page.
- **Streaming is throttled**: UI refreshes at most every 50 ms during streaming, with a forced flush
  at the end of each round.

## Native version

The original Kotlin/XML implementation was removed in November 2026 after full feature parity was
reached. It remains available in git history.

## License

See repository license file.
