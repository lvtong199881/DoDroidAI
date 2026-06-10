package com.example.dodroidai.ui.setting

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.config.AppConfigManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * AI 配置列表 ViewModel
 */
class AIConfigListViewModel : ViewModel() {

    private val _configs = MutableStateFlow<List<AIConfig>>(emptyList())
    val configs: StateFlow<List<AIConfig>> = _configs.asStateFlow()

    private val _activeConfigId = MutableStateFlow<String?>(null)
    val activeConfigId: StateFlow<String?> = _activeConfigId.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    init {
        viewModelScope.launch {
            AppConfigManager.configsFlow.collect { _configs.value = it }
        }
        viewModelScope.launch {
            AppConfigManager.activeConfigIdFlow.collect { _activeConfigId.value = it }
        }
    }

    fun addConfig(config: AIConfig) {
        viewModelScope.launch {
            _isLoading.value = true
            AppConfigManager.addConfig(config)
            _isLoading.value = false
        }
    }

    fun updateConfig(config: AIConfig) {
        viewModelScope.launch {
            AppConfigManager.updateConfig(config)
        }
    }

    fun deleteConfig(configId: String) {
        viewModelScope.launch {
            AppConfigManager.deleteConfig(configId)
        }
    }

    fun setActiveConfig(configId: String) {
        viewModelScope.launch {
            AppConfigManager.setActiveConfig(configId)
        }
    }

    fun cloneConfig(configId: String) {
        viewModelScope.launch {
            AppConfigManager.cloneConfig(configId)
        }
    }
}