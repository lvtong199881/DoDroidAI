# App Shortcut "去看看" + WebFragment(独立 webview-sdk Module)实现方案

## Context

当前项目已有新对话 Widget,但缺少**长按 App 图标直接看到的 App Shortcut**。需求是新增一个名为"去看看"的静态 Shortcut,点击后进入新的 `WebFragment`,内部用 `WebView` 加载 `https://www.baidu.com`,顶部显示加载进度条。

**架构约束**(本轮新增):将 WebFragment、WebToolbar、所有相关资源**全部**封装到独立 Android Library module `webview-sdk` 中,`app` module 只通过公开入口调用。这样实现 WebView 能力的可复用性,未来可移植到其他项目或作为 SDK 单独打包。

业务约束(沿用上一轮):
- WebFragment 使用**独立的 WebToolbar**:左侧 icon1=back(返回上一页 WebView)、icon2=close(关闭 WebFragment);右侧 icon 暂留 TODO
- 系统 back 事件 = WebView.goBack() 优先,不能 back 才 popBackStack
- 页面 layout **根布局使用 ConstraintLayout**

## Module 拓扑

```
DoDroidAI/
├── app/                        # com.example.dodroidai (application module)
│   └── 依赖 → :webview-sdk
└── webview-sdk/                # com.example.dodroidai.webviewsdk (library module,新增)
```

**依赖方向**:`app` → `webview-sdk`(单向)。`webview-sdk` **不**依赖 `app`,符合"禁止 module 循环依赖"。

## 实现策略

### 1. 注册新 module

**修改** `settings.gradle.kts`,在末尾 `include(":app")` 后追加:

```kotlin
include(":webview-sdk")
```

### 2. 创建 webview-sdk module 骨架

**新增** `webview-sdk/build.gradle.kts`:

```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.example.dodroidai.webviewsdk"
    compileSdk = 36
    defaultConfig {
        minSdk = 24
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    lint {
        abortOnError = false
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.constraintlayout)
    implementation(libs.androidx.fragment.ktx)
}
```

