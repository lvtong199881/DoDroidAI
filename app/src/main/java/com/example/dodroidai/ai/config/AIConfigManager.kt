package com.example.dodroidai.ai.config

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ApiFormat
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "ai_config")

/**
 * AI 配置管理器，负责持久化 AI 配置
 */
class AIConfigManager(
    private val context: Context
) {
    private val providerKey = stringPreferencesKey("provider")
    private val apiKeyKey = stringPreferencesKey("api_key")
    private val baseUrlKey = stringPreferencesKey("base_url")
    private val modelKey = stringPreferencesKey("model")
    private val providerNameKey = stringPreferencesKey("provider_name")
    private val descriptionKey = stringPreferencesKey("description")
    private val officialUrlKey = stringPreferencesKey("official_url")
    private val apiFormatKey = stringPreferencesKey("api_format")
    private val mainModelKey = stringPreferencesKey("main_model")
    private val haikuModelKey = stringPreferencesKey("haiku_model")
    private val sonnetModelKey = stringPreferencesKey("sonnet_model")
    private val opusModelKey = stringPreferencesKey("opus_model")

    val configFlow: Flow<AIConfig> = context.dataStore.data.map { preferences ->
        val providerStr = preferences[providerKey] ?: AIProvider.OPENAI.name
        val provider = try {
            AIProvider.valueOf(providerStr)
        } catch (e: Exception) {
            AIProvider.OPENAI
        }
        val defaultConfig = AIConfig.default(provider)
        val apiFormatStr = preferences[apiFormatKey] ?: ApiFormat.ANTHROPIC_MESSAGES.name
        val apiFormat = try {
            ApiFormat.valueOf(apiFormatStr)
        } catch (e: Exception) {
            ApiFormat.ANTHROPIC_MESSAGES
        }
        AIConfig(
            provider = provider,
            apiKey = preferences[apiKeyKey] ?: "",
            baseUrl = preferences[baseUrlKey] ?: defaultConfig.baseUrl,
            model = preferences[modelKey] ?: defaultConfig.model,
            providerName = preferences[providerNameKey] ?: defaultConfig.providerName,
            description = preferences[descriptionKey] ?: "",
            officialUrl = preferences[officialUrlKey] ?: "",
            apiFormat = apiFormat,
            mainModel = preferences[mainModelKey] ?: defaultConfig.mainModel,
            haikuModel = preferences[haikuModelKey] ?: defaultConfig.haikuModel,
            sonnetModel = preferences[sonnetModelKey] ?: defaultConfig.sonnetModel,
            opusModel = preferences[opusModelKey] ?: defaultConfig.opusModel
        )
    }

    suspend fun updateConfig(config: AIConfig) {
        context.dataStore.edit { preferences ->
            preferences[providerKey] = config.provider.name
            preferences[apiKeyKey] = config.apiKey
            preferences[baseUrlKey] = config.baseUrl
            preferences[modelKey] = config.model
            preferences[providerNameKey] = config.providerName
            preferences[descriptionKey] = config.description
            preferences[officialUrlKey] = config.officialUrl
            preferences[apiFormatKey] = config.apiFormat.name
            preferences[mainModelKey] = config.mainModel
            preferences[haikuModelKey] = config.haikuModel
            preferences[sonnetModelKey] = config.sonnetModel
            preferences[opusModelKey] = config.opusModel
        }
    }

    suspend fun updateProvider(provider: AIProvider) {
        val defaultConfig = AIConfig.default(provider)
        context.dataStore.edit { preferences ->
            preferences[providerKey] = provider.name
            preferences[baseUrlKey] = defaultConfig.baseUrl
            preferences[modelKey] = defaultConfig.model
            preferences[providerNameKey] = defaultConfig.providerName
            preferences[apiFormatKey] = defaultConfig.apiFormat.name
            preferences[mainModelKey] = defaultConfig.mainModel
            preferences[haikuModelKey] = defaultConfig.haikuModel
            preferences[sonnetModelKey] = defaultConfig.sonnetModel
            preferences[opusModelKey] = defaultConfig.opusModel
        }
    }

    companion object {
        @Volatile
        private var INSTANCE: AIConfigManager? = null

        fun getInstance(context: Context): AIConfigManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AIConfigManager(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
}