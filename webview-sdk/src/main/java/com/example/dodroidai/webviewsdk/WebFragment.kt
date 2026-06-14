package com.example.dodroidai.webviewsdk

import android.graphics.Bitmap
import android.graphics.Color
import android.os.Bundle
import android.util.Log
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
 * WebView 滚动 → toolbar alpha 联动控制器。
 *
 * H5 通过 [WebToolbarBridge] 配置规则,Native 端在 WebView 滚动时
 * 按规则线性插值并应用 alpha 到整个 toolbar(含文字/按钮/背景)。
 */
internal interface ScrollAlphaController {
    /**
     * 启用滚动联动。
     *
     * [startScrollDp] / [endScrollDp] 单位是 dp(≈ CSS px,在 viewport=device-width 时一致),
     * Native 用 displayMetrics.density 换算成 device px,与 WebView.scrollY 比较。
     * 如果 [startScrollDp] > [endScrollDp] 内部自动 swap 并同步 swap 两端 alpha。
     * alpha 范围 0-100,越界会被 coerce 到 [0, 100]。
     * 调用后立即按当前 webView.scrollY 应用一次。
     */
    fun setRule(startScrollDp: Int, endScrollDp: Int, startAlpha: Int, endAlpha: Int)

    /**
     * 手动设置 alpha(0-100)。内部自动 [clearRule],避免下次滚动覆盖手动值。
     */
    fun setManualAlpha(alpha: Int)

    /**
     * 仅清掉规则,toolbar 当前 alpha 保持不变。
     * 若要恢复完全不透明,再调 [setManualAlpha](100)。
     */
    fun clearRule()
}

/**
 * 滚动联动规则。
 * - [startPx] / [endPx] 是 device px 缓存,运行时用来与 webView.scrollY 比较
 * - [startDp] / [endDp] 是原始 dp 值,只用于 onSaveInstanceState 持久化
 *   (旋转/重建后 density 不变,但直接存 dp 更直观,避免 px 反算)
 */
