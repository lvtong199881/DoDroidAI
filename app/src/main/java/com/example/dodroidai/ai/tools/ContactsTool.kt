package com.example.dodroidai.ai.tools

import android.Manifest
import android.provider.ContactsContract
import kotlinx.coroutines.delay

/**
 * 搜索联系人（只读，需要 READ_CONTACTS 权限）
 */
@ToolProvider
object SearchContactsTool {

    fun spec(): ToolSpec = ToolSpec(
        name = "search_contacts",
        description = "按姓名或号码搜索手机联系人，返回姓名和号码",
        parameters = ToolParameters(
            properties = mapOf(
                "query" to ToolProperty("string", "姓名或号码的一部分"),
                "limit" to ToolProperty(
                    type = "integer",
                    description = "返回条数，默认 5，最大 10",
                    minimum = 1,
                    maximum = 10,
                    defaultValue = com.google.gson.JsonPrimitive(5)
                )
            ),
            required = listOf("query")
        ),
        riskLevel = RiskLevel.MEDIUM,
        requiredPermissions = listOf(Manifest.permission.READ_CONTACTS),
        execute = { ctx, args ->
            val query = args.requireString("query")
            val limit = (args.optionalInt("limit") ?: 5).coerceIn(1, 10)
            searchContacts(ctx, query, limit)
        }
    )

    private suspend fun searchContacts(ctx: ToolContext, query: String, limit: Int): ToolOutput {
        return try {
            toOutput(queryContacts(ctx, query, limit))
        } catch (e: SecurityException) {
            // 权限刚授予时 ContentProvider 可能短暂未刷新，重试一次
            delay(250)
            try {
                toOutput(queryContacts(ctx, query, limit))
            } catch (e2: SecurityException) {
                ToolOutput("没有读取联系人的权限", isError = true)
            }
        } catch (e: Exception) {
            ToolOutput("读取联系人失败: ${e.javaClass.simpleName}", isError = true)
        }
    }

    private fun toOutput(results: List<String>): ToolOutput =
        if (results.isEmpty()) ToolOutput("未找到匹配的联系人") else ToolOutput(results.joinToString("\n"))

    private fun queryContacts(ctx: ToolContext, query: String, limit: Int): List<String> {
        val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER
        )
        val selection =
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ? OR " +
                "${ContactsContract.CommonDataKinds.Phone.NUMBER} LIKE ?"
        val selectionArgs = arrayOf("%$query%", "%$query%")

        return ctx.appContext.contentResolver.query(
            uri,
            projection,
            selection,
            selectionArgs,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
        )?.use { cursor ->
            val results = mutableListOf<String>()
            while (cursor.moveToNext() && results.size < limit) {
                val name = cursor.getString(0).orEmpty()
                val number = cursor.getString(1).orEmpty()
                if (name.isNotBlank() || number.isNotBlank()) {
                    results.add("$name: $number")
                }
            }
            results
        } ?: emptyList()
    }
}
