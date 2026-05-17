# DoDroidAI

An Android Agent application that allows users to control their phone through natural language conversations.

一个可以让用户通过自然语言对话来控制手机的 Android Agent 应用。

---

## 功能 | Features

- **多 AI 提供商支持 | Multi-Provider AI Support**: OpenAI, DeepSeek, MiniMax, 自定义端点
- **对话界面 | Conversational Interface**: 聊天界面，支持消息历史
- **附件支持 | Attachment Support**: 拍照、相册选择、文件附件（图片、PDF、Word、TXT）
- **Markdown 渲染 | Markdown Rendering**: AI 回复支持 Markdown 格式展示
- **深度思考模式 | Deep Think Mode**: 切换扩展推理用于复杂问题
- **语音/文字输入 | Voice/Text Input**: 在打字和语音输入模式间切换
- **主题定制 | Theme Customization**: 浅色、深色跟随系统
- **多语言 | Multi-language**: 英文、简体中文、繁体中文

---

## 要求 | Requirements

- Android 7.0 (API 24) 或更高
- 相机权限（用于拍照）
- 网络连接（用于 AI API 调用）

---

## 快速开始 | Getting Started

1. 在 设置 > AI 配置 中配置您的 AI 提供商
2. Configure your AI provider in Settings > AI Configuration
3. 输入您的 API key 和模型设置 / Enter your API key and model settings
4. 开始新对话并自然聊天 / Start a new conversation and chat naturally

---

## 技术栈 | Tech Stack

- Kotlin
- XML Views
- Material Design 3
- Markwon (Markdown 渲染)
- AndroidX
- MVVM Architecture