package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.attachments.EncodedAttachment
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.streaming.AnthropicSseListener
import com.example.dodroidai.ai.streaming.OpenAiSseListener
import com.example.dodroidai.ai.tools.ToolDefinition

/**
 * 根据配置的 [ApiFormat] 构建请求。
 */
object ApiRequestFactory {

    fun build(
        config: AIConfig,
        messages: List<ChatMessage>,
        encoded: Map<Long, List<EncodedAttachment>>,
        tools: List<ToolDefinition>?,
        sessionId: String? = null
    ): PreparedRequest = when (config.apiFormat) {
        ApiFormat.ANTHROPIC_MESSAGES -> {
            val messagesBody = ChatRequestBuilder.buildAnthropic(messages, encoded)
            PreparedRequest(
                request = createAnthropicRequest(config, messagesBody, tools),
                listenerFactory = { callback -> AnthropicSseListener(callback) }
            )
        }

        ApiFormat.OPENAI_CHAT_COMPLETIONS -> {
            val body = OpenAiChatRequestBuilder.buildBody(
                model = config.model,
                messages = messages,
                encoded = encoded,
                tools = tools
            )
            PreparedRequest(
                request = createOpenAiRequest(config, body, sessionId),
                listenerFactory = { callback -> OpenAiSseListener(callback) }
            )
        }
    }
}
