package com.example.dodroidai.ui.setting

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.config.AIConfigManager
import com.example.dodroidai.ai.model.AIProvider
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * AI 配置 ViewModel
 */
class AIConfigViewModel(
    private val configManager: AIConfigManager
) : ViewModel() {

    private val _config = MutableStateFlow(AIConfig.default(AIProvider.OPENAI))
    val config: StateFlow<AIConfig> = _config.asStateFlow()

    init {
        viewModelScope.launch {
            configManager.configFlow.collect { config ->
                _config.value = config
            }
        }
    }

    fun updateProvider(provider: AIProvider) {
        viewModelScope.launch {
            configManager.updateProvider(provider)
        }
    }

    fun updateConfig(config: AIConfig) {
        viewModelScope.launch {
            configManager.updateConfig(config)
        }
    }
}