package com.example.dodroidai.ui.setting

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.config.AppConfigManager
import com.example.dodroidai.ai.model.AIProvider
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 设置页面 ViewModel
 */
class SettingsViewModel : ViewModel() {

    private val _config = MutableStateFlow(AIConfig.default(AIProvider.OPENAI))
    val config: StateFlow<AIConfig> = _config.asStateFlow()

    init {
        viewModelScope.launch {
            AppConfigManager.configFlow.collect { config ->
                _config.value = config
            }
        }
    }
}