# 任务11：页面交互重构

## Context
当前 app 默认启动 ChatListFragment（会话列表页），用户需要先选一个会话才能进入 ChatFragment。这样的交互不够顺畅——用户可能只是想快速提问，而不是管理会话。

需求：
1. 默认启动对话页（ChatFragment），无 session 时显示引导文字
2. 发送消息时才创建 session
3. 左上角 back 按钮改为 menu 按钮，点击打开侧边栏展示会话列表

## 详细改动

### 1. activity_main.xml
改用 DrawerLayout 包装，主内容区放 ChatFragment，侧边栏放 ChatListFragment：
```xml
<?xml version="1.0" encoding="utf-8"?>
<androidx.drawerlayout.widget.DrawerLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:id="@+id/drawerLayout"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:fitsSystemWindows="true">

    <FrameLayout
        android:id="@+id/fragment_container"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <FrameLayout
        android:id="@+id/drawer_container"
        android:layout_width="280dp"
        android:layout_height="match_parent"
        android:layout_gravity="start"
        android:background="?attr/colorSurface"
        android:fitsSystemWindows="true" />

</androidx.drawerlayout.widget.DrawerLayout>
```

### 2. MainActivity.kt
- 默认启动 ChatFragment（无 sessionId）
- 预加载侧边栏 ChatListFragment
- 添加 openDrawer/closeDrawer/toggleDrawer 方法
- 重写 onBackPressed 处理侧边栏返回

### 3. fragment_chat.xml
添加空状态引导 TextView（id: tvEmptyHint）

### 4. ChatFragment.kt
- initViews 中：将 back 图标改为 ic_menu，点击调用 MainActivity.toggleDrawer()
- observeState 中：无消息时显示空状态引导

### 5. ChatListFragment.kt
- 添加 isDrawerMode 属性和 setDrawerMode() 方法
- 添加 onSessionSelected 回调
- 点击会话时如果是 drawer mode，关闭侧边栏并回调

### 6. 新增资源
- **res/drawable/ic_menu.xml**：三横线菜单图标
- **values/strings.xml** 新增：`chat_empty_hint` = "发送消息开始对话"
- **values-zh-rCN/strings.xml** 新增：中文翻译

## 关键文件
| 文件 | 改动 |
|------|------|
| activity_main.xml | 改用 DrawerLayout |
| MainActivity.kt | 启动逻辑 + drawer 方法 |
| fragment_chat.xml | 添加空状态 TextView |
| ChatFragment.kt | menu 按钮 + 空状态显示 |
| ChatListFragment.kt | drawer mode + 回调 |
| ic_menu.xml | 新增 |
| strings.xml | 新增字符串 |

## 验证方式
1. 启动 app 默认进入对话页，显示空白引导文字
2. 点击左上角 menu 打开侧边栏
3. 选择会话切换/新建会话
4. 发送消息创建 session
5. 侧边栏打开时按返回键关闭侧边栏