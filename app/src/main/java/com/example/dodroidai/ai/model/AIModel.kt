package com.example.dodroidai.ai.model

/**
 * AI 模型接口，定义响应解析能力
 */
interface AIModel {
    fun parseResponse(body: String): ChatResponse
}