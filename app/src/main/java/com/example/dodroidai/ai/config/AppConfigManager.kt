package com.example.dodroidai.ai.config

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.appDataStore: DataStore<Preferences> by preferencesDataStore(name = "app_config")

/**
 * 应用配置管理器，负责持久化应用级配置（如语言、主题）
 */
class AppConfigManager(
    private val context: Context
) {
    private val languageKey = stringPreferencesKey("language")
    private val themeKey = stringPreferencesKey("theme")

    val languageFlow: Flow<String> = context.appDataStore.data.map { preferences ->
        preferences[languageKey] ?: "en"
    }

    val themeFlow: Flow<String> = context.appDataStore.data.map { preferences ->
        preferences[themeKey] ?: "system"
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

    companion object {
        const val THEME_SYSTEM = "system"
        const val THEME_LIGHT = "light"
        const val THEME_DARK = "dark"
    }
}