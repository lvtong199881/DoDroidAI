# WebView 滚动联动 Toolbar Alpha

## Context

webview-sdk 已经通过 JS Bridge `WVToolbar` 让 H5 控制原生 Toolbar 的标题、文字色、close 按钮、背景渐变。本次新需求:让 H5 一次性配置 "WebView scrollY → toolbar alpha" 的映射规则,后续 Native 监听 WebView 滚动,按规则线性插值后自动应用 alpha 到 **整个 toolbar(含文字/按钮/背景)**。

典型用法:H5 调 `WVToolbar.setScrollAlphaRule('{"startY":0,"endY":300,"startAlpha":100,"endAlpha":0}')` 后,WebView 滚到顶部时 toolbar 完全不透明、滚到 300dp 时完全透明,中间线性过渡。alpha 协议为 0-100 整型(0 透,100 不透)。

附带提供 `WVToolbar.setAlpha(0..100)` 手动设置和 `WVToolbar.disableScrollAlpha()` 取消联动。

---

## 方案

### 1. `WebToolbar.kt` — 新增 alpha 与交互控制

```kotlin
fun setAlphaPercent(@IntRange(from = 0, to = 100) percent: Int) {
    alpha = percent.coerceIn(0, 100) / 100f
}

/** 当 alpha 极低时禁用点击事件,让触摸穿透回 WebView,避免误触不可见的 back/close */
fun setInteractive(interactive: Boolean) {
    isClickable = interactive
    btnBack.isEnabled = interactive
    btnClose.isEnabled = interactive
    btnRight.isEnabled = interactive
}
```

### 2. `WebFragment.kt` — 控制器 + 滚动监听 + 状态持久化

在同文件内 `internal` 新增:

```kotlin
internal interface ScrollAlphaController {
    fun setRule(startScrollDp: Int, endScrollDp: Int, startAlpha: Int, endAlpha: Int)
    fun setManualAlpha(alpha: Int)   // 内部自动 clearRule,避免下次滚动覆盖
    fun clearRule()                  // 仅清规则,alpha 保持不变
}

private data class AlphaRule(
    val startPx: Int,
    val endPx: Int,
    val startAlpha: Int,
    val endAlpha: Int,
    // 同时记录 dp 原始值,旋转后用于 onSaveInstanceState 重建
    val startDp: Int,
    val endDp: Int
)
```

`WebFragment` 内实现要点:
- `private var alphaRule: AlphaRule? = null`
- `setRule` 内部规范化:`startY > endY` 自动 swap(并 Log.w);alpha 越界 coerceIn(0,100);dp→px 用 `resources.displayMetrics.density`;立即按当前 `webView.scrollY` 应用一次
- `applyAlphaFromScroll(scrollPx: Int)`:`progress = (scrollPx - startPx) / max(1, endPx - startPx)`,coerceIn(0f,1f),alpha = startAlpha + progress*(endAlpha - startAlpha),调 `setAlphaPercent` + `setInteractive(percent > 5)`(阈值 5% 让"基本不可见"的 toolbar 把事件穿透回 WebView)
- `setManualAlpha(a)`:`alphaRule = null` + `setAlphaPercent(a)` + `setInteractive(a > 5)`
- `clearRule()`:仅 `alphaRule = null`,alpha 保持当前值

滚动监听(保存引用以便解绑):
```kotlin
private var scrollListener: View.OnScrollChangeListener? = null
// onViewCreated 中:
scrollListener = View.OnScrollChangeListener { _, _, y, _, _ ->
    applyAlphaFromScroll(y)
}
webView.setOnScrollChangeListener(scrollListener)
```

兜底 apply(WebView 锚点跳转 / 切前后台 不触发 onScrollChange):
```kotlin
// 现有 WebViewClient.onPageFinished 内追加
controller.apply(webView.scrollY)
```

销毁清理(`onDestroyView` 中,在现有 WebView destroy 之前):
```kotlin
webView?.setOnScrollChangeListener(null)
scrollListener = null
```

旋转持久化:
```kotlin
// onSaveInstanceState 存 4 个 int(dp 原始值,而非 px,避免 density 变化导致漂移)
override fun onSaveInstanceState(outState: Bundle) {
    super.onSaveInstanceState(outState)
    alphaRule?.let {
        outState.putInt(KEY_START_DP, it.startDp)
        outState.putInt(KEY_END_DP, it.endDp)
        outState.putInt(KEY_START_ALPHA, it.startAlpha)
        outState.putInt(KEY_END_ALPHA, it.endAlpha)
        outState.putBoolean(KEY_HAS_RULE, true)
    }
}
// onViewCreated 中:if (savedInstanceState?.getBoolean(KEY_HAS_RULE) == true) controller.setRule(...)
```

### 3. `WebToolbarBridge.kt` — Bridge 新增方法

构造改为:
```kotlin
class WebToolbarBridge(
    private val toolbarProvider: WebToolbar?,
    private val scrollAlphaController: ScrollAlphaController?
)
```

新增方法(全部走 `mainHandler.post` 切回主线程,沿用现有模式):

```kotlin
@JavascriptInterface
fun setAlpha(alpha: Int) {
    mainHandler.post { scrollAlphaController?.setManualAlpha(alpha) }
}

@JavascriptInterface
fun setScrollAlphaRule(json: String) {
    try {
        val obj = JSONObject(json)
        // 必填字段缺失则整体忽略
        if (!obj.has("startY") || !obj.has("endY")
            || !obj.has("startAlpha") || !obj.has("endAlpha")) {
            Log.w(TAG, "setScrollAlphaRule missing fields, ignored: $json")
            return
        }
        val sy = obj.getInt("startY")
        val ey = obj.getInt("endY")
        val sa = obj.getInt("startAlpha")
        val ea = obj.getInt("endAlpha")
        mainHandler.post {
            scrollAlphaController?.setRule(sy, ey, sa, ea)
        }
    } catch (e: Exception) {
        Log.w(TAG, "setScrollAlphaRule parse failed: $json", e)
    }
}

@JavascriptInterface
fun disableScrollAlpha() {
    mainHandler.post { scrollAlphaController?.clearRule() }
}
```

