package com.example.dodroidai

/**
 * 应用 Application 类，管理全局配置
 */
class DoDroidAIApplication : android.app.Application() {

    lateinit var configManager: com.example.dodroidai.ai.config.AIConfigManager
        private set

    lateinit var appConfigManager: com.example.dodroidai.ai.config.AppConfigManager
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        configManager = com.example.dodroidai.ai.config.AIConfigManager(this)
        appConfigManager = com.example.dodroidai.ai.config.AppConfigManager(this)
    }

    companion object {
        lateinit var instance: DoDroidAIApplication
            private set
    }
}