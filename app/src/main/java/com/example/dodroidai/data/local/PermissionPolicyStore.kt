package com.example.dodroidai.data.local

import android.content.Context

/**
 * 记录用户对工具权限的选择，避免反复弹窗打扰。
 *
 * key = "toolName|permission"，拒绝过且系统权限仍缺失时直接返回失败，
 * 用户可在「设置 → 工具审计 → 重置权限提示」中清除。
 */
object PermissionPolicyStore {

    private const val PREFS = "permission_policy"
    private const val KEY_DENIED = "denied_tool_permissions"

    fun isDenied(context: Context, toolName: String, permission: String): Boolean =
        prefs(context).getStringSet(KEY_DENIED, emptySet()).orEmpty()
            .contains(key(toolName, permission))

    fun markDenied(context: Context, toolName: String, permission: String) {
        val set = prefs(context).getStringSet(KEY_DENIED, emptySet()).orEmpty().toMutableSet()
        set.add(key(toolName, permission))
        prefs(context).edit().putStringSet(KEY_DENIED, set).apply()
    }

    fun clearDenied(context: Context, toolName: String, permission: String) {
        val set = prefs(context).getStringSet(KEY_DENIED, emptySet()).orEmpty().toMutableSet()
        if (set.remove(key(toolName, permission))) {
            prefs(context).edit().putStringSet(KEY_DENIED, set).apply()
        }
    }

    fun clear(context: Context) {
        prefs(context).edit().remove(KEY_DENIED).apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun key(toolName: String, permission: String) = "$toolName|$permission"
}