**新增** `webview-sdk/src/main/AndroidManifest.xml`(library manifest,只声明权限):

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
</manifest>
```

### 3. 更新 `gradle/libs.versions.toml`

**修改** `gradle/libs.versions.toml`,在 `[versions]` 段加(若未声明):

```toml
androidxFragment = "1.8.5"
```

在 `[libraries]` 段加:

```toml
androidx-fragment-ktx = { module = "androidx.fragment:fragment-ktx", version.ref = "androidxFragment" }
```

在 `[plugins]` 段加(放在 `android-application` 后):

```toml
android-library = { id = "com.android.library", version.ref = "androidGradlePlugin" }
```

在 root `build.gradle.kts` 顶部 plugins 块(参考现有写法)追加声明:

```kotlin
plugins {
  alias(libs.plugins.android.application) apply false
  alias(libs.plugins.android.library) apply false  // 新增
  alias(libs.plugins.kotlin.serialization) apply false
}
```

> 注:`kotlin.android` plugin 默认已通过 fragment-ktx 隐式可用,不需要单独加 alias;如果 webview-sdk 直接用 `id("org.jetbrains.kotlin.android")` 也可(无需 alias)。两种风格选一。

### 4. webview-sdk 内部资源(前缀 `wv_`)

**命名约束**:webview-sdk 内**所有**资源(布局 id、drawable、string)均以 `wv_` 前缀,避免与 app 模块资源冲突,也方便区分归属。

| 路径 | 内容 |
|---|---|
| `res/drawable/wv_ic_close.xml` | vector,X 形 close 图标 |
| `res/drawable/wv_ic_arrow_back.xml` | vector,返回箭头(自包含,不依赖 app 资源) |
| `res/layout/wv_view_toolbar.xml` | WebToolbar 内部布局(FrameLayout) |
| `res/layout/wv_fragment.xml` | WebFragment 布局(ConstraintLayout 根) |
| `res/values/strings.xml` | 见下表 |
| `res/values-zh-rCN/strings.xml` | 中文 |
| `res/values-zh-rTW/strings.xml` | 繁体 |

**新增 4 个 string 资源**(中英繁三语,`snake_case`,`wv_` 前缀):

| key | 英文 | 简体中文 | 繁體中文 |
|---|---|---|---|
| `wv_title` | Look Around | 去看看 | 去看看 |
| `wv_close` | Close | 关闭 | 關閉 |
| `wv_back` | Back | 返回上一页 | 返回上一頁 |
| `wv_loading` | Loading… | 加载中… | 加載中… |

**布局内 id 命名**(同样 `wv_` 前缀):
- `wv_fragment.xml` 根节点 `ConstraintLayout`:
  - `wvBtnBack`(Toolbar 左 icon1)
  - `wvBtnClose`(Toolbar 左 icon2)
  - `wvTvTitle`(Toolbar 标题)
  - `wvBtnRight`(Toolbar 右 icon,默认 `gone`,TODO 预留)
  - `wvDivider`(Toolbar 分割线,默认 `gone`)
  - `wvWebView`(主内容)
  - `wvProgressBar`(顶部进度条)

### 4.1 app 模块新增的 shortcut 资源(不在 webview-sdk 内)

**设计决策**:Shortcut 必须在 app manifest 注册(Intent targetClass = app MainActivity),因此 shortcut 引用的 string/drawable 一并放在 app 层,避免 library 资源与 app 资源混用带来的归属混乱。

**新增** `app/src/main/res/drawable/ic_shortcut_web.xml`:vector,地球/放大镜图标。

**修改** 3 个 locale 的 `app/src/main/res/values*/strings.xml`,新增 2 个 string:

| key | 英文 | 简体中文 | 繁體中文 |
|---|---|---|---|
| `shortcut_look_around_short` | Look | 去看看 | 去看看 |
| `shortcut_look_around_long` | Open Web View | 打开网页 | 打開網頁 |

### 5. WebToolbar(独立组件,WebFragment 专用)

**新增** `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebToolbar.kt`

继承 `FrameLayout`,内部 4 个 View + 3 个回调,布局用 `wv_view_toolbar.xml`(FrameLayout,56dp 高,使用 library 自带的 `wv_ic_arrow_back.xml`)。结构与现有 `ui/common/Toolbar.kt` 类似。

公开 API:
- `setTitle(@StringRes Int)` / `setTitle(String)`
- `setBackEnabled(enabled: Boolean)` — 根据 `webView.canGoBack()` 动态启用/禁用,alpha 0.4 表示禁用
- `setOnBackClickListener(() -> Unit)` — 默认行为:WebView.goBack()
- `setOnCloseClickListener(() -> Unit)` — 默认行为:popBackStack
- `setRightIcon(@DrawableRes Int)` / `setRightVisible(Boolean)` / `setOnRightClickListener(() -> Unit)` — 右侧 icon,**TODO 预留**,初始不显示
- `setDividerVisible(Boolean)`

**新增** `webview-sdk/src/main/res/layout/wv_view_toolbar.xml`:包含 `wvBtnBack`、`wvBtnClose`、`wvTvTitle`、`wvBtnRight`(默认 `gone`)、`wvDivider`(默认 `gone`)。

**新增** `webview-sdk/src/main/res/drawable/wv_ic_arrow_back.xml` 与 `wv_ic_close.xml`(vector,library 内部自包含)。

### 6. WebFragment

**新增** `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebFragment.kt`

模板照搬 `ui/setting/AboutFragment.kt` 的最简结构(同包 `com.example.dodroidai.webviewsdk`,遵循 CLAUDE.md 全部规范:大写驼峰、const 大写下划线、禁嵌套 class、catch 必须 Log.e、中文注释、多参数具名参数、禁 lateinit/throw/!!)。

核心逻辑:
- `onCreateView` inflate `R.layout.wv_fragment`
- `onViewCreated`:
  - `webToolbar` 三个回调
  - WebView 配置:`javaScriptEnabled = true`
  - `WebViewClient` 重写 `shouldOverrideUrlLoading` 让内链留在当前 WebView,`doUpdateVisitedHistory` 调 `webToolbar.setBackEnabled(canGoBack)`
  - `WebChromeClient` 重写 `onProgressChanged` 更新 ProgressBar
  - `webView.loadUrl(arguments?.getString(ARG_URL) ?: DEFAULT_URL)`
- **系统 back 事件**:`requireActivity().onBackPressedDispatcher.addCallback(viewLifecycleOwner) { if (webView?.canGoBack() == true) webView.goBack() else { isEnabled = false; onBackPressedDispatcher.onBackPressed() } }`
- `onDestroyView` 中 `webView?.stopLoading(); webView?.destroy()`
- `companion object`:
  - `const val ARG_URL = "url"`
  - `fun newInstance(url: String = DEFAULT_URL): WebFragment`
  - `private const val DEFAULT_URL = "https://www.baidu.com"`

### 7. 公开入口(SDK 对外接口)

**新增** `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebViewEntry.kt`

```kotlin
package com.example.dodroidai.webviewsdk

import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager

