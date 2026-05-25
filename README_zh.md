# DoDroidAI

一个可以让用户通过自然语言对话来控制手机的 Android Agent 应用。

---

## 功能

- **多 AI 提供商支持**: OpenAI, DeepSeek, MiniMax, 自定义端点
- **对话界面**: 聊天界面，支持消息历史
- **附件支持**: 拍照、相册选择、文件附件（图片、PDF、Word、TXT）
- **Markdown 渲染**: AI 回复支持 Markdown 格式展示
- **扩展推理模式**: 切换扩展推理用于复杂问题
- **本地语音识别**: 基于 Whisper.cpp 的完全离线语音转文字
- **语音/文字输入**: 在打字和语音输入模式间切换
- **联网搜索**: Brave Search API 实时网络搜索
- **AI 工具调用**: 闹钟、日历、短信、笔记等系统操作
- **TTS 语音播报**: AI 回复语音朗读
- **主题定制**: 浅色、深色跟随系统
- **多语言**: 英文、简体中文、繁体中文

---

## 要求

- Android 7.0 (API 24) 或更高
- 相机权限（用于拍照）
- 网络连接（用于 AI API 调用）

---

## 快速开始

1. 在设置 > AI 配置中配置您的 AI 提供商
2. 输入您的 API key 和模型设置
3. 开始新对话并自然聊天

---

## 技术栈

- Kotlin
- XML Views
- Material Design 3
- Markwon (Markdown 渲染)
- OkHttp + Retrofit (网络)
- DataStore (本地存储)
- whisper.cpp (本地语音识别)
- Android TTS (语音合成)
- MVVM Architecture
- NDK (C++ 编译)