保留所有现有方法。`WebFragment` 创建 Bridge 时把 controller 传入。

### 4. `lookaround.html` — Demo 更新

页面内容已足够长可滚动,不再追加。仅追加:

- 页面加载完(`DOMContentLoaded`)主动调一次,启用默认联动:
  ```html
  document.addEventListener('DOMContentLoaded', () => {
      window.WVToolbar.setScrollAlphaRule(JSON.stringify({
          startY: 0, endY: 300, startAlpha: 100, endAlpha: 0
      }));
  });
  ```
- 在右下角 demo 面板加按钮:
  - "启用滚动联动" → setScrollAlphaRule(默认规则)
  - "禁用滚动联动" → disableScrollAlpha
  - "手动 alpha=50" → setAlpha(50)
  - "手动 alpha=100" → setAlpha(100)

### 5. 参数单位约定(写进 KDoc 注释)

Bridge JSON 里的 `startY` / `endY` 单位是 **CSS px(≈ Android dp)**。在 `viewport=device-width` 配置下,H5 写 300 对应"页面滚动 300 CSS px / 300dp 的位置"。Native 内部用 `displayMetrics.density` 把 dp 换算成 device px,再与 `webView.scrollY` 比较。

不支持的场景(写进注释):
- H5 用 `transform: translateY()` 模拟滚动(不会触发 `webView.scrollY` 变化)
- H5 自定义 viewport(非 device-width)导致 CSS px 与 dp 不一致

---

## 关键文件

| 文件 | 修改内容 |
|---|---|
| `/Users/mohanlv/AndroidStudioProjects/DoDroidAI/webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebToolbar.kt` | 新增 `setAlphaPercent`、`setInteractive` |
| `/Users/mohanlv/AndroidStudioProjects/DoDroidAI/webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebFragment.kt` | 新增 `ScrollAlphaController` 接口/实现/`AlphaRule` 数据类/滚动监听/`onPageFinished` 兜底/`onSaveInstanceState` 持久化/`onDestroyView` 清理 |
| `/Users/mohanlv/AndroidStudioProjects/DoDroidAI/webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebToolbarBridge.kt` | 构造增加 `scrollAlphaController` 参数;新增 `setAlpha`/`setScrollAlphaRule`/`disableScrollAlpha` 三个 `@JavascriptInterface` |
| `/Users/mohanlv/AndroidStudioProjects/DoDroidAI/webview-sdk/src/main/assets/wv/lookaround.html` | 加 DOMContentLoaded 初始化、加 4 个 demo 按钮(内容长度不变) |

不修改 `wv_view_toolbar.xml`/`wv_fragment.xml`/字符串资源/`WebViewEntry.kt`/`build.gradle.kts`。

---

## 复用的现有能力

- `Handler(Looper.getMainLooper())`(Bridge 现有字段)→ 沿用切主线程
- `WebToolbar` 现有 `btnBack/btnClose/btnRight` 字段 → `setInteractive` 直接 setEnabled
- 现有 `WebViewClient.onPageFinished` 钩子 → 直接追加兜底 apply
- 现有 `mainHandler.post + try/catch + Log.w/e` 模式 → 新方法沿用

---

## 验证步骤

1. **编译**:`./gradlew :webview-sdk:assembleDebug` 通过(不允许新增依赖)
2. **装到手机**:`./gradlew :app:installDebug` 后启动 app,点 "去看看" 进入 WebFragment
3. **核心场景**:
   - 加载后 toolbar 完全不透明(alpha=100)
   - 向下慢滑 → toolbar 逐渐变透
   - 滑过 300dp 后 toolbar 完全透明,**点击 toolbar 区域应能触发下方 H5 的元素**(穿透生效)
   - 滑回顶部 → toolbar 恢复完全不透明,back/close 可点
4. **手动模式**:
   - 点 "手动 alpha=50" → toolbar 立即半透明,继续滚动 toolbar **不再变化**(规则已被清)
   - 点 "启用滚动联动" → 重新进入滚动联动
   - 点 "禁用滚动联动" → 当前 alpha 保持不变,继续滚动 toolbar 不再变化
5. **旋转**:横竖屏切换后,持久化的规则继续生效(toolbar 跟随滚动变 alpha)
6. **销毁**:按返回键退出 WebFragment,无 logcat 报错(setOnScrollChangeListener(null) 已解绑)
7. **容错**:H5 console 里手动调:
   - `WVToolbar.setScrollAlphaRule("{}")` → logcat 出现 `missing fields` Warning,toolbar 不变
   - `WVToolbar.setScrollAlphaRule("not json")` → logcat 出现 `parse failed` Warning,toolbar 不变
   - `WVToolbar.setScrollAlphaRule('{"startY":300,"endY":0,"startAlpha":100,"endAlpha":0}')` → 自动 swap 仍然工作

---

## 后续 TODO(不在本次范围)

- ProgressBar 与 toolbar alpha 同步(避免加载中半透 toolbar 配合不透明 ProgressBar 的违和感)
- alpha 变化加 ValueAnimator 平滑过渡(仅当实测出现闪烁时再加)
