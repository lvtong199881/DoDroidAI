package com.example.dodroidai.ui.setting

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.AutoCompleteTextView
import android.widget.Button
import android.widget.ImageView
import android.widget.ScrollView
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.example.dodroidai.DoDroidAIApplication
import com.example.dodroidai.R
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ApiFormat
import com.example.dodroidai.ui.common.Toolbar
import com.google.android.material.card.MaterialCardView
import com.google.android.material.textfield.TextInputEditText
import kotlinx.coroutines.launch

/**
 * AI 配置页面 Fragment
 */
class AIConfigFragment : Fragment() {

    private var viewModel: AIConfigViewModel? = null

    private var providerNameInput: TextInputEditText? = null
    private var descriptionInput: TextInputEditText? = null
    private var officialUrlInput: TextInputEditText? = null
    private var apiKeyInput: TextInputEditText? = null
    private var baseUrlInput: TextInputEditText? = null
    private var apiFormatDropdown: AutoCompleteTextView? = null
    private var mainModelInput: TextInputEditText? = null
    private var haikuModelInput: TextInputEditText? = null
    private var sonnetModelInput: TextInputEditText? = null
    private var opusModelInput: TextInputEditText? = null
    private var saveButton: Button? = null
    private var toolbar: Toolbar? = null
    private var scrollView: ScrollView? = null

    private var cardOpenAI: MaterialCardView? = null
    private var cardDeepSeek: MaterialCardView? = null
    private var cardMiniMax: MaterialCardView? = null

