package com.example.dodroidai.ai.config

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ApiFormat
import com.example.dodroidai.util.GsonUtil
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.appDataStore: DataStore<Preferences> by preferencesDataStore(name = "app_config")
private val Context.aiDataStore: DataStore<Preferences> by preferencesDataStore(name = "ai_config")

/**
 * 应用配置管理器，负责持久化应用级配置
 */
object AppConfigManager {
    // 主题常量
    const val THEME_SYSTEM = "system"
    const val THEME_LIGHT = "light"
    const val THEME_DARK = "dark"

    private val context: Context
        get() = com.example.dodroidai.DoDroidAIApplication.instance

    // ===== 应用级配置 =====
    private val languageKey = stringPreferencesKey("language")
    private val themeKey = stringPreferencesKey("theme")
    private val braveSearchApiKeyKey = stringPreferencesKey("brave_search_api_key")

    val languageFlow: Flow<String> = context.appDataStore.data.map { preferences ->
        preferences[languageKey] ?: "en"
    }

    val themeFlow: Flow<String> = context.appDataStore.data.map { preferences ->
        preferences[themeKey] ?: "system"
    }

    val braveSearchApiKeyFlow: Flow<String> = context.appDataStore.data.map { preferences ->
        preferences[braveSearchApiKeyKey] ?: ""
    }

    suspend fun updateLanguage(language: String) {
        context.appDataStore.edit { preferences ->
            preferences[languageKey] = language
        }
    }

    suspend fun updateTheme(theme: String) {
        context.appDataStore.edit { preferences ->
            preferences[themeKey] = theme
        }
    }

    suspend fun updateBraveSearchApiKey(apiKey: String) {
        context.appDataStore.edit { preferences ->
            preferences[braveSearchApiKeyKey] = apiKey
        }
    }

    // ===== AI 配置（新版多配置） =====

    //旧版 Key（用于迁移）
    private val oldProviderKey = stringPreferencesKey("provider")
    private val oldApiKeyKey = stringPreferencesKey("api_key")
    private val oldBaseUrlKey = stringPreferencesKey("base_url")
    private val oldModelKey = stringPreferencesKey("model")
    private val oldProviderNameKey = stringPreferencesKey("provider_name")
    private val oldDescriptionKey = stringPreferencesKey("description")
    private val oldOfficialUrlKey = stringPreferencesKey("official_url")
    private val oldApiFormatKey = stringPreferencesKey("api_format")
    private val oldMainModelKey = stringPreferencesKey("main_model")
    private val oldHaikuModelKey = stringPreferencesKey("haiku_model")
    private val oldSonnetModelKey = stringPreferencesKey("sonnet_model")
    private val oldOpusModelKey = stringPreferencesKey("opus_model")

    // 新版 Key
    private val configsKey = stringPreferencesKey("configs")
    private val activeConfigIdKey = stringPreferencesKey("active_config_id")

    private val configsListTypeToken = object : TypeToken<List<AIConfig>>() {}

    val configsFlow: Flow<List<AIConfig>> = context.aiDataStore.data.map { preferences ->
        val configsJson = preferences[configsKey]
        if (configsJson.isNullOrEmpty()) {
            emptyList()
        } else {
            GsonUtil.fromJsonWithTypeToken(configsJson, configsListTypeToken) ?: emptyList()
        }
    }

    val activeConfigIdFlow: Flow<String?> = context.aiDataStore.data.map { preferences ->
        preferences[activeConfigIdKey]
    }

    val activeConfigFlow: Flow<AIConfig?> = combine(configsFlow, activeConfigIdFlow) { configs, activeId ->
        configs.find { it.id == activeId } ?: configs.firstOrNull()
    }

    // 保持向后兼容，返回激活配置（用于 ChatViewModel 等）
    val configFlow: Flow<AIConfig> = activeConfigFlow.map { config ->
        config ?: AIConfig.default(AIProvider.OPENAI)
    }

