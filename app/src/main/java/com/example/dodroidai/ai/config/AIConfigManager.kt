package com.example.dodroidai.ai.config

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.example.dodroidai.ai.model.AIProvider
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

    val configFlow: Flow<AIConfig> = context.dataStore.data.map { preferences ->
        val providerStr = preferences[providerKey] ?: AIProvider.OPENAI.name
        val provider = try {
            AIProvider.valueOf(providerStr)
        } catch (e: Exception) {
            AIProvider.OPENAI
        }
        AIConfig(
            provider = provider,
            apiKey = preferences[apiKeyKey] ?: "",
            baseUrl = preferences[baseUrlKey] ?: AIConfig.default(provider).baseUrl,
            model = preferences[modelKey] ?: AIConfig.default(provider).model
        )
    }

    suspend fun updateConfig(config: AIConfig) {
        context.dataStore.edit { preferences ->
            preferences[providerKey] = config.provider.name
            preferences[apiKeyKey] = config.apiKey
            preferences[baseUrlKey] = config.baseUrl
            preferences[modelKey] = config.model
        }
    }

    suspend fun updateProvider(provider: AIProvider) {
        context.dataStore.edit { preferences ->
            preferences[providerKey] = provider.name
            preferences[baseUrlKey] = AIConfig.default(provider).baseUrl
            preferences[modelKey] = AIConfig.default(provider).model
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