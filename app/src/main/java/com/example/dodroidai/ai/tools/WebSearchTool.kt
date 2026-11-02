package com.example.dodroidai.ai.tools

import android.util.Log
import com.example.dodroidai.ai.config.AppConfigManager
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import kotlinx.coroutines.flow.first
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * 联网搜索工具，使用 Brave Search API
 */
@ToolProvider
object WebSearchTool {

    private val gson = Gson()

    /** 10 分钟缓存，相同关键词复用结果 */
    private val cache: MutableMap<String, CacheEntry> = object : LinkedHashMap<String, CacheEntry>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, CacheEntry>): Boolean {
            return size > MAX_CACHE_SIZE
        }
    }

    private data class CacheEntry(val result: String, val timestamp: Long)

    fun spec(): ToolSpec = ToolSpec(
        name = "web_search",
        description = "搜索互联网获取实时信息，如天气、新闻、股票等",
        parameters = ToolParameters(
            properties = mapOf(
                "query" to ToolProperty("string", "搜索关键词")
            ),
            required = listOf("query")
        ),
        riskLevel = RiskLevel.LOW,
        timeoutMillis = 20_000,
        execute = { ctx, args ->
            val query = args.requireString("query")

            val cached = cache[query]
            if (cached != null && System.currentTimeMillis() - cached.timestamp < CACHE_DURATION_MS) {
                Log.d(TAG, "使用缓存结果")
                ToolOutput(cached.result)
            } else {
                val apiKey = AppConfigManager.braveSearchApiKeyFlow.first()
                if (apiKey.isBlank()) {
                    ToolOutput("请先在设置中配置 Brave Search API Key", isError = true)
                } else {
                    try {
                        val result = search(ctx.httpClient, query, apiKey)
                        cache[query] = CacheEntry(result, System.currentTimeMillis())
                        ToolOutput(result)
                    } catch (e: Exception) {
                        Log.e(TAG, "搜索失败: ${e.javaClass.simpleName}")
                        ToolOutput("搜索失败: ${e.message}", isError = true)
                    }
                }
            }
        }
    )

    private fun search(httpClient: OkHttpClient, query: String, apiKey: String): String {
        val url = "$BASE_URL?${mapOf(
            "q" to query,
            "count" to MAX_RESULTS.toString()
        ).entries.joinToString("&") { "${it.key}=${java.net.URLEncoder.encode(it.value, "UTF-8")}" }}"

        val request = Request.Builder()
            .url(url)
            .header("Accept", "application/json")
            .header("X-Subscription-Token", apiKey)
            .build()

        httpClient.newCall(request).execute().use { response ->
            val body = response.body?.string()
            if (body.isNullOrBlank()) {
                Log.e(TAG, "空响应")
                return "未找到相关结果"
            }
            return parseResponse(body)
        }
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
            Log.e(TAG, "解析响应失败: ${e.javaClass.simpleName}")
            "未找到相关结果"
        }
    }

    private const val TAG = "WebSearchTool"
    private const val BASE_URL = "https://api.search.brave.com/res/v1/web/search"
    private const val MAX_RESULTS = 5
    private const val CACHE_DURATION_MS = 10 * 60 * 1000L
    private const val MAX_CACHE_SIZE = 100

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
