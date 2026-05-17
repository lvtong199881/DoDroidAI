package com.example.dodroidai.ui.setting

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ScrollView
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.example.dodroidai.DoDroidAIApplication
import com.example.dodroidai.R
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.config.AppConfigManager
import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ui.common.SettingsItemView
import com.example.dodroidai.ui.common.Toolbar
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * 设置页面 Fragment，显示 AI 配置和语言设置入口
 */
class SettingsFragment : Fragment() {

    private var viewModel: SettingsViewModel? = null
    private var configManager: AppConfigManager? = null

    private var aiConfigCard: SettingsItemView? = null
    private var languageConfigCard: SettingsItemView? = null
    private var appearanceConfigCard: SettingsItemView? = null
    private var aboutCard: SettingsItemView? = null
    private var toolbar: Toolbar? = null
    private var scrollView: ScrollView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        viewModel = SettingsViewModel(DoDroidAIApplication.instance.configManager)
        configManager = AppConfigManager(DoDroidAIApplication.instance)
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return inflater.inflate(R.layout.fragment_settings, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        aiConfigCard = view.findViewById(R.id.aiConfigCard)
        languageConfigCard = view.findViewById(R.id.languageConfigCard)
        appearanceConfigCard = view.findViewById(R.id.appearanceConfigCard)
        aboutCard = view.findViewById(R.id.aboutCard)
        toolbar = view.findViewById(R.id.toolbar)
        scrollView = view.findViewById(R.id.scrollView)

        aiConfigCard?.setTitle(R.string.ai_config_title)
        languageConfigCard?.setTitle(R.string.language_title)
        appearanceConfigCard?.setTitle(R.string.appearance_title)
        aboutCard?.setTitle(R.string.about_title)

        toolbar?.setTitle(R.string.settings_title)
        toolbar?.setOnBackClickListener {
            parentFragmentManager.popBackStack()
        }
        toolbar?.setRightVisible(false)

        setupClickListeners()
        setupScrollListener()
        observeConfig()
        observeLanguage()
        observeTheme()
    }

    private fun setupScrollListener() {
        scrollView?.setOnScrollChangeListener { _, _, scrollY, _, _ ->
            toolbar?.setDividerVisible(scrollY > 0)
        }
    }

    private fun setupClickListeners() {
        aiConfigCard?.setOnItemClickListener {
            parentFragmentManager.beginTransaction()
                .replace(R.id.fragment_container, AIConfigFragment())
                .addToBackStack(null)
                .commit()
        }

        languageConfigCard?.setOnItemClickListener {
            parentFragmentManager.beginTransaction()
                .replace(R.id.fragment_container, LanguageSettingFragment())
                .addToBackStack(null)
                .commit()
        }

        appearanceConfigCard?.setOnItemClickListener {
            showThemeDialog()
        }

        aboutCard?.setOnItemClickListener {
            parentFragmentManager.beginTransaction()
                .replace(R.id.fragment_container, AboutFragment())
                .addToBackStack(null)
                .commit()
        }
    }

    private fun showThemeDialog() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_theme_setting, null)
        val radioGroup = dialogView.findViewById<android.widget.RadioGroup>(R.id.themeRadioGroup)

        val currentTheme = runCatching {
            kotlinx.coroutines.runBlocking { configManager?.themeFlow?.first() }
        }.getOrDefault(AppConfigManager.THEME_SYSTEM)

        when (currentTheme) {
            AppConfigManager.THEME_LIGHT -> radioGroup.check(R.id.radioLight)
            AppConfigManager.THEME_DARK -> radioGroup.check(R.id.radioDark)
            else -> radioGroup.check(R.id.radioSystem)
        }

        AlertDialog.Builder(requireContext())
            .setTitle(R.string.appearance_title)
            .setView(dialogView)
            .setPositiveButton(R.string.save) { _, _ ->
                val theme = when (radioGroup.checkedRadioButtonId) {
                    R.id.radioLight -> AppConfigManager.THEME_LIGHT
                    R.id.radioDark -> AppConfigManager.THEME_DARK
                    else -> AppConfigManager.THEME_SYSTEM
                }
                lifecycleScope.launch {
                    configManager?.updateTheme(theme)
                    applyTheme(theme)
                    activity?.recreate()
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun applyTheme(theme: String) {
        val mode = when (theme) {
            AppConfigManager.THEME_LIGHT -> androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_NO
            AppConfigManager.THEME_DARK -> androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_YES
            else -> androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
        }
        androidx.appcompat.app.AppCompatDelegate.setDefaultNightMode(mode)
    }

    private fun observeConfig() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel?.config?.collect { config ->
                    updateAIConfigUI(config)
                }
            }
        }
    }

    private fun observeLanguage() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                configManager?.languageFlow?.collect { language ->
                    updateLanguageUI(language)
                }
            }
        }
    }

    private fun observeTheme() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                configManager?.themeFlow?.collect { theme ->
                    updateThemeUI(theme)
                    applyTheme(theme)
                }
            }
        }
    }

    private fun updateAIConfigUI(config: AIConfig) {
        val providerText = when (config.provider) {
            AIProvider.OPENAI -> getString(R.string.provider_openai)
            AIProvider.DEEPSEEK -> getString(R.string.provider_deepseek)
            AIProvider.MINIMAX -> getString(R.string.provider_minimax)
            AIProvider.CUSTOM -> getString(R.string.provider_custom)
        }
        aiConfigCard?.setValue(if (config.apiKey.isNotEmpty()) {
            providerText
        } else {
            getString(R.string.not_configured)
        })
    }

    private fun updateLanguageUI(language: String) {
        val text = when (language) {
            "zh-rCN" -> getString(R.string.language_chinese_simplified)
            "zh-rTW" -> getString(R.string.language_chinese_traditional)
            else -> getString(R.string.language_english)
        }
        languageConfigCard?.setValue(text)
    }

    private fun updateThemeUI(theme: String) {
        val text = when (theme) {
            AppConfigManager.THEME_LIGHT -> getString(R.string.theme_light)
            AppConfigManager.THEME_DARK -> getString(R.string.theme_dark)
            else -> getString(R.string.theme_system)
        }
        appearanceConfigCard?.setValue(text)
    }
}