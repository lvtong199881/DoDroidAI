package com.example.dodroidai

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.os.Bundle
import android.view.View
import androidx.activity.OnBackPressedCallback
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.view.GravityCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.drawerlayout.widget.DrawerLayout
import com.example.dodroidai.ai.config.AppConfigManager
import com.example.dodroidai.ui.chat.ChatFragment
import com.example.dodroidai.ui.chat.ChatListFragment
import com.example.dodroidai.webviewsdk.WebViewEntry
import java.util.Locale

/**
 * 主 Activity，应用入口
 */
class MainActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_NEW_CHAT = "new_chat"
        const val EXTRA_OPEN_WEB = "open_web"

        private const val LANG_EN = "en"
        private const val LANG_ZH_CN = "zh-rCN"
        private const val LANG_ZH_TW = "zh-rTW"
    }

    private var chatListFragment: ChatListFragment? = null

    private var drawerLayout: DrawerLayout? = null

    override fun attachBaseContext(newBase: Context) {
        // 从 Application.onCreate 预热的内存缓存同步读取,避免阻塞主线程
        applyTheme(AppConfigManager.cachedTheme)
        val context = updateLocale(newBase, AppConfigManager.cachedLanguage)
        super.attachBaseContext(context)
    }

    private fun applySystemBarInsets() {
        val root = findViewById<View>(R.id.drawerLayout)
        val fragmentContainer = findViewById<View>(R.id.fragment_container)
        val drawerContainer = findViewById<View>(R.id.drawer_container)
        // DrawerLayout 会消费 systemBars insets，这里在根上统一分配并返回 CONSUMED
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            fragmentContainer.setPadding(0, bars.top, 0, bars.bottom)
            drawerContainer.setPadding(0, bars.top, 0, bars.bottom)
            WindowInsetsCompat.CONSUMED
        }
    }

    private fun applyBarAppearance() {
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        val isDark = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        controller.isAppearanceLightStatusBars = !isDark
        controller.isAppearanceLightNavigationBars = !isDark
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
            LANG_ZH_CN -> Locale.SIMPLIFIED_CHINESE
            LANG_ZH_TW -> Locale.TRADITIONAL_CHINESE
            else -> Locale.ENGLISH
        }
        Locale.setDefault(locale)
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        return context.createConfigurationContext(config)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        setContentView(R.layout.activity_main)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        drawerLayout = findViewById(R.id.drawerLayout)
        applySystemBarInsets()
        applyBarAppearance()

        if (savedInstanceState == null) {
            // 检测是否从 widget 点击启动新对话
            val startNewChat = intent?.getBooleanExtra(EXTRA_NEW_CHAT, false) ?: false

            // 检测是否从 shortcut 启动 WebFragment
            val openWeb = intent?.getBooleanExtra(EXTRA_OPEN_WEB, false) ?: false

            if (openWeb) {
                // 启动 WebFragment(看看去 shortcut):
                // 先后 add 两个 fragment,ChatFragment 在底(无 back stack),
                // WebFragment 在上(有 back stack);关闭 WebFragment 后 ChatFragment 仍保留
                supportFragmentManager.beginTransaction()
                    .add(R.id.fragment_container, ChatFragment.newInstance(null))
                    .commit()
                WebViewEntry.show(this, R.id.fragment_container)
            } else {
                // 默认启动 ChatFragment(无 sessionId)
                supportFragmentManager.beginTransaction()
                    .replace(R.id.fragment_container, ChatFragment.newInstance(null))
                    .commit()
            }

            // 预加载侧边栏中的 ChatListFragment
            chatListFragment = ChatListFragment.newInstance()
            chatListFragment?.setDrawerMode(true)
            chatListFragment?.onSessionSelected = { sessionId ->
                supportFragmentManager.beginTransaction()
                    .replace(R.id.fragment_container, ChatFragment.newInstance(sessionId))
                    .commit()
            }
            supportFragmentManager.beginTransaction()
                .replace(R.id.drawer_container, chatListFragment ?: return)
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