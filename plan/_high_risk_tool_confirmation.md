# 高风险工具确认功能

## Context
TodoTasks.md 要求高风险工具（riskLevel=HIGH）执行前弹出 AlertDialog 让用户确认。

## 实现方案

### 1. ChatViewModel 新增 requestToolConfirmation 方法
**文件**: `app/src/main/java/com/example/dodroidai/ui/chat/ChatViewModel.kt`

```kotlin
/**
 * 请求高风险工具确认
 */
private suspend fun requestToolConfirmation(tool: Tool, fragment: Fragment): Boolean {
    val deferred = CompletableDeferred<Boolean>()
    fragment.activity?.runOnUiThread {
        val dialog = CustomDialog.Builder(fragment.requireContext())
            .setTitle("确认执行")
            .setDescription("即将执行【${tool.name}】工具，此操作风险较高，是否继续？")
            .setButtons(
                CustomDialog.ButtonInfo("确认", onClick = {
                    Log.i(TAG, "Confirm button clicked")
                    if (!deferred.isCompleted) {
                        deferred.complete(true)
                    }
                }, dismissOnClick = true),
                CustomDialog.ButtonInfo("取消", onClick = {
                    Log.i(TAG, "Cancel button clicked")
                    if (!deferred.isCompleted) {
                        deferred.complete(false)
                    }
                }, dismissOnClick = true)
            )
            .setCancelable(true)
            .build()
        dialog.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_PANEL)
        dialog.show()
        Log.i(TAG, "Dialog shown")
    }
    return deferred.await()
}
```

### 2. executeToolCalls 修改
**文件**: `app/src/main/java/com/example/dodroidai/ui/chat/ChatViewModel.kt`

高风险工具在执行前先调用 `requestToolConfirmation` 请求用户确认。

### 3. CustomDialog 按钮点击修复
**文件**: `app/src/main/res/layout/item_dialog_button.xml`

将 `clickable` 和 `focusable` 从 TextView 移到 FrameLayout：

```xml
<!-- 修改后 -->
<FrameLayout
    android:clickable="true"
    android:focusable="true">
    <TextView
        android:clickable="false"
        android:focusable="false"
        ... />
</FrameLayout>
```

**文件**: `app/src/main/java/com/example/dodroidai/ui/common/CustomDialog.kt`

将 `setOnClickListener` 设置在 FrameLayout 根视图而非 TextView：

```kotlin
// 修改后
setOnClickListener { ... }  // 在 apply 块根视图上设置
```

## 修改文件清单

| 文件 | 修改内容 |
|------|----------|
| `ui/chat/ChatViewModel.kt` | 新增 `requestToolConfirmation` 方法，修改 `executeToolCalls` 增加高风险工具确认 |
| `ui/common/CustomDialog.kt` | 修复按钮点击事件设置位置 |
| `res/layout/item_dialog_button.xml` | 修复点击区域属性 |

## 验证方案

1. 发送"发短信给xxx，内容是xxx"
2. 弹出确认对话框
3. 点击"确认"按钮任意位置
4. 验证对话框关闭且短信发送