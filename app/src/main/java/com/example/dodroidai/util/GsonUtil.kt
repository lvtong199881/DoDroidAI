package com.example.dodroidai.util

import android.util.Log
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.reflect.TypeToken

/**
 * Gson 工具类
 */
object GsonUtil {
    private const val TAG = "GsonUtil"

    @PublishedApi
    internal val gson: Gson = GsonBuilder()
        .serializeNulls()
        .create()

    /**
     * 将 JSON 字符串解析为指定类型
     */
    fun <T> fromJson(json: String?, clazz: Class<T>): T? {
        return try {
            json?.let { gson.fromJson(it, clazz) }
        } catch (e: Exception) {
            Log.e(TAG, "fromJson failed", e)
            null
        }
    }

    /**
     * 将 JSON 字符串解析为指定类型（使用 TypeToken）
     */
    fun <T> fromJsonWithTypeToken(json: String?, typeToken: TypeToken<T>): T? {
        return try {
            json?.let { gson.fromJson(it, typeToken) }
        } catch (e: Exception) {
            Log.e(TAG, "fromJsonWithTypeToken failed", e)
            null
        }
    }

    /**
     * 将对象序列化为 JSON 字符串
     */
    fun toJson(obj: Any?): String? {
        return try {
            obj?.let { gson.toJson(it) }
        } catch (e: Exception) {
            Log.e(TAG, "toJson failed", e)
            null
        }
    }

    /**
     * 将对象序列化为 JSON 字符串（格式化输出）
     */
    fun toJsonPretty(obj: Any?): String? {
        return try {
            obj?.let { GsonBuilder().setPrettyPrinting().create().toJson(it) }
        } catch (e: Exception) {
            Log.e(TAG, "toJsonPretty failed", e)
            null
        }
    }
}