package com.example.dodroidai

import com.example.dodroidai.ai.config.AppConfigManager
import com.example.dodroidai.ai.tools.ToolExecutor
import com.example.dodroidai.data.repository.ChatRepository
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * 应用 Application 类，管理全局配置
 */
class DoDroidAIApplication : android.app.Application() {

    val chatRepository: ChatRepository by lazy { ChatRepository(this) }

    val toolExecutor: ToolExecutor by lazy { ToolExecutor(this) }

    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        AppConfigManager.init(this)
        // 旧版单配置迁移 + 明文 Key 加密
        applicationScope.launch {
            runCatching {
                AppConfigManager.migrateIfNeeded()
                AppConfigManager.ensureEncryptedIfNeeded()
            }
        }
        // PDFBox 需要先加载 Android 资源（字体/编码表），否则解析 PDF 会失败
        PDFBoxResourceLoader.init(applicationContext)
    }
}

/**
 * 通过 Context 访问 ChatRepository,避免对 DoDroidAIApplication 单例的直接依赖
 */
val android.content.Context.chatRepository: ChatRepository
    get() = (applicationContext as DoDroidAIApplication).chatRepository

/**
 * 通过 Context 访问 ToolExecutor,避免对 DoDroidAIApplication 单例的直接依赖
 */
val android.content.Context.toolExecutor: ToolExecutor
    get() = (applicationContext as DoDroidAIApplication).toolExecutor
