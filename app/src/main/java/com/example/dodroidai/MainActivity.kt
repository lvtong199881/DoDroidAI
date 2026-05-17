package com.example.dodroidai

import android.content.Context
import android.content.res.Configuration
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.dodroidai.ai.config.AppConfigManager
import com.example.dodroidai.ui.chat.ChatListFragment
import kotlinx.coroutines.flow.first
import java.util.Locale

/**
 * 主 Activity，应用入口
 */
class MainActivity : AppCompatActivity() {

    private var appConfigManager: com.example.dodroidai.ai.config.AppConfigManager? = null

    override fun attachBaseContext(newBase: Context) {
        val app = newBase.applicationContext as DoDroidAIApplication
        appConfigManager = app.appConfigManager

        // 先应用主题
        val theme = runCatching {
            kotlinx.coroutines.runBlocking { appConfigManager?.themeFlow?.first() }
        }.getOrNull() ?: AppConfigManager.THEME_SYSTEM
        applyTheme(theme)

        // 再应用语言
        val language = runCatching {
            kotlinx.coroutines.runBlocking { appConfigManager?.languageFlow?.first() }
        }.getOrDefault("en") ?: "en"
        val context = updateLocale(newBase, language)
        super.attachBaseContext(context)
    }

    private fun applyTheme(theme: String) {
        val mode = when (theme) {
            AppConfigManager.THEME_LIGHT -> androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_NO
            AppConfigManager.THEME_DARK -> androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_YES
            else -> androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
        }
        androidx.appcompat.app.AppCompatDelegate.setDefaultNightMode(mode)
    }

    private fun updateLocale(context: Context, language: String): Context {
        val locale = when (language) {
            "zh-rCN" -> Locale.SIMPLIFIED_CHINESE
            "zh-rTW" -> Locale.TRADITIONAL_CHINESE
            else -> Locale.ENGLISH
        }
        Locale.setDefault(locale)
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        return context.createConfigurationContext(config)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(R.id.fragment_container, ChatListFragment())
                .commit()
        }
    }
}