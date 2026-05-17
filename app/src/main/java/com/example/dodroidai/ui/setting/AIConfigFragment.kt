package com.example.dodroidai.ui.setting

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.AutoCompleteTextView
import android.widget.Button
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.example.dodroidai.DoDroidAIApplication
import com.example.dodroidai.R
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ui.common.Toolbar
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout
import kotlinx.coroutines.launch

/**
 * AI 配置页面 Fragment，配置 API Key、模型等
 */
class AIConfigFragment : Fragment() {

    private var viewModel: AIConfigViewModel? = null

    private var providerDropdown: AutoCompleteTextView? = null
    private var apiKeyInput: TextInputEditText? = null
    private var modelLayout: TextInputLayout? = null
    private var modelInput: TextInputEditText? = null
    private var baseUrlLayout: TextInputLayout? = null
    private var baseUrlInput: TextInputEditText? = null
    private var saveButton: Button? = null

    private var currentProvider: AIProvider = AIProvider.OPENAI
    private var toolbar: Toolbar? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        viewModel = AIConfigViewModel(DoDroidAIApplication.instance.configManager)
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return inflater.inflate(R.layout.fragment_ai_config, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        providerDropdown = view.findViewById(R.id.providerDropdown)
        apiKeyInput = view.findViewById(R.id.apiKeyInput)
        modelLayout = view.findViewById(R.id.modelLayout)
        modelInput = view.findViewById(R.id.modelInput)
        baseUrlLayout = view.findViewById(R.id.baseUrlLayout)
        baseUrlInput = view.findViewById(R.id.baseUrlInput)
        saveButton = view.findViewById(R.id.saveButton)
        toolbar = view.findViewById(R.id.toolbar)

        toolbar?.setTitle(R.string.ai_config_title)
        toolbar?.setOnBackClickListener {
            parentFragmentManager.popBackStack()
        }
        toolbar?.setRightVisible(false)

        setupProviderDropdown()
        setupSaveButton()
        observeConfig()
    }

    private fun setupProviderDropdown() {
        val adapter = ProviderIconAdapter(requireContext(), AIProvider.entries.toList())
        providerDropdown?.setAdapter(adapter)
        providerDropdown?.setOnItemClickListener { _, _, position, _ ->
            val provider = AIProvider.entries[position]
            currentProvider = provider
            viewModel?.updateProvider(provider)
            updateInputVisibility(provider)
        }
    }

    private fun updateInputVisibility(provider: AIProvider) {
        val isCustom = provider == AIProvider.CUSTOM
        modelLayout?.visibility = if (isCustom) View.VISIBLE else View.GONE
        baseUrlLayout?.visibility = if (isCustom) View.VISIBLE else View.GONE
    }

    private fun getProviderDisplayName(provider: AIProvider): String {
        return when (provider) {
            AIProvider.OPENAI -> getString(R.string.provider_openai)
            AIProvider.DEEPSEEK -> getString(R.string.provider_deepseek)
            AIProvider.MINIMAX -> getString(R.string.provider_minimax)
            AIProvider.CUSTOM -> getString(R.string.provider_custom)
        }
    }

    private fun setupSaveButton() {
        saveButton?.setOnClickListener {
            val apiKey = apiKeyInput?.text.toString().trim()

            if (apiKey.isEmpty()) {
                Toast.makeText(context, R.string.error_api_key_empty, Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            val config = viewModel?.config?.value ?: return@setOnClickListener

            if (currentProvider == AIProvider.CUSTOM) {
                val model = modelInput?.text.toString().trim()
                val baseUrl = baseUrlInput?.text.toString().trim()

                if (model.isEmpty()) {
                    Toast.makeText(context, R.string.error_model_empty, Toast.LENGTH_SHORT).show()
                    return@setOnClickListener
                }
                if (baseUrl.isEmpty()) {
                    Toast.makeText(context, R.string.error_base_url_empty, Toast.LENGTH_SHORT).show()
                    return@setOnClickListener
                }

                val newConfig = config.copy(
                    provider = currentProvider,
                    apiKey = apiKey,
                    model = model,
                    baseUrl = baseUrl
                )
                viewModel?.updateConfig(newConfig)
            } else {
                val newConfig = config.copy(
                    provider = currentProvider,
                    apiKey = apiKey
                )
                viewModel?.updateConfig(newConfig)
            }
            parentFragmentManager.popBackStack()
        }
    }

    private fun observeConfig() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel?.config?.collect { config ->
                    updateUI(config)
                }
            }
        }
    }

    private fun updateUI(config: AIConfig) {
        currentProvider = config.provider
        val displayName = getProviderDisplayName(config.provider)
        providerDropdown?.setText(displayName, false)
        // 设置图标
        val icon = ProviderIconAdapter.getProviderIcon(config.provider)
        if (icon != 0) {
            providerDropdown?.setCompoundDrawablesWithIntrinsicBounds(icon, 0, 0, 0)
        }
        apiKeyInput?.setText(config.apiKey)
        modelInput?.setText(config.model)
        baseUrlInput?.setText(config.baseUrl)
        updateInputVisibility(config.provider)
    }
}