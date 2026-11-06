package com.mohanlv.dodroidai

import android.Manifest
import android.content.pm.PackageManager
import android.provider.ContactsContract
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dodroidai/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "searchContacts" -> {
                        try {
                            val query = call.argument<String>("query") ?: ""
                            val limit = call.argument<Int>("limit") ?: 5
                            result.success(searchContacts(query, limit))
                        } catch (e: Exception) {
                            result.error("CONTACTS_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun searchContacts(query: String, limit: Int): List<Map<String, String>> {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            throw IllegalStateException("缺少通讯录权限，请在系统设置中授予")
        }
        val out = mutableListOf<Map<String, String>>()
        val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER
        )
        val selection =
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ? OR " +
                "${ContactsContract.CommonDataKinds.Phone.NUMBER} LIKE ?"
        val args = arrayOf("%$query%", "%$query%")
        contentResolver.query(
            uri, projection, selection, args,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
        )?.use { cursor ->
            val nameIdx = cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numberIdx = cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)
            while (cursor.moveToNext() && out.size < limit) {
                out.add(
                    mapOf(
                        "name" to (cursor.getString(nameIdx) ?: ""),
                        "number" to (cursor.getString(numberIdx) ?: "")
                    )
                )
            }
        }
        return out
    }
}
