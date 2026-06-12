package com.example.dodroidai.webviewsdk

import android.graphics.Bitmap
import android.graphics.Color
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.ViewParent
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.ProgressBar
import androidx.activity.OnBackPressedCallback
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.fragment.app.Fragment

/**
 * 内嵌 WebView 的 Fragment,顶部带 WebToolbar 与加载进度条。
 *
 * 仅 WebFragment 进入 edge-to-edge:在 onViewCreated 临时把 Window
 * 切到 decorFitsSystemWindows=false,statusBarColor 置透明,
 * 并把祖先 View 的 fitsSystemWindows 关掉、清掉 top padding,
 * 让 WebView 真正延伸到状态栏区域(状态栏看到的是 WebView 内容)。
 * toolbar 通过 WindowInsets 设置 topMargin(而非 padding),
 * 让整个 toolbar 推到状态栏下方,toolbar 背景不会盖住状态栏。
 * onDestroyView 把这些改动全部还原,避免影响宿主 Activity 其他 Fragment。
 *
 * back 事件优先 WebView.goBack(),不能 back 才交给上层 popBackStack。
 */
class WebFragment : Fragment() {

    private var webView: WebView? = null
    private var webToolbar: WebToolbar? = null
    private var progressBar: ProgressBar? = null

    /**
     * 记录在 onViewCreated 时被关掉 fitsSystemWindows 的祖先 View,
     * onDestroyView 按相反顺序恢复,确保 WebFragment 退出后宿主行为不变。
     */
    private val parentsWithFits = mutableListOf<View>()

    /**
     * 记录进入 WebFragment 前 Window 的 statusBarColor,onDestroyView 时还原。
     */
    private var savedStatusBarColor: Int = Color.TRANSPARENT

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return inflater.inflate(R.layout.wv_fragment, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        webToolbar = view.findViewById(R.id.wvToolbar)
        webView = view.findViewById(R.id.wvWebView)
        progressBar = view.findViewById(R.id.wvProgressBar)

        enableEdgeToEdge(view)

        webToolbar?.setTitle(R.string.wv_title)
        // 默认:back = WebView.goBack,close = popBackStack
        webToolbar?.setOnBackClickListener {
            val wv = webView ?: return@setOnBackClickListener
            if (wv.canGoBack()) {
                wv.goBack()
            }
        }
        webToolbar?.setOnCloseClickListener {
            parentFragmentManager.popBackStack()
        }
        // TODO BY @author: 右侧 icon 由 webview 自定义事件触发
        webToolbar?.setRightVisible(false)

        val current = webView ?: return
        with(current.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            useWideViewPort = true
            loadWithOverviewMode = true
        }

        current.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                if (url != null) {
                    view?.loadUrl(url)
                }
                return true
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                webToolbar?.setBackEnabled(view?.canGoBack() == true)
            }