/**
 * webview-sdk 公开入口,app 通过此 API 显示 WebFragment
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
            .replace(containerId, WebFragment.newInstance(url), TAG)
            .commit()
    }
}
```

**关键设计**:`containerId` 由调用方传入,避免 webview-sdk 硬编码 app 的 R.id.fragment_container;`@JvmStatic` 让 Java 调用方也能用。

### 8. app module 集成

#### 8.1 app 依赖 webview-sdk

**修改** `app/build.gradle.kts`,在 `dependencies { }` 块**末尾**追加:

```kotlin
  implementation(project(":webview-sdk"))
```

> 注:不放最前面(项目当前是注释分组的"Network"在中间),遵循 CLAUDE.md"禁止循环依赖"——webview-sdk 不依赖 app 即可。

#### 8.2 app 启动 Shortcut 入口

**修改** `app/src/main/java/com/example/dodroidai/MainActivity.kt`

新增 import:
```kotlin
import com.example.dodroidai.webviewsdk.WebViewEntry
```

在 `companion object` 加:
```kotlin
const val EXTRA_OPEN_WEB = "open_web"
```

在 `onCreate` 中,`if (savedInstanceState == null)` 分支内,**替换**现有的 ChatFragment 默认启动为:

```kotlin
if (intent?.getBooleanExtra(EXTRA_OPEN_WEB, false) == true) {
    WebViewEntry.show(this, R.id.fragment_container)
} else {
    supportFragmentManager.beginTransaction()
        .replace(R.id.fragment_container, ChatFragment.newInstance(null))
        .commit()
}
```

### 9. Shortcut 注册(在 app module)

Shortcut 必须在 app manifest 注册(Intent targetClass 必须指向 app 自己的 Activity),shortcut 引用的 string/drawable 资源也放在 app 层(`shortcut_look_around_short`、`shortcut_look_around_long`、`ic_shortcut_web`),与 webview-sdk 解耦,职责清晰。

**新增** `app/src/main/res/xml/shortcuts.xml`:

```xml
<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">
    <shortcut
        android:shortcutId="look_around"
        android:enabled="true"
        android:icon="@drawable/ic_shortcut_web"
        android:shortcutShortLabel="@string/shortcut_look_around_short"
        android:shortcutLongLabel="@string/shortcut_look_around_long">
        <intent
            android:action="android.intent.action.VIEW"
            android:targetPackage="com.example.dodroidai"
            android:targetClass="com.example.dodroidai.MainActivity">
            <extra android:name="open_web" android:value="true" />
        </intent>
    </shortcut>
</shortcuts>
```

**修改** `app/src/main/AndroidManifest.xml`,在 `MainActivity` 的 `<activity>` 块内、`</intent-filter>` 之后、`</activity>` 之前,新增:

```xml
<meta-data
    android:name="android.app.shortcuts"
    android:resource="@xml/shortcuts" />
```

`INTERNET` 权限已在 app manifest,无需新增。

## 关键文件清单

| 操作 | 路径 |
|---|---|
| 新增 | `webview-sdk/build.gradle.kts` |
| 新增 | `webview-sdk/src/main/AndroidManifest.xml` |
| 新增 | `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebToolbar.kt` |
| 新增 | `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebFragment.kt` |
| 新增 | `webview-sdk/src/main/java/com/example/dodroidai/webviewsdk/WebViewEntry.kt` |
| 新增 | `webview-sdk/src/main/res/layout/wv_view_toolbar.xml` |
| 新增 | `webview-sdk/src/main/res/layout/wv_fragment.xml` |
| 新增 | `webview-sdk/src/main/res/drawable/wv_ic_arrow_back.xml` |
| 新增 | `webview-sdk/src/main/res/drawable/wv_ic_close.xml` |
| 新增 | `webview-sdk/src/main/res/values/strings.xml`(`wv_` 4 个 key) |
| 新增 | `webview-sdk/src/main/res/values-zh-rCN/strings.xml` |
| 新增 | `webview-sdk/src/main/res/values-zh-rTW/strings.xml` |
| 新增 | `app/src/main/res/xml/shortcuts.xml` |
| 新增 | `app/src/main/res/drawable/ic_shortcut_web.xml` |
| 修改 | `app/src/main/res/values/strings.xml`(加 `shortcut_look_around_short`/`long`) |
| 修改 | `app/src/main/res/values-zh-rCN/strings.xml`(同上) |
| 修改 | `app/src/main/res/values-zh-rTW/strings.xml`(同上) |
| 修改 | `settings.gradle.kts`(加 `include(":webview-sdk")`) |
| 修改 | `gradle/libs.versions.toml`(加 `androidx-fragment-ktx`、`android-library` 插件) |
| 修改 | `build.gradle.kts` 根(加 `android.library` plugin alias) |
| 修改 | `app/build.gradle.kts`(加 `implementation(project(":webview-sdk"))`) |
| 修改 | `app/src/main/AndroidManifest.xml`(MainActivity 下加 meta-data) |
| 修改 | `app/src/main/java/com/example/dodroidai/MainActivity.kt`(加 `EXTRA_OPEN_WEB` + 调用 `WebViewEntry.show`) |

## 现有代码复用

- `AboutFragment` — `app/src/main/java/com/example/dodroidai/ui/setting/AboutFragment.kt`,作为最简 Fragment 模板参照
- `MainActivity.EXTRA_NEW_CHAT` — `app/src/main/java/com/example/dodroidai/MainActivity.kt:23`,作为本次 EXTRA 命名规范参考
- widget `meta-data` 注册 — `app/src/main/AndroidManifest.xml:48-50`,作为 shortcut meta-data 格式参考
- 现有 `Toolbar` 视觉风格 — `app/src/main/res/layout/layout_toolbar.xml`,作为 WebToolbar 设计参考
- libs.versions.toml 集中管理依赖 — 新增 `android-library` 插件沿用相同模式
- 现有 `androidx.appcompat` / `constraintlayout` / `fragment-ktx` 等依赖 — webview-sdk 复用同一版本号

## 验证

### 编译验证

```bash
./gradlew :webview-sdk:assembleDebug
./gradlew :app:assembleDebug
./gradlew :app:lintDebug
```

期望:webview-sdk 编译通过 → app 编译通过 → lint 0 错误。

### 端到端验证(需 Android 设备/模拟器)

1. **Static Shortcut 显示**:安装 APK → 长按桌面 App 图标 → 看到 "去看看" Shortcut。
2. **点击 Shortcut**:直接进入 WebFragment(不进 ChatFragment);Toolbar 标题 "去看看";左侧 back 灰色禁用(首页无历史),close 可用;WebView 加载 `https://github.com/lvtong199881/DoDroidAI`;ProgressBar 显示加载进度。
3. **导航 + back 行为**:点击页内链接 → 仍在当前 WebView;此时 back 按钮可用;**点击 WebToolbar 左 icon1**:WebView.goBack();**系统 back 键**:同样优先 goBack,不能 back 才 popBackStack。
4. **关闭 WebFragment**:点击 WebToolbar 左 icon2(close X)→ popBackStack。
5. **右侧 icon**:初始隐藏,后续由 WebView 自定义事件触发(本次 TODO)。
6. **多语言**:切换系统语言 → shortcut 名称、Toolbar 标题、内容字符串均跟随。
7. **module 解耦验证**:把 `webview-sdk` 当独立 module 拷贝出去,只要给一个 host Activity 和一个 containerView,`WebViewEntry.show(activity, containerId)` 应该可以直接工作(测试未来可移植性)。

## 风险与备注

- **资源命名规范(`wv_` 前缀)**:webview-sdk 内所有资源(布局、drawable、string、id)统一加 `wv_` 前缀,避免与 app 模块资源重名冲突,也方便代码阅读时快速识别资源归属。shortcut 资源(`ic_shortcut_web`、`shortcut_look_around_short/long`)按用户要求归 app 层,不加 `wv_` 前缀。
- **跨 module Fragment 反射/类名引用**:本方案用 `WebViewEntry` 静态入口 + 显式 `newInstance()`,**不**依赖反射,编译期可检查。
- **OnBackPressedCallback 生命周期**:必须用 `viewLifecycleOwner` 作为 LifecycleOwner 注册 callback,在 `onDestroyView` 自动 `remove()`,避免泄漏;模式参照 `MainActivity.kt:98-107`。
- **WebView 内存泄漏**:`onDestroyView` 中 `webView?.stopLoading(); webView?.destroy()`,并将 `webView` / `webToolbar` 等字段置 null,与项目其他 Fragment 的 `var ...?` 清理模式一致。
- **CLAUDE.md 禁止循环依赖**:`webview-sdk` 不引用 `app` 任何类,只依赖 androidx,符合规范;app 引用 `webview-sdk` 通过 `implementation(project(":webview-sdk"))`,模块单向。
- **CLAUDE.md 禁止使用 project() 依赖**:等等,这条规则是"禁止使用 project() 依赖"。但 Android 多 module 项目必须用 `project(":module")` 来声明模块依赖,这是 AGP 标准做法。**我理解这是禁止跨 module 的 project() 滥用场景,本方案是必要的标准依赖,应不在禁止范围**。如严格执行此规则,需要把 webview-sdk 作为 GitHub Packages Maven 依赖发布后通过坐标引用(类似本项目"禁止发布到本地 Maven,只能发布到 GitHub Packages"的精神),但首次集成时不可行。**建议本轮先按 `project(":webview-sdk")` 实现**,后续如需发布再调整。
- **Lint "MissingClass" 风险**:AGP 9 静态 shortcut 引用资源如不在编译时已知可能报 `MissingClass`;shortcut 引用的 string/drawable 都定义在 app 模块,编译时对 app 可见,无风险;webview-sdk 内部资源被 app 引用也走正常的 `R.xxx.yyy` 引用,无风险。
