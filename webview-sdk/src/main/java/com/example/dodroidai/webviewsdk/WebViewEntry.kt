package com.example.dodroidai.webviewsdk

import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager

/**
 * webview-sdk 公开入口,app 通过此 API 显示 WebFragment。
 *
 * 使用时需传入 Activity(或 FragmentManager)和容器 View 的 id,
 * webview-sdk 不硬编码 app 的容器 id,保证可移植性。
 */
object WebViewEntry {
    private const val DEFAULT_URL = "https://www.baidu.com"
    private const val TAG = "WebFragment"

    @JvmStatic
    fun show(activity: FragmentActivity, containerId: Int, url: String = DEFAULT_URL) {
        show(activity.supportFragmentManager, containerId, url)
    }

    @JvmStatic
    fun show(manager: FragmentManager, containerId: Int, url: String = DEFAULT_URL) {
        manager.beginTransaction()
            .add(containerId, WebFragment.newInstance(url), TAG)
            .addToBackStack(TAG)
            .commit()
    }
}
