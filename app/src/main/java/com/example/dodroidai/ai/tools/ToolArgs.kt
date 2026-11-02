package com.example.dodroidai.ai.tools

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.text.SimpleDateFormat
import java.util.Locale

class ToolArgumentException(message: String) : IllegalArgumentException(message)

/**
 * 工具参数读取与校验。缺字段、类型错误、越界统一抛 [ToolArgumentException]，
 * 由 [ToolRegistry] 转成 INVALID_ARGS 回给模型。
 */
class ToolArgs private constructor(private val json: JsonObject) {

    fun requireString(key: String): String {
        val element = json.get(key) ?: throw ToolArgumentException("缺少参数: $key")
        if (!element.isJsonPrimitive || !element.asJsonPrimitive.isString) {
            throw ToolArgumentException("参数 $key 必须是字符串")
        }
        val value = element.asString.trim()
        if (value.isEmpty()) throw ToolArgumentException("参数 $key 不能为空")
        return value
    }

    fun optionalString(key: String): String? {
        val element = json.get(key) ?: return null
        if (element.isJsonNull) return null
        if (!element.isJsonPrimitive || !element.asJsonPrimitive.isString) {
            throw ToolArgumentException("参数 $key 必须是字符串")
        }
        return element.asString.trim().ifEmpty { null }
    }

    fun requireInt(key: String, range: IntRange? = null): Int {
        val element = json.get(key) ?: throw ToolArgumentException("缺少参数: $key")
        val value = when {
            element.isJsonPrimitive && element.asJsonPrimitive.isNumber -> element.asInt
            element.isJsonPrimitive && element.asJsonPrimitive.isString ->
                element.asString.toIntOrNull() ?: throw ToolArgumentException("参数 $key 必须是整数")
            else -> throw ToolArgumentException("参数 $key 必须是整数")
        }
        if (range != null && value !in range) {
            throw ToolArgumentException("参数 $key 超出范围 ${range.first}-${range.last}: $value")
        }
        return value
    }

    fun optionalInt(key: String): Int? = if (json.has(key)) requireInt(key) else null

    fun requireIsoTime(key: String): Long {
        val raw = requireString(key)
        val patterns = listOf(
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm"
        )
        for (pattern in patterns) {
            val time = try {
                SimpleDateFormat(pattern, Locale.getDefault()).apply { isLenient = false }
                    .parse(raw)?.time
            } catch (_: Exception) {
                null
            }
            if (time != null) return time
        }
        throw ToolArgumentException("无法解析时间: $raw")
    }

    fun optionalIsoTime(key: String): Long? = if (json.has(key)) requireIsoTime(key) else null

    companion object {
        fun parse(raw: String): ToolArgs {
            val trimmed = raw.trim()
            if (trimmed.isEmpty()) return ToolArgs(JsonObject())
            val element = try {
                JsonParser.parseString(trimmed)
            } catch (e: Exception) {
                throw ToolArgumentException("参数不是合法 JSON")
            }
            if (!element.isJsonObject) throw ToolArgumentException("参数必须是 JSON 对象")
            return ToolArgs(element.asJsonObject)
        }
    }
}