    suspend fun addConfig(config: AIConfig): String {
        val newConfig = config.copy(
            id = java.util.UUID.randomUUID().toString(),
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        context.aiDataStore.edit { preferences ->
            val configs = getConfigsList(preferences)
            val updatedConfigs = configs + newConfig
            preferences[configsKey] = GsonUtil.toJson(updatedConfigs) ?: "[]"
            // 如果是第一个配置，自动设为激活
            if (configs.isEmpty()) {
                preferences[activeConfigIdKey] = newConfig.id
            }
        }
        return newConfig.id
    }

    suspend fun updateConfig(config: AIConfig) {
        context.aiDataStore.edit { preferences ->
            val configs = getConfigsList(preferences)
            val updatedConfigs = configs.map {
                if (it.id == config.id) {
                    config.copy(updatedAt = System.currentTimeMillis())
                } else {
                    it
                }
            }
            preferences[configsKey] = GsonUtil.toJson(updatedConfigs) ?: "[]"
        }
    }

    suspend fun deleteConfig(configId: String) {
        context.aiDataStore.edit { preferences ->
            val configs = getConfigsList(preferences)
            val updatedConfigs = configs.filter { it.id != configId }
            preferences[configsKey] = GsonUtil.toJson(updatedConfigs) ?: "[]"

            // 如果删除的是激活配置，且还有其他配置，选第一个
            val currentActiveId = preferences[activeConfigIdKey]
            if (currentActiveId == configId && updatedConfigs.isNotEmpty()) {
                preferences[activeConfigIdKey] = updatedConfigs.first().id
            } else if (updatedConfigs.isEmpty()) {
                preferences.remove(activeConfigIdKey)
            }
        }
    }

    suspend fun setActiveConfig(configId: String) {
        context.aiDataStore.edit { preferences ->
            preferences[activeConfigIdKey] = configId
        }
    }

    suspend fun getConfig(configId: String): AIConfig? {
        return configsFlow.first().find { it.id == configId }
    }

    suspend fun cloneConfig(configId: String): String? {
        val config = getConfig(configId) ?: return null
        return addConfig(config.copy(id = java.util.UUID.randomUUID().toString()))
    }

    suspend fun migrateIfNeeded(): Boolean {
        val preferences = context.aiDataStore.data.first()
        val configsJson = preferences[configsKey]

        // 检查是否需要迁移（configsKey 为空但旧数据存在）
        if (configsJson.isNullOrEmpty()) {
            val oldProvider = preferences[oldProviderKey]
            if (oldProvider != null) {
                // 存在旧数据，执行迁移
                val provider = try {
                    AIProvider.valueOf(oldProvider)
                } catch (e: Exception) {
                    AIProvider.OPENAI
                }
                val defaultConfig = AIConfig.default(provider)
                val apiFormatStr = preferences[oldApiFormatKey] ?: ApiFormat.ANTHROPIC_MESSAGES.name
                val apiFormat = try {
                    ApiFormat.valueOf(apiFormatStr)
                } catch (e: Exception) {
                    ApiFormat.ANTHROPIC_MESSAGES
                }

                val oldConfig = AIConfig(
                    provider = provider,
                    apiKey = preferences[oldApiKeyKey] ?: "",
                    baseUrl = preferences[oldBaseUrlKey] ?: defaultConfig.baseUrl,
                    model = preferences[oldModelKey] ?: defaultConfig.model,
                    providerName = preferences[oldProviderNameKey] ?: defaultConfig.providerName,
                    description = preferences[oldDescriptionKey] ?: "",
                    officialUrl = preferences[oldOfficialUrlKey] ?: "",
                    apiFormat = apiFormat,
                    mainModel = preferences[oldMainModelKey] ?: defaultConfig.mainModel,
                    haikuModel = preferences[oldHaikuModelKey] ?: defaultConfig.haikuModel,
                    sonnetModel = preferences[oldSonnetModelKey] ?: defaultConfig.sonnetModel,
                    opusModel = preferences[oldOpusModelKey] ?: defaultConfig.opusModel
                )
                addConfig(oldConfig)
                return true
            }
        }
        return false
    }

    private fun getConfigsList(preferences: Preferences): List<AIConfig> {
        val configsJson = preferences[configsKey]
        return if (configsJson.isNullOrEmpty()) {
            emptyList()
        } else {
            GsonUtil.fromJsonWithTypeToken(configsJson, configsListTypeToken) ?: emptyList()
        }
    }

    // ===== 旧版方法（保留用于兼容） =====

    suspend fun updateProvider(provider: AIProvider) {
        val currentConfig = activeConfigFlow.first() ?: AIConfig.default(provider)
        if (currentConfig.provider != provider) {
            val defaultConfig = AIConfig.default(provider)
            updateConfig(currentConfig.copy(
                provider = provider,
                baseUrl = defaultConfig.baseUrl,
                model = defaultConfig.model,
                providerName = defaultConfig.providerName,
                apiFormat = defaultConfig.apiFormat,
                mainModel = defaultConfig.mainModel,
                haikuModel = defaultConfig.haikuModel,
                sonnetModel = defaultConfig.sonnetModel,
                opusModel = defaultConfig.opusModel
            ))
        }
    }
}