private data class AlphaRule(
    val startPx: Int,
    val endPx: Int,
    val startAlpha: Int,
    val endAlpha: Int,
    val startDp: Int,
    val endDp: Int
)

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

    /** 当前滚动联动规则,null 表示已禁用。 */
    private var alphaRule: AlphaRule? = null

    /** 保存监听器引用,onDestroyView 时显式置 null 解绑,避免 WebView 销毁过程中回调触发 NPE。 */
    private var scrollListener: View.OnScrollChangeListener? = null

    /**
     * 给 Bridge 用的滚动联动控制器实现。
     * Bridge 所有方法已经在主线程 post 后再调本对象,这里方法体不再做线程切换。
     */
    private val scrollAlphaController: ScrollAlphaController = object : ScrollAlphaController {
        override fun setRule(
            startScrollDp: Int,
            endScrollDp: Int,
            startAlpha: Int,
            endAlpha: Int
        ) {
            var sy = startScrollDp
            var ey = endScrollDp
            var sa = startAlpha.coerceIn(0, 100)
            var ea = endAlpha.coerceIn(0, 100)
            // start > end 时自动 swap,同步 swap 两端 alpha,保证语义"滚到更深位置时 alpha 是另一端"
            if (sy > ey) {
                Log.w(TAG, "setRule swap: startY=$sy > endY=$ey")
                val tmpY = sy
                sy = ey
                ey = tmpY
                val tmpA = sa
                sa = ea
                ea = tmpA
            }
            val density = resources.displayMetrics.density
            alphaRule = AlphaRule(
                startPx = (sy * density).toInt(),
                endPx = (ey * density).toInt(),
                startAlpha = sa,
                endAlpha = ea,
                startDp = sy,
                endDp = ey
            )
            // 设规则后立即按当前 scrollY 应用一次,避免规则与显示状态不一致
            applyAlphaFromScroll(webView?.scrollY ?: 0)
        }

        override fun setManualAlpha(alpha: Int) {
            val clamped = alpha.coerceIn(0, 100)
            // 手动设置时清掉规则,避免下次滚动覆盖手动值
            alphaRule = null
            webToolbar?.setAlphaPercent(clamped)
            webToolbar?.setInteractive(clamped > ALPHA_INTERACTIVE_THRESHOLD)
        }

        override fun clearRule() {
            // 仅清规则,toolbar 当前 alpha 保持不变(H5 想恢复就再调 setAlpha(100))
            alphaRule = null
        }
    }

    /**
     * 按当前 scrollY 与 [alphaRule] 计算 alpha 并应用到 toolbar。
     * 没有规则时直接返回,避免滚动事件做无用计算。
     */
    private fun applyAlphaFromScroll(scrollPx: Int) {
        val rule = alphaRule ?: return
        val toolbar = webToolbar ?: return
        val percent = computeAlpha(scrollPx = scrollPx, rule = rule)
        toolbar.setAlphaPercent(percent)
        toolbar.setInteractive(percent > ALPHA_INTERACTIVE_THRESHOLD)
    }

    /**
     * 线性插值。span 用 coerceAtLeast(1) 防止 start==end 时除零。
     * coerceIn 把 progress 截到 [0,1],scrollY 在区间外时取对应端点 alpha。
     */
    private fun computeAlpha(scrollPx: Int, rule: AlphaRule): Int {
        val span = (rule.endPx - rule.startPx).coerceAtLeast(1)
        val progress = ((scrollPx - rule.startPx).toFloat() / span).coerceIn(0f, 1f)
        val alpha = rule.startAlpha + progress * (rule.endAlpha - rule.startAlpha)
        return alpha.toInt().coerceIn(0, 100)
    }

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

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                // 兜底:锚点跳转、切前后台等场景 onScrollChange 不一定触发,
                // 这里在页面就绪时按当前 scrollY 应用一次,避免 H5 调 setScrollAlphaRule
                // 后 toolbar 还停留在旧 alpha
                applyAlphaFromScroll(view?.scrollY ?: 0)
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
        val bridge = WebToolbarBridge(
            toolbarProvider = webToolbar,
            scrollAlphaController = scrollAlphaController
        )
        current.addJavascriptInterface(bridge, BRIDGE_NAME)

        // 监听 WebView 滚动,联动 toolbar alpha。
        // 保存 listener 引用以便 onDestroyView 显式解绑,避免回调持有 fragment 引用导致泄漏。
        val listener = View.OnScrollChangeListener { _, _, y, _, _ ->
            applyAlphaFromScroll(y)
        }
        scrollListener = listener
        current.setOnScrollChangeListener(listener)

        current.loadUrl(url)
        webToolbar?.setBackEnabled(false)

        // 旋转/重建后从 savedInstanceState 恢复滚动联动规则,避免 H5 重复 setScrollAlphaRule。
        // 这里调 controller 而不是直接写 alphaRule,以便 density 变化(虽然旋转 density 不变)
        // 也能用最新的 displayMetrics 重算 px。
        if (savedInstanceState?.getBoolean(KEY_HAS_ALPHA_RULE) == true) {
            scrollAlphaController.setRule(
                startScrollDp = savedInstanceState.getInt(KEY_ALPHA_START_DP),
                endScrollDp = savedInstanceState.getInt(KEY_ALPHA_END_DP),
                startAlpha = savedInstanceState.getInt(KEY_ALPHA_START),
                endAlpha = savedInstanceState.getInt(KEY_ALPHA_END)
            )
        }

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

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        // 持久化滚动联动规则。存原始 dp 值而非 px,旋转后用最新 density 重算更直观,
        // 避免 px 反算的精度损失
        alphaRule?.let { rule ->
            outState.putBoolean(KEY_HAS_ALPHA_RULE, true)
            outState.putInt(KEY_ALPHA_START_DP, rule.startDp)
            outState.putInt(KEY_ALPHA_END_DP, rule.endDp)
            outState.putInt(KEY_ALPHA_START, rule.startAlpha)
            outState.putInt(KEY_ALPHA_END, rule.endAlpha)
        }
    }

    override fun onDestroyView() {
        restoreEdgeToEdge()
        // 先解绑滚动监听,再 destroy WebView,避免 destroy 过程中触发的回调
        // 访问已经置 null 的 webToolbar
        webView?.setOnScrollChangeListener(null)
        scrollListener = null
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
        private const val TAG = "WebFragment"

        // alpha 低于此百分比阈值时,toolbar 视觉上"基本看不见",
        // 禁用点击让触摸穿透回下方 WebView,避免误触不可见的 back/close
        private const val ALPHA_INTERACTIVE_THRESHOLD = 5

        // onSaveInstanceState 持久化 key
        private const val KEY_HAS_ALPHA_RULE = "wv_has_alpha_rule"
        private const val KEY_ALPHA_START_DP = "wv_alpha_start_dp"
        private const val KEY_ALPHA_END_DP = "wv_alpha_end_dp"
        private const val KEY_ALPHA_START = "wv_alpha_start"
        private const val KEY_ALPHA_END = "wv_alpha_end"

        fun newInstance(url: String = DEFAULT_URL): WebFragment {
            return WebFragment().apply {
                arguments = Bundle().apply {
                    putString(ARG_URL, url)
                }
            }
        }
    }
}
