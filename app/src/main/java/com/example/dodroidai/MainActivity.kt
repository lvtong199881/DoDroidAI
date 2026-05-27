package com.example.dodroidai

import android.content.Context
import android.content.res.Configuration
import android.os.Bundle
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.GravityCompat
import androidx.drawerlayout.widget.DrawerLayout
import com.example.dodroidai.ai.config.AppConfigManager
import com.example.dodroidai.ui.chat.ChatFragment
import com.example.dodroidai.ui.chat.ChatListFragment
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import java.util.Locale

/**
 * 主 Activity，应用入口
 */
class MainActivity : AppCompatActivity() {

    private var chatListFragment: ChatListFragment? = null

    private var drawerLayout: DrawerLayout? = null

    override fun attachBaseContext(newBase: Context) {
        // 先应用主题
        val theme = runCatching {
            runBlocking { AppConfigManager.themeFlow.first() }
        }.getOrNull() ?: AppConfigManager.THEME_SYSTEM
        applyTheme(theme)

        // 再应用语言
        val language = runCatching {
            runBlocking { AppConfigManager.languageFlow.first() }
        }.getOrDefault("en")
        val context = updateLocale(newBase, language)
        super.attachBaseContext(context)
    }

    private fun applyTheme(theme: String) {
        val mode = when (theme) {
            AppConfigManager.THEME_LIGHT -> AppCompatDelegate.MODE_NIGHT_NO
            AppConfigManager.THEME_DARK -> AppCompatDelegate.MODE_NIGHT_YES
            else -> AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
        }
        AppCompatDelegate.setDefaultNightMode(mode)
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
        installSplashScreen()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        drawerLayout = findViewById(R.id.drawerLayout)

        if (savedInstanceState == null) {
            // 默认启动 ChatFragment（无 sessionId）
            supportFragmentManager.beginTransaction()
                .replace(R.id.fragment_container, ChatFragment.newInstance(null))
                .commit()

            // 预加载侧边栏中的 ChatListFragment
            chatListFragment = ChatListFragment.newInstance()
            chatListFragment?.setDrawerMode(true)
            chatListFragment?.onSessionSelected = { sessionId ->
                supportFragmentManager.beginTransaction()
                    .replace(R.id.fragment_container, ChatFragment.newInstance(sessionId))
                    .commit()
            }
            supportFragmentManager.beginTransaction()
                .replace(R.id.drawer_container, chatListFragment!!)
                .commit()
        }

        // 处理返回键关闭侧边栏
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (drawerLayout?.isDrawerOpen(GravityCompat.START) == true) {
                    drawerLayout?.closeDrawer(GravityCompat.START)
                } else {
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                }
            }
        })
    }

    fun openDrawer() {
        drawerLayout?.openDrawer(GravityCompat.START)
    }

    fun closeDrawer() {
        drawerLayout?.closeDrawer(GravityCompat.START)
    }

    fun toggleDrawer() {
        if (drawerLayout?.isDrawerOpen(GravityCompat.START) == true) {
            closeDrawer()
        } else {
            openDrawer()
        }
    }
}