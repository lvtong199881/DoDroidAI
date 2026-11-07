# 任务11：页面交互重构

## Context
当前 app 默认启动 ChatListFragment（会话列表页），用户需要先选一个会话才能进入 ChatFragment。这样的交互不够顺畅——用户可能只是想快速提问，而不是管理会话。

需求：
1. 默认启动对话页（ChatFragment），无 session 时显示引导文字
2. 发送消息时才创建 session
3. 左上角 back 按钮改为 menu 按钮，点击打开侧边栏展示会话列表

## 方案：手动 Fragment + DrawerLayout

不使用 Navigation Component，保持当前手动 Fragment 跳转的风格。

---

## 详细改动

### 1. activity_main.xml 改动
```xml
<?xml version="1.0" encoding="utf-8"?>
<androidx.drawerlayout.widget.DrawerLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:id="@+id/drawerLayout"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:fitsSystemWindows="true">

    <!-- 主内容区：ChatFragment -->
    <FrameLayout
        android:id="@+id/fragment_container"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <!-- 侧边栏：ChatListFragment -->
    <FrameLayout
        android:id="@+id/drawer_container"
        android:layout_width="280dp"
        android:layout_height="match_parent"
        android:layout_gravity="start"
        android:background="?attr/colorSurface"
        android:fitsSystemWindows="true" />

</androidx.drawerlayout.widget.DrawerLayout>
```

### 2. MainActivity.kt 改动
```kotlin
class MainActivity : AppCompatActivity() {

    private lateinit var drawerLayout: DrawerLayout
    private var chatListFragment: ChatListFragment? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        drawerLayout = findViewById(R.id.drawerLayout)

        if (savedInstanceState == null) {
            // 默认启动 ChatFragment（无 sessionId）
            supportFragmentManager.beginTransaction()
                .replace(R.id.fragment_container, ChatFragment.newInstance(null))
                .commit()

            // 预加载侧边栏中的 ChatListFragment
            chatListFragment = ChatListFragment.newInstance()
            supportFragmentManager.beginTransaction()
                .replace(R.id.drawer_container, chatListFragment!!)
                .commit()
        }
    }

    fun openDrawer() {
        drawerLayout.openDrawer(GravityCompat.START)
    }

    fun closeDrawer() {
        drawerLayout.closeDrawer(GravityCompat.START)
    }

    fun toggleDrawer() {
        if (drawerLayout.isDrawerOpen(GravityCompat.START)) {
            closeDrawer()
        } else {
            openDrawer()
        }
    }

    override fun onBackPressed() {
        if (drawerLayout.isDrawerOpen(GravityCompat.START)) {
            closeDrawer()
        } else {
            super.onBackPressed()
        }
    }
}
```

### 3. fragment_chat.xml 改动
添加空状态引导 TextView：

```xml
<TextView
    android:id="@+id/tvEmptyHint"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:text="@string/chat_empty_hint"
    android:textSize="16sp"
    android:textColor="?attr/colorOnSurface"
    android:alpha="0.6"
    android:gravity="center"
    android:padding="32dp"
    android:visibility="gone"
    app:layout_constraintStart_toStartOf="parent"
    app:layout_constraintEnd_toEndOf="parent"
    app:layout_constraintTop_toBottomOf="@id/toolbar"
    app:layout_constraintBottom_toTopOf="@id/inputContainer" />
```

### 4. ChatFragment 改动
```kotlin
// initViews 中：
toolbar?.setBackIcon(R.drawable.ic_menu)
toolbar?.setOnBackClickListener {
    (activity as? MainActivity)?.toggleDrawer()
}

// observeState 中控制空状态显示
viewLifecycleOwner.lifecycleScope.launch {
    viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
        viewModel.uiState.collect { state ->
            val isEmpty = state.messages.isEmpty() && !state.isLoading
            binding.tvEmptyHint.visibility = if (isEmpty) View.VISIBLE else View.GONE
        }
    }
}
```

### 5. ChatListFragment 改动
添加 drawer mode 和回调：

```kotlin
private var isDrawerMode = false
var onSessionSelected: ((String?) -> Unit)? = null

fun setDrawerMode(enabled: Boolean) {
    isDrawerMode = enabled
}

onSessionClick = { sessionId ->
    if (isDrawerMode) {
        (activity as? MainActivity)?.closeDrawer()
        onSessionSelected?.invoke(sessionId)
    } else {
        navigateTo(ChatFragment.newInstance(sessionId))
    }
}

onNewChatClick = {
    if (isDrawerMode) {
        (activity as? MainActivity)?.closeDrawer()
        onSessionSelected?.invoke(null)
    } else {
        navigateTo(ChatFragment.newInstance(null))
    }
}
```

MainActivity 接收回调并切换 Fragment：
```kotlin
chatListFragment?.onSessionSelected = { sessionId ->
    supportFragmentManager.beginTransaction()
        .replace(R.id.fragment_container, ChatFragment.newInstance(sessionId))
        .commit()
}
```

### 6. 新增资源

**res/drawable/ic_menu.xml**:
```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="?attr/colorOnSurface">
    <path
        android:fillColor="@android:color/white"
        android:pathData="M3,18h18v-2H3v2zm0,-5h18v-2H3v2zm0,-7v2h18V6H3z"/>
</vector>
```

**values/strings.xml** 和 **values-zh-rCN/strings.xml**:
```xml
<string name="chat_empty_hint">发送消息开始对话</string>
```

---

## 关键文件
- `MainActivity.kt` - 启动逻辑 + drawer 方法
- `activity_main.xml` - DrawerLayout 结构
- `ChatFragment.kt` - menu 按钮 + 空状态
- `ChatListFragment.kt` - drawer mode + 回调
- `fragment_chat.xml` - 添加空状态 TextView
- `res/drawable/ic_menu.xml` - 新增
- `values/strings.xml` - 新增字符串

## 验证方式
1. 启动 app 默认进入对话页（空白引导文字）
2. 点击左上角 menu 打开侧边栏
3. 选择会话切换/新建会话
4. 发送消息创建 session
5. 侧边栏正确响应返回键