            override fun doUpdateVisitedHistory(view: WebView?, url: String?, isReload: Boolean) {
                super.doUpdateVisitedHistory(view, url, isReload)
                webToolbar?.setBackEnabled(view?.canGoBack() == true)
            }
        }

        current.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                progressBar?.progress = newProgress
                if (newProgress >= 100) {
                    progressBar?.visibility = View.GONE
                } else {
                    progressBar?.visibility = View.VISIBLE
                }
            }
        }

        val url = arguments?.getString(ARG_URL) ?: DEFAULT_URL
        // 注册 JS Bridge 必须在 loadUrl 之前,首屏页面才能拿到 window.WVToolbar
        val bridge = WebToolbarBridge(webToolbar)
        current.addJavascriptInterface(bridge, BRIDGE_NAME)
        current.loadUrl(url)
        webToolbar?.setBackEnabled(false)

        // 系统 back 事件:优先 goBack,不能 back 才交给上层
        requireActivity().onBackPressedDispatcher.addCallback(
            viewLifecycleOwner,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    val wv = webView
                    if (wv != null && wv.canGoBack()) {
                        wv.goBack()
                    } else {
                        isEnabled = false
                        requireActivity().onBackPressedDispatcher.onBackPressed()
                    }
                }
            }
        )
    }

    /**
     * 让 WebFragment 进入 edge-to-edge 模式:
     * 1. Window decorFitsSystemWindows = false,允许 content 绘制到 system bars 下方;
     *    同时把 statusBarColor 设成透明,WebView 内容可以透过状态栏
     * 2. 向上遍历祖先,关掉 fitsSystemWindows 并清掉 top padding,
     *    避免父布局自己消费 status bar inset
     * 3. toolbar 通过 WindowInsets 把 topMargin 设成状态栏高度
     *    (用 margin 而不是 padding,这样 toolbar 整体被推到状态栏下方,
     *    其背景色不会覆盖状态栏区域)
     */
    @Suppress("DEPRECATION")
    private fun enableEdgeToEdge(rootView: View) {
        val activity = activity ?: return
        val window = activity.window
        WindowCompat.setDecorFitsSystemWindows(window, false)
        savedStatusBarColor = window.statusBarColor
        window.statusBarColor = Color.TRANSPARENT

        var current: ViewParent? = rootView.parent
        while (current != null) {
            val v = current as? View ?: break
            if (v.fitsSystemWindows) {
                v.fitsSystemWindows = false
                v.setPadding(v.paddingLeft, 0, v.paddingRight, v.paddingBottom)
                parentsWithFits.add(v)
            }
            current = current.parent
        }

        val toolbar = webToolbar ?: return
        // 直接读系统的 status_bar_height,立即生效,避免 inset 派发链
        // 被中间某层(如 DrawerLayout 内部逻辑)消费导致 listener 收到 0
        val statusBarHeight = getStatusBarHeight()
        val lp = toolbar.layoutParams
        if (lp is ViewGroup.MarginLayoutParams && lp.topMargin != statusBarHeight) {
            lp.topMargin = statusBarHeight
            toolbar.layoutParams = lp
        }
        // 兜底:监听 inset 变化(横竖屏切换、刘海等场景)
        ViewCompat.setOnApplyWindowInsetsListener(toolbar) { v, insets ->
            val top = insets.getInsets(WindowInsetsCompat.Type.systemBars()).top
            val l = v.layoutParams
            if (l is ViewGroup.MarginLayoutParams && top > 0 && l.topMargin != top) {
                l.topMargin = top
                v.layoutParams = l
            }
            insets
        }
        ViewCompat.requestApplyInsets(rootView)
    }

    /**
     * 从系统资源读 status bar 高度,minSdk 24 以上 status_bar_height 一直可用。
     * 这是最可靠的获取方式,不受 WindowInsets 派发时机和中间层消费的影响。
     */
    @Suppress("DiscouragedApi", "InternalInsetResource")
    private fun getStatusBarHeight(): Int {
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resourceId > 0) {
            resources.getDimensionPixelSize(resourceId)
        } else {
            0
        }
    }

    /**
     * 还原宿主 Activity 的 edge-to-edge 状态,把 onViewCreated 时改动的祖先 View、
     * Window decor 与 statusBarColor 全部恢复,避免 WebFragment 影响其他 Fragment。
     */
    @Suppress("DEPRECATION")
    private fun restoreEdgeToEdge() {
        val act = activity
        if (act != null) {
            WindowCompat.setDecorFitsSystemWindows(act.window, true)
            act.window.statusBarColor = savedStatusBarColor
        }
        parentsWithFits.forEach { v ->
            v.fitsSystemWindows = true
            ViewCompat.requestApplyInsets(v)
        }
        parentsWithFits.clear()

        webToolbar?.let { ViewCompat.setOnApplyWindowInsetsListener(it, null) }
    }

    override fun onDestroyView() {
        restoreEdgeToEdge()
        webView?.let { wv ->
            wv.stopLoading()
            wv.loadUrl("about:blank")
            wv.destroy()
        }
        webView = null
        webToolbar = null
        progressBar = null
        super.onDestroyView()
    }

    companion object {
        const val ARG_URL = "url"
        const val BRIDGE_NAME = "WVToolbar"

        private const val DEFAULT_URL = "file:///android_asset/wv/lookaround.html"

        fun newInstance(url: String = DEFAULT_URL): WebFragment {
            return WebFragment().apply {
                arguments = Bundle().apply {
                    putString(ARG_URL, url)
                }
            }
        }
    }
}
