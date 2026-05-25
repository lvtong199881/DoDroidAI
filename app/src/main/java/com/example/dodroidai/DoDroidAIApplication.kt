package com.example.dodroidai

/**
 * 应用 Application 类，管理全局配置
 */
class DoDroidAIApplication : android.app.Application() {

    lateinit var chatRepository: com.example.dodroidai.data.repository.ChatRepository
        private set

    lateinit var toolExecutor: com.example.dodroidai.ai.tools.ToolExecutor
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        chatRepository = com.example.dodroidai.data.repository.ChatRepository(this)
        toolExecutor = com.example.dodroidai.ai.tools.ToolExecutor(this)
    }

    companion object {
        lateinit var instance: DoDroidAIApplication
            private set
    }
}