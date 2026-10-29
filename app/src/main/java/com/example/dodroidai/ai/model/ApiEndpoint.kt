package com.example.dodroidai.ai.model

/**
 * API 端点拼接与 baseUrl 规范化。
 *
 * 配置中的 baseUrl 统一视为“根地址”（不含 `/v1`、`/v1/messages`、`/v1/chat/completions`），
 * 请求时按格式拼接，避免 `/v1/v1/...` 这类重复。
 */
object ApiEndpoint {

    fun normalizeBaseUrl(raw: String): String {
        return raw.trim()
            .trimEnd('/')
            .removeSuffix("/v1/messages")
            .removeSuffix("/v1/chat/completions")
            .removeSuffix("/v1")
            .trimEnd('/')
    }

    fun anthropicMessagesUrl(baseUrl: String): String =
        "${normalizeBaseUrl(baseUrl)}/v1/messages"

    fun openAiChatCompletionsUrl(baseUrl: String): String =
        "${normalizeBaseUrl(baseUrl)}/v1/chat/completions"
}
