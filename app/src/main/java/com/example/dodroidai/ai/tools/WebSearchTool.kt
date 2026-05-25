package com.example.dodroidai.ai.tools

import android.content.Context
import android.util.Log
import com.example.dodroidai.ai.config.AppConfigManager
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import kotlinx.coroutines.flow.first
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/**
 * 联网搜索工具，使用 Brave Search API
 */
class WebSearchTool : Tool {
    override val name = "web_search"

    override val requiredPermissions = emptyList<String>()

    override val riskLevel = RiskLevel.LOW

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30L, TimeUnit.SECONDS)
        .readTimeout(30L, TimeUnit.SECONDS)
        .build()

    private val gson = Gson()

    /** 10分钟缓存，相同关键词复用结果 */
    private val cache: MutableMap<String, CacheEntry> = object : LinkedHashMap<String, CacheEntry>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, CacheEntry>): Boolean {
            return size > MAX_CACHE_SIZE
        }
    }

    private data class CacheEntry(
        val result: String,
        val timestamp: Long
    )

    override fun hasPermissions(context: Context): Boolean = true

    override fun requestPermissions(activity: android.app.Activity, callback: (Boolean) -> Unit) {
        callback(true)
    }

    override fun execute(context: Context, arguments: String): ToolResult {
        val query = parseQuery(arguments)
        if (query.isBlank()) {
            return ToolResult(
                toolCallId = "",
                toolName = name,
                success = false,
                result = "",
                error = "搜索关键词不能为空"
            )
        }

        // 检查缓存
        val cached = cache[query]
        if (cached != null && System.currentTimeMillis() - cached.timestamp < CACHE_DURATION_MS) {
            Log.d(TAG, "使用缓存结果: $query")
            return ToolResult(
                toolCallId = "",
                toolName = name,
                success = true,
                result = cached.result
            )
        }

        val apiKey = kotlinx.coroutines.runBlocking {
            AppConfigManager.braveSearchApiKeyFlow.first()
        }
        if (apiKey.isBlank()) {
            return ToolResult(
                toolCallId = "",
                toolName = name,
                success = false,
                result = "",
                error = "请先在设置中配置 Brave Search API Key"
            )
        }

        return try {
            val result = search(query, apiKey)
            // 存入缓存
            cache[query] = CacheEntry(result, System.currentTimeMillis())
            ToolResult(
                toolCallId = "",
                toolName = name,
                success = true,
                result = result
            )
        } catch (e: Exception) {
            Log.e(TAG, "搜索失败", e)
            ToolResult(
                toolCallId = "",
                toolName = name,
                success = false,
                result = "",
                error = "搜索失败: ${e.message}"
            )
        }
    }

    private fun parseQuery(arguments: String): String {
        return try {
            val json = gson.fromJson(arguments, Arguments::class.java)
            json.query
        } catch (e: Exception) {
            arguments.trim()
        }
    }

    private fun search(query: String, apiKey: String): String {
        val url = "$BASE_URL?${mapOf(
            "q" to query,
            "count" to MAX_RESULTS.toString()
        ).entries.joinToString("&") { "${it.key}=${java.net.URLEncoder.encode(it.value, "UTF-8")}" }}"

        val request = Request.Builder()
            .url(url)
            .header("Accept", "application/json")
            .header("X-Subscription-Token", apiKey)
            .build()

        val response = httpClient.newCall(request).execute()
        val body = response.body?.string() ?: throw Exception("空响应")

        return parseResponse(body)
    }

    private fun parseResponse(json: String): String {
        return try {
            val searchResponse = gson.fromJson(json, BraveSearchResponse::class.java)
            val results = searchResponse.web?.results?.take(MAX_RESULTS) ?: emptyList()

            if (results.isEmpty()) {
                "未找到相关结果"
            } else {
                results.mapIndexed { index, result ->
                    "${index + 1}. ${result.title}\n${result.url}\n${result.description}"
                }.joinToString("\n\n")
            }
        } catch (e: Exception) {
            Log.e(TAG, "解析响应失败: $json", e)
            throw e
        }
    }

    companion object {
        private const val TAG = "WebSearchTool"
        private const val BASE_URL = "https://api.search.brave.com/res/v1/web/search"
        private const val MAX_RESULTS = 5
        private const val CACHE_DURATION_MS = 10 * 60 * 1000L // 10分钟
        private const val MAX_CACHE_SIZE = 100
    }

    data class Arguments(
        val query: String
    )

    data class BraveSearchResponse(
        @SerializedName("web")
        val web: WebResults?
    )

    data class WebResults(
        @SerializedName("results")
        val results: List<WebResult>
    )

    data class WebResult(
        @SerializedName("title")
        val title: String,
        @SerializedName("url")
        val url: String,
        @SerializedName("description")
        val description: String
    )
}