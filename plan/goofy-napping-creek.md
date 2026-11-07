# 闪屏页实现计划

## Context
项目目前没有闪屏页，启动时直接进入 ChatListFragment。用户希望在启动时展示品牌 Logo 和品牌色背景，提升首次启动的视觉体验。

采用 Android 12+ 原生 Splash Screen API，这是官方推荐的实现方式。

## 实现步骤

### 1. 准备 Logo 资源
- 将 Logo 图片放入 `app/src/main/res/drawable/` 目录
- 推荐格式：PNG 或 WebP，带透明通道
- 推荐尺寸：108dp × 108dp（适配不同屏幕密度）

### 2. 配置闪屏主题颜色
文件：`app/src/main/res/values/colors.xml`

新增颜色值：
```xml
<color name="splashBackground">#XXXXXX</color>  <!-- 品牌背景色 -->
```

### 3. 创建闪屏主题
文件：`app/src/main/res/values-v27/themes.xml`（API 27+ 闪屏支持）

创建主题继承 `Theme.SplashScreen`：
```xml
<style name="Theme.MyApplication.Splash" parent="Theme.SplashScreen">
    <item name="windowSplashScreenBackground">@color/splashBackground</item>
    <item name="windowSplashScreenAnimatedIcon">@drawable/ic_launcher_foreground</item>
    <item name="windowSplashScreenBrandingText">@string/app_name</item>
</style>
```

### 4. 更新 AndroidManifest
文件：`app/src/main/AndroidManifest.xml`

为 MainActivity 添加主题：
```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:theme="@style/Theme.MyApplication.Splash">
    ...
</activity>
```

### 5. 在代码中使用 SplashScreen
文件：`app/src/main/java/com/example/dodroidai/MainActivity.kt`

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    val splashScreen = SplashScreen.getSplashScreen()
    super.onCreate(savedInstanceState)
    // 延迟初始化确保闪屏显示完整
}
```

## 关键文件

| 文件 | 作用 |
|------|------|
| `app/src/main/res/values/colors.xml` | 闪屏背景色定义 |
| `app/src/main/res/values-v27/themes.xml` | 闪屏主题（API 27+） |
| `app/src/main/AndroidManifest.xml` | MainActivity 主题配置 |
| `app/src/main/java/com/example/dodroidai/MainActivity.kt` | SplashScreen API 调用 |
| `app/src/main/res/drawable/ic_launcher_foreground.xml` | Logo 资源（已有） |

## 验证方式
1. 编译运行应用，观察启动时是否显示品牌色背景和 Logo
2. 验证闪屏到主界面的过渡动画是否流畅
3. 测试夜间模式下的显示效果