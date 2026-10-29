package com.example.dodroidai.ai.model

import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

enum class ChatErrorKind {
    NETWORK,
    TIMEOUT,
    AUTH,
    RATE_LIMIT,
    SERVER,
    PARSE,
    UNKNOWN
}

data class ChatError(
    val kind: ChatErrorKind,
    val message: String,
    val retryable: Boolean
)

/**
 * 把网络/HTTP/解析异常归类为用户可理解的提示。
 *
 * 纯逻辑实现，便于单元测试。
 */
object ChatErrorParser {

    fun parse(error: Throwable): ChatError {
        val chain = generateSequence(error) { it.cause }.toList()
        val raw = chain.mapNotNull { it.message }
            .joinToString(" | ")
            .ifBlank { error.javaClass.simpleName }

        val isTimeout = chain.any { it is SocketTimeoutException } ||
            raw.contains("timeout", ignoreCase = true)

        val isNetwork = chain.any { it is UnknownHostException || it is ConnectException } ||
            raw.contains("failed to connect", ignoreCase = true) ||
            raw.contains("unable to resolve host", ignoreCase = true) ||
            raw.contains("connection reset", ignoreCase = true) ||
            raw.contains("network is unreachable", ignoreCase = true)

        val isAuth = raw.contains("HTTP 401") ||
            raw.contains("HTTP 403") ||
            raw.contains("invalid api key", ignoreCase = true) ||
            raw.contains("unauthorized", ignoreCase = true)

        val isRateLimit = raw.contains("HTTP 429") ||
            raw.contains("rate limit", ignoreCase = true)

        val isServer = Regex("HTTP 5\\d\\d").containsMatchIn(raw) ||
            raw.contains("server_error", ignoreCase = true)

        val isParse = raw.contains("SSE failed", ignoreCase = true) &&
            (raw.contains("parse", ignoreCase = true) || raw.contains("format", ignoreCase = true))

        return when {
            isAuth -> ChatError(ChatErrorKind.AUTH, "鉴权失败或访问被拒绝，请检查 API Key。", false)
            isRateLimit -> ChatError(ChatErrorKind.RATE_LIMIT, "请求过于频繁，请稍后重试。", true)
            isTimeout -> ChatError(ChatErrorKind.TIMEOUT, "连接超时，请检查网络后重试。", true)
            isNetwork -> ChatError(ChatErrorKind.NETWORK, "无法连接服务器，请检查网络后重试。", true)
            isServer -> ChatError(ChatErrorKind.SERVER, "服务端错误，请稍后重试。", true)
            isParse -> ChatError(ChatErrorKind.PARSE, "响应格式异常，请重试。", true)
            else -> ChatError(ChatErrorKind.UNKNOWN, "请求失败：${raw.take(200)}", true)
        }
    }
}
