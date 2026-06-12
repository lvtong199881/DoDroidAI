# WebView JS Bridge:H5 控制原生 Toolbar

## Context

当前 `webview-sdk` 的 `WebFragment` + `WebToolbar` 完全由原生侧控制,H5 页面只能被动展示。需要让 H5 页面通过 JS Bridge 主动控制原生的 toolbar:

1. **title 文案**:H5 动态更新标题文字
2. **title 颜色**:H5 设置标题文字颜色(hex)
3. **close 显隐**:H5 控制左侧 close 按钮是否显示
4. **toolbar 渐变背景**:H5 设置整个 toolbar 的渐变色与渐变方向

目标:保持 `webview-sdk` 单向解耦(app 仍只通过 `WebViewEntry.show()` 入口调用),H5 调用 `window.WVToolbar.xxx()` 即可生效。

## 设计决策

### Bridge 名称:`WVToolbar`

- **具体而非通用**:命名为 `WVToolbar`(WebView Toolbar 的缩写),体现 SDK 命名空间隔离。
- 与未来可能新增的 `WVNavigator`、`WVPage` 等桥接对象保持命名一致。

### API 形态:4 个 `@JavascriptInterface` 方法

```javascript
window.WVToolbar.setTitle("新标题");
window.WVToolbar.setTitleColor("#FF5722");
window.WVToolbar.setCloseVisible(false);
window.WVToolbar.setBackgroundGradient('{"colors":["#FF0000","#0000FF"],"direction":"90deg"}');
```

**为什么用字符串参数而非 JS 对象**:Android `addJavascriptInterface` 暴露的方法签名只支持基本类型 + String,JS 对象在原生侧会被自动转换,处理反而麻烦;统一用 JSON 字符串,Android 侧用 `org.json.JSONObject` 解析(框架内置,零依赖)。

### JSON 协议:`{"colors":[...],"direction":N}`

```json
{
  "colors": ["#FF0000", "#0000FF"],
  "direction": 2
}
```

- **colors**:**非必填**,hex 字符串数组,数量不限
  - 缺失 / 空数组 `[]` / 字段为 `null` = **恢复默认背景**
  - 只有 1 个元素 = 原生复制成 2 个相同色(`["#FF0000"]` 等同于 `["#FF0000","#FF0000"]`)
  - ≥ 2 个元素 = 直接用作渐变色
- **direction**:**非必填**,整数 0~7,直接对应 `GradientDrawable.Orientation` 全部 8 个枚举值(按 enum 顺序)
  - `0` = `TOP_BOTTOM`(从上到下)
  - `1` = `TR_BL`(从右上到左下)
  - `2` = `RIGHT_LEFT`(从右到左)
  - `3` = `BR_TL`(从右下到左上)
  - `4` = `BOTTOM_TOP`(从下到上)
  - `5` = `BL_TR`(从左下到右上)
  - `6` = `LEFT_RIGHT`(从左到右)
  - `7` = `TL_BR`(从左上到右下)
  - 缺失或不在 0~7 范围 = 默认 `0`(从上到下)
- **整体空对象 `{}`** = 恢复默认背景(等同 colors 缺失)

### 方向映射:整数索引 → `GradientDrawable.Orientation`

直接复用 Android 原生枚举顺序,**全部 8 个值**一一对应:

| 索引 | Android `Orientation` | 视觉含义(start→end) |
|---|---|---|
| `0` | `TOP_BOTTOM` | 从顶到底 |
| `1` | `TR_BL` | 从右上到左下 |
| `2` | `RIGHT_LEFT` | 从右到左 |
| `3` | `BR_TL` | 从右下到左上 |
| `4` | `BOTTOM_TOP` | 从底到顶 |
| `5` | `BL_TR` | 从左下到右上 |
| `6` | `LEFT_RIGHT` | 从左到右 |
| `7` | `TL_BR` | 从左上到右下 |

> 注:H5 与 Android 直接共享 enum ordinal,**无需查表**。`parseOrientation` 用 `GradientDrawable.Orientation.values()[index]` 直接索引,索引越界走默认 `TOP_BOTTOM`。

### 默认背景恢复

`WebToolbar.init` 中 `LayoutInflater.inflate(...)` 时 root FrameLayout 的 `android:background="?attr/colorSurface"` 会被设置;Bridge 在 `init` 时缓存 `toolbar.background` 为 `defaultBackground`,调用 `setBackgroundGradient("{}")` 时还原这个 drawable。

### Lifecycle 安全:`() -> WebToolbar?` provider

Bridge 不直接持有 `WebToolbar` 强引用,而是通过 provider 函数获取:

