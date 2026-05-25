# DoDroidAI

An Android Agent application that allows users to control their phone through natural language conversations.

---

## Features

- **Multi-Provider AI Support**: OpenAI, DeepSeek, MiniMax, Custom endpoints
- **Conversational Interface**: Chat UI with message history
- **Attachment Support**: Camera, gallery, file attachments (images, PDF, Word, TXT)
- **Markdown Rendering**: AI responses support Markdown format
- **Extended Reasoning**: Toggle extended reasoning for complex problems
- **Local Voice Recognition**: Fully offline speech-to-text based on Whisper.cpp
- **Voice/Text Input**: Switch between typing and voice input modes
- **Web Search**: Brave Search API real-time web search
- **AI Tool Use**: System operations like alarms, calendar, SMS, notes
- **Text-to-Speech**: AI response voice reading
- **Theme Customization**: Light, dark, follow system
- **Multi-language**: English, Simplified Chinese, Traditional Chinese

---

## Requirements

- Android 7.0 (API 24) or higher
- Camera permission (for taking photos)
- Network connection (for AI API calls)

---

## Getting Started

1. Configure your AI provider in Settings > AI Configuration
2. Enter your API key and model settings
3. Start a new conversation and chat naturally

---

## Tech Stack

- Kotlin
- XML Views
- Material Design 3
- Markwon (Markdown rendering)
- OkHttp + Retrofit (Networking)
- DataStore (Local storage)
- whisper.cpp (Local voice recognition)
- Android TTS (Text-to-Speech)
- MVVM Architecture
- NDK (C++ compilation)