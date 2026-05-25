package com.example.dodroidai.ui.setting

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.RadioButton
import android.widget.RadioGroup
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import androidx.fragment.app.Fragment
import com.example.dodroidai.ui.common.Toolbar
import com.example.dodroidai.DoDroidAIApplication
import com.example.dodroidai.R
import com.example.dodroidai.ai.config.AppConfigManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * 语言设置页面 Fragment，支持简体中文、繁体中文、英文切换
 */
class LanguageSettingFragment : Fragment() {

    private var languageRadioGroup: RadioGroup? = null
    private var radioEnglish: RadioButton? = null
    private var radioChineseSimplified: RadioButton? = null
    private var radioChineseTraditional: RadioButton? = null
    private var toolbar: Toolbar? = null

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return inflater.inflate(R.layout.fragment_language_setting, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        languageRadioGroup = view.findViewById(R.id.languageRadioGroup)
        radioEnglish = view.findViewById(R.id.radioEnglish)
        radioChineseSimplified = view.findViewById(R.id.radioChineseSimplified)
        radioChineseTraditional = view.findViewById(R.id.radioChineseTraditional)
        toolbar = view.findViewById(R.id.toolbar)

        toolbar?.setTitle(R.string.language_title)
        toolbar?.setOnBackClickListener {
            parentFragmentManager.popBackStack()
        }
        toolbar?.setRightVisible(false)
        setupLanguageOptions()
    }

    private fun setupLanguageOptions() {
        languageRadioGroup?.setOnCheckedChangeListener { _, checkedId ->
            val language = when (checkedId) {
                R.id.radioEnglish -> "en"
                R.id.radioChineseSimplified -> "zh-rCN"
                R.id.radioChineseTraditional -> "zh-rTW"
                else -> "en"
            }
            CoroutineScope(Dispatchers.Main).launch {
                AppConfigManager.updateLanguage(language)
                val localeList = LocaleListCompat.forLanguageTags(language)
                AppCompatDelegate.setApplicationLocales(localeList)
                parentFragmentManager.popBackStack()
            }
        }
    }
}