```kotlin
class WebToolbarBridge(private val toolbarProvider: () -> WebToolbar?)
```

每次 JS 调用都通过 `toolbarProvider()` 取当前 toolbar,Fragment 重建、view 销毁时 `webToolbar` 为 null,provider 返回 null,方法静默 no-op。

### 线程模型:JS 调用默认在 WebView 的 binder 线程

通过 `Handler(Looper.getMainLooper()).post { ... }` 把所有 UI 操作切回主线程,避免在后台线程触碰 View 抛异常。

## 实现策略

### 1. 新增 `WebToolbarBridge.kt`

**新增** `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebToolbarBridge.kt`

```kotlin
package com.example.dodroidai.webviewsdk

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import android.webkit.JavascriptInterface

/**
 * WebView → 原生 WebToolbar 的 JS Bridge。
 *
 * H5 通过 window.WVToolbar.xxx() 调用本对象方法,实现对原生 toolbar 的控制:
 * - setTitle(String):更新标题文字
 * - setTitleColor(String hex):更新标题颜色
 * - setCloseVisible(Boolean):控制 close 按钮显隐
 * - setBackgroundGradient(String json):设置 toolbar 整体渐变背景
 *
 * 线程模型:JS 接口默认在 WebView binder 线程被调用,
 * 所有 View 操作通过 Handler 切到主线程执行。
 *
 * Lifecycle:不持有 WebToolbar 强引用,通过 provider 函数按需获取,
 * 避免 Fragment view 销毁后调用导致崩溃。
 */
class WebToolbarBridge(private val toolbarProvider: () -> WebToolbar?) {

    private val mainHandler = Handler(Looper.getMainLooper())

    @JavascriptInterface
    fun setTitle(title: String) {
        try {
            mainHandler.post {
                toolbarProvider()?.setTitle(title)
            }
        } catch (e: Exception) {
            Log.e(TAG, "setTitle failed: $title", e)
        }
    }

    @JavascriptInterface
    fun setTitleColor(hex: String) {
        try {
            val color = Color.parseColor(hex)
            mainHandler.post {
                toolbarProvider()?.setTitleTextColor(color)
            }
        } catch (e: Exception) {
            Log.e(TAG, "setTitleColor failed: $hex", e)
        }
    }

    @JavascriptInterface
    fun setCloseVisible(visible: Boolean) {
        try {
            mainHandler.post {
                toolbarProvider()?.setCloseVisible(visible)
            }
        } catch (e: Exception) {
            Log.e(TAG, "setCloseVisible failed: $visible", e)
        }
    }

    @JavascriptInterface
    fun setBackgroundGradient(json: String) {
        try {
            val obj = JSONObject(json)
            mainHandler.post {
                val toolbar = toolbarProvider() ?: return@post
                applyGradient(toolbar, obj)
            }
        } catch (e: Exception) {
            Log.e(TAG, "setBackgroundGradient failed: $json", e)
        }
    }

    /**
     * 应用渐变。
     * - colors 缺失 / 空数组 → 恢复默认背景
     * - colors 只有 1 个 → 复制成 2 个相同色
     * - direction 缺失 / 非法 → 默认 0(TOP_BOTTOM)
     */
    private fun applyGradient(toolbar: WebToolbar, obj: JSONObject) {
        val colorsArray = obj.optJSONArray(KEY_COLORS)

        // colors 缺失或为空 → 恢复默认
        if (colorsArray == null || colorsArray.length() == 0) {
            toolbar.resetBackground()
            return
        }

        val colors = mutableListOf<Int>()
        for (i in 0 until colorsArray.length()) {
            colors.add(Color.parseColor(colorsArray.getString(i)))
        }

        // 只有 1 个色 → 复制成 2 个相同色(GradientDrawable 至少要 2 色)
        if (colors.size == 1) {
            colors.add(colors[0])
        }

        val directionInt = obj.optInt(KEY_DIRECTION, 0)
        val orientation = parseOrientation(directionInt)
        val drawable = GradientDrawable(orientation, colors.toIntArray())
        toolbar.setBackgroundDrawable(drawable)
    }

    /**
     * 整数索引 → GradientDrawable.Orientation 全部枚举值(0~7)。
     * 与原生 enum ordinal 一一对应,无需查表。
     */
    private fun parseOrientation(index: Int): GradientDrawable.Orientation {
        val values = GradientDrawable.Orientation.values()
        return if (index in values.indices) {
            values[index]
        } else {
            GradientDrawable.Orientation.TOP_BOTTOM  // 默认
        }
    }

    companion object {
        private const val TAG = "WebToolbarBridge"
        private const val KEY_COLORS = "colors"
        private const val KEY_DIRECTION = "direction"
    }
}
```

