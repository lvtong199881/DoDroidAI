package com.example.dodroidai.ai.model

/**
 * API 格式枚举
 */
enum class ApiFormat {
    /** Anthropic Messages 原生格式 */
    ANTHROPIC_MESSAGES,

    /** OpenAI Chat Completions 兼容格式 */
    OPENAI_CHAT_COMPLETIONS
}