    private var currentApiFormat: ApiFormat = ApiFormat.ANTHROPIC_MESSAGES

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
        initViews(view)
        setupToolbar()
        setupApiFormatDropdown()
        setupQuickProviderCards()
        setupSaveButton()
        observeConfig()
    }

    private fun initViews(view: View) {
        toolbar = view.findViewById(R.id.toolbar)
        scrollView = view.findViewById(R.id.scrollView)
        providerNameInput = view.findViewById(R.id.providerNameInput)
        descriptionInput = view.findViewById(R.id.descriptionInput)
        officialUrlInput = view.findViewById(R.id.officialUrlInput)
        apiKeyInput = view.findViewById(R.id.apiKeyInput)
        baseUrlInput = view.findViewById(R.id.baseUrlInput)
        apiFormatDropdown = view.findViewById(R.id.apiFormatDropdown)
        mainModelInput = view.findViewById(R.id.mainModelInput)
        haikuModelInput = view.findViewById(R.id.haikuModelInput)
        sonnetModelInput = view.findViewById(R.id.sonnetModelInput)
        opusModelInput = view.findViewById(R.id.opusModelInput)
        saveButton = view.findViewById(R.id.saveButton)
        cardOpenAI = view.findViewById(R.id.cardOpenAI)
        cardDeepSeek = view.findViewById(R.id.cardDeepSeek)
        cardMiniMax = view.findViewById(R.id.cardMiniMax)
    }

    private fun setupToolbar() {
        toolbar?.setTitle(R.string.ai_config_title)
        toolbar?.setOnBackClickListener {
            parentFragmentManager.popBackStack()
        }
        toolbar?.setRightVisible(false)
    }

    private fun setupApiFormatDropdown() {
        apiFormatDropdown?.setText(getApiFormatDisplayName(ApiFormat.ANTHROPIC_MESSAGES), false)
    }

    private fun getApiFormatDisplayName(format: ApiFormat): String {
        return getString(R.string.api_format_anthropic)
    }

    private fun setupQuickProviderCards() {
        cardOpenAI?.setOnClickListener { applyDefaultConfig(AIProvider.OPENAI) }
        cardDeepSeek?.setOnClickListener { applyDefaultConfig(AIProvider.DEEPSEEK) }
        cardMiniMax?.setOnClickListener { applyDefaultConfig(AIProvider.MINIMAX) }
    }

    private fun applyDefaultConfig(provider: AIProvider) {
        val defaultConfig = AIConfig.default(provider)
        clearAllInputs()
        apiKeyInput?.setText(defaultConfig.apiKey)
        baseUrlInput?.setText(defaultConfig.baseUrl)
        mainModelInput?.setText(defaultConfig.mainModel)
        haikuModelInput?.setText(defaultConfig.haikuModel)
        sonnetModelInput?.setText(defaultConfig.sonnetModel)
        opusModelInput?.setText(defaultConfig.opusModel)
        providerNameInput?.setText(defaultConfig.providerName)
        currentApiFormat = defaultConfig.apiFormat
        apiFormatDropdown?.setText(getApiFormatDisplayName(defaultConfig.apiFormat), false)
        scrollView?.scrollTo(0, 0)
    }

    private fun clearAllInputs() {
        providerNameInput?.text?.clear()
        descriptionInput?.text?.clear()
        officialUrlInput?.text?.clear()
        apiKeyInput?.text?.clear()
        baseUrlInput?.text?.clear()
        mainModelInput?.text?.clear()
        haikuModelInput?.text?.clear()
        sonnetModelInput?.text?.clear()
        opusModelInput?.text?.clear()
    }

    private fun setupSaveButton() {
        saveButton?.setOnClickListener {
            if (!validateInputs()) {
                return@setOnClickListener
            }
            saveConfig()
        }
    }

    private fun validateInputs(): Boolean {
        val providerName = providerNameInput?.text.toString().trim()
        val apiKey = apiKeyInput?.text.toString().trim()
        val baseUrl = baseUrlInput?.text.toString().trim()
        val mainModel = mainModelInput?.text.toString().trim()
        val haikuModel = haikuModelInput?.text.toString().trim()
        val sonnetModel = sonnetModelInput?.text.toString().trim()
        val opusModel = opusModelInput?.text.toString().trim()

        val missingFields = mutableListOf<String>()
        if (providerName.isEmpty()) missingFields.add(getString(R.string.ai_provider_name))
        if (apiKey.isEmpty()) missingFields.add(getString(R.string.ai_api_key))
        if (baseUrl.isEmpty()) missingFields.add(getString(R.string.ai_base_url))
        if (mainModel.isEmpty()) missingFields.add(getString(R.string.ai_main_model))
        if (haikuModel.isEmpty()) missingFields.add(getString(R.string.ai_haiku_model))
        if (sonnetModel.isEmpty()) missingFields.add(getString(R.string.ai_sonnet_model))
        if (opusModel.isEmpty()) missingFields.add(getString(R.string.ai_opus_model))

        if (missingFields.isNotEmpty()) {
            Toast.makeText(
                context,
                getString(R.string.error_fields_required, missingFields.joinToString("、")),
                Toast.LENGTH_SHORT
            ).show()
            return false
        }
        return true
    }

    private fun saveConfig() {
        val provider = AIProvider.valueOf(providerNameInput?.text.toString().trim().uppercase())
        val newConfig = AIConfig(
            provider = provider,
            apiKey = apiKeyInput?.text.toString().trim(),
            baseUrl = baseUrlInput?.text.toString().trim(),
            model = mainModelInput?.text.toString().trim(),
            providerName = providerNameInput?.text.toString().trim(),
            description = descriptionInput?.text.toString().trim(),
            officialUrl = officialUrlInput?.text.toString().trim(),
            apiFormat = currentApiFormat,
            mainModel = mainModelInput?.text.toString().trim(),
            haikuModel = haikuModelInput?.text.toString().trim(),
            sonnetModel = sonnetModelInput?.text.toString().trim(),
            opusModel = opusModelInput?.text.toString().trim()
        )
        android.util.Log.d("AIConfigFragment", "Saving config: provider=${newConfig.provider}, baseUrl=${newConfig.baseUrl}, model=${newConfig.model}, apiKey=${newConfig.apiKey.take(10)}...")
        viewModel?.updateConfig(newConfig)
        Toast.makeText(context, R.string.save_success, Toast.LENGTH_SHORT).show()
        parentFragmentManager.popBackStack()
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
        providerNameInput?.setText(config.providerName)
        descriptionInput?.setText(config.description)
        officialUrlInput?.setText(config.officialUrl)
        apiKeyInput?.setText(config.apiKey)
        baseUrlInput?.setText(config.baseUrl)
        mainModelInput?.setText(config.mainModel)
        haikuModelInput?.setText(config.haikuModel)
        sonnetModelInput?.setText(config.sonnetModel)
        opusModelInput?.setText(config.opusModel)
        currentApiFormat = config.apiFormat
        apiFormatDropdown?.setText(getApiFormatDisplayName(config.apiFormat), false)
    }
}