### 2. `WebToolbar.kt` 新增 4 个公开方法

**修改** `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebToolbar.kt`,新增 imports:

```kotlin
import android.graphics.drawable.Drawable
```

新增字段(在 `init` 之前):

```kotlin
private var defaultBackground: Drawable? = null
```

在 `init` 末尾追加缓存:

```kotlin
defaultBackground = background
```

新增 4 个公开方法(放在 `setTitle` 系列附近,符合主题分组):

```kotlin
/**
 * 设置标题文本颜色。H5 Bridge 调用,内部 main thread。
 */
fun setTitleTextColor(color: Int) {
    tvTitle?.setTextColor(color)
}

/**
 * 设置 close 按钮是否显示。H5 Bridge 调用,内部 main thread。
 */
fun setCloseVisible(visible: Boolean) {
    btnClose?.visibility = if (visible) VISIBLE else GONE
}

/**
 * 设置 toolbar 整体背景(用于渐变)。H5 Bridge 调用,内部 main thread。
 */
fun setBackgroundDrawable(drawable: Drawable) {
    background = drawable
}

/**
 * 恢复 init 时的默认背景。Bridge setBackgroundGradient("{}") 时调用。
 */
fun resetBackground() {
    defaultBackground?.let { background = it }
}
```

### 3. `WebFragment.kt` 注册 Bridge

**修改** `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebFragment.kt`,新增 imports:

```kotlin
import android.webkit.JavascriptInterface
```

**关键修改**:在 `current.loadUrl(url)` 之前、`webToolbar?.setBackEnabled(false)` 之前,插入:

```kotlin
val bridge = WebToolbarBridge {
    webToolbar?.takeIf { it.isAttachedToWindow }
}
current.addJavascriptInterface(bridge, BRIDGE_NAME)
```

新增 companion 常量(放在 `ARG_URL` 之后):

```kotlin
const val BRIDGE_NAME = "WVToolbar"
```

> 注意:`@JavascriptInterface` 注解在 Kotlin 中需要显式 import(虽然是 Java 的注解),确保 SDK 编译时能找到。

### 4. `lookaround.html` 增加 Demo 控制面板

**修改** `webview-sdk/src/main/assets/wv/lookaround.html`

在 `</body>` 前插入 demo 控制区(底部固定浮动按钮):

```html
<style>
    .demo-panel {
        position: fixed;
        bottom: 16px;
        right: 16px;
        display: flex;
        flex-direction: column;
        gap: 8px;
        z-index: 999;
    }
    .demo-btn {
        background: #1a73e8;
        color: #ffffff;
        border: none;
        border-radius: 20px;
        padding: 10px 16px;
        font-size: 13px;
        box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
    }
    .demo-btn:active { background: #1557b0; }
</style>
<div class="demo-panel">
    <button class="demo-btn" onclick="demoTitle()">改标题</button>
    <button class="demo-btn" onclick="demoColor()">改标题颜色</button>
    <button class="demo-btn" onclick="demoGradient()">渐变背景</button>
    <button class="demo-btn" onclick="demoCloseHide()">隐藏 close</button>
    <button class="demo-btn" onclick="demoCloseShow()">显示 close</button>
    <button class="demo-btn" onclick="demoReset()">恢复默认</button>
</div>
<script>
    function demoTitle() {
        window.WVToolbar.setTitle("今日推荐 · 已读 12");
    }
    function demoColor() {
        window.WVToolbar.setTitleColor("#FFFFFF");
    }
    function demoGradient() {
        window.WVToolbar.setBackgroundGradient(
            '{"colors":["#FF5722","#FF9800"],"direction":"135deg"}'
        );
        window.WVToolbar.setTitleColor("#FFFFFF");
    }
    function demoCloseHide() {
        window.WVToolbar.setCloseVisible(false);
    }
    function demoCloseShow() {
        window.WVToolbar.setCloseVisible(true);
    }
    function demoReset() {
        window.WVToolbar.setBackgroundGradient("{}");
        window.WVToolbar.setTitleColor("#1F1F1F");
        window.WVToolbar.setTitle("今日推荐");
    }
</script>
```

## 关键文件清单

| 操作 | 路径 |
|---|---|
| 新增 | `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebToolbarBridge.kt` |
| 修改 | `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebToolbar.kt`(4 个新方法 + `defaultBackground` 缓存) |
| 修改 | `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebFragment.kt`(`addJavascriptInterface` + `BRIDGE_NAME`) |
| 修改 | `webview-sdk/src/main/assets/wv/lookaround.html`(demo 控制面板 + `<script>`) |

## 现有代码复用

- **`Handler(Looper.getMainLooper())` 模式**:参照 `MainActivity.kt` / `WebFragment.kt` 中现有的主线程调度方式。
- **`org.json.JSONObject`**:Android framework 内置,零依赖;参照 `WebFragment.kt:118` 已有的 `arguments?.getString(ARG_URL)` Bundle 解析风格。
- **`Color.parseColor(hex)`**:SDK 内已有用法(`WebFragment.kt:155` 的 `Color.TRANSPARENT` 思路)。
- **`GradientDrawable(orientation, colors)`**:Android framework 内置,无新依赖。

## 验证

### 编译验证

```bash
./gradlew :webview-sdk:assembleDebug
./gradlew :app:assembleDebug
./gradlew :app:lintDebug
./gradlew ktlintCheck  # 如已集成
```

期望:全部通过,0 error / 0 warning(业务代码)。

### 端到端验证(需 Android 设备/模拟器)

1. **Bridge 注册验证**:从 shortcut 启动 WebFragment → 加载内置 H5 → 看到底部 6 个 demo 按钮。
2. **改标题**:点击"改标题"→ toolbar 标题变为"今日推荐 · 已读 12"。
3. **改标题颜色**:点击"改标题颜色"→ toolbar 标题文字变白色(默认深色)。
4. **渐变背景**:点击"渐变背景"→ toolbar 整体变为橙红渐变(135deg),标题自动变白以保持对比度。
5. **隐藏 close**:点击"隐藏 close"→ toolbar 左侧只剩 back 按钮。
6. **显示 close**:点击"显示 close"→ close 重新出现。
7. **恢复默认**:点击"恢复默认"→ toolbar 颜色、标题颜色、close 显隐、文案全部回到初始。
8. **多语言不影响**:`strings.xml` 不变(本次不改 string 资源),仅 H5 JS 行为。
9. **Lifecycle 安全**:在 WebFragment 中点击 demo 按钮 → 立即系统 back 退出 → Bridge 引用通过 provider 兜底,无崩溃。
10. **异常路径**:H5 注入错误 JSON(如 `setBackgroundGradient('not json')`)→ `Log.e` 打印堆栈但 app 不崩溃,toolbar 背景保持现状。
11. **colors 单色**:H5 调用 `setBackgroundGradient('{"colors":["#FF0000"],"direction":"90deg"}')` → toolbar 显示纯红(单色复制成两端相同的渐变,视觉上无渐变效果)。
12. **colors 缺失恢复默认**:H5 调用 `setBackgroundGradient('{}')` 或 `setBackgroundGradient('{"colors":[]}')` → toolbar 背景还原为 `?attr/colorSurface`。

### 模块解耦验证

`webview-sdk` 仍只依赖 androidx + framework `org.json`,**不**新增依赖;Bridge 是 webview-sdk 内部实现,`app` 模块无任何变更,无感知。

## 风险与备注

- **JS 安全面**:Bridge 暴露的 4 个方法仅修改 toolbar 视觉,**不**触发任何 `popBackStack`、网络请求、Intent 跳转、权限申请,安全面很小。若未来需要新增能力,优先加白名单,不开放通用 dispatch。
- **`@JavascriptInterface` 必须显式 import**:Kotlin 调用 Java 注解需 import,否则编译报 `unresolved reference`。
- **`addJavascriptInterface` 注入时机**:必须在 `loadUrl` **之前**调用,否则首次加载的页面拿不到 Bridge 对象。
- **`btnClose` 默认可见性**:`wv_view_toolbar.xml` 当前是 `visible`(默认),Bridge 调用 `setCloseVisible(false)` 后变 `gone`,这是预期行为,与"关闭按钮"语义一致。
- **CSS angle 与 Android Orientation 的语义对齐**:两个枚举都是按视觉方向定义,只需按角度映射,不要按"命名"映射(避免出现方向反)。
- **CLAUDE.md 合规检查**:
  - 禁止 `lateinit` ✓(用 `var ...?` 可空类型)
  - 禁止 `!!` ✓(provider 用 `?.takeIf { ... }` 安全调用)
  - 禁止 throw ✓(catch 内只 Log.e,不重抛)
  - catch 必须打印堆栈 ✓(4 个方法全部 `Log.e(TAG, msg, e)`)
  - 中文注释 ✓
  - 多参数具名参数 ✓(本任务新增方法均单参数或 JSON,无需具名)
  - 禁止直接创建 Fragment ✓(未涉及)
  - 禁止 `parentFragmentManager.xxx` ✓(WebFragment 内 `parentFragmentManager.popBackStack()` 已存在,沿用)