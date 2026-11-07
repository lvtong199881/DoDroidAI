# 工具模块重构：将每个 Tool 拆分为独立类

## Context
当前 `ToolExecutor.kt` 将所有工具逻辑放在一个大类中，违反了单一职责原则。需求将每个 Tool 拆分为独立类，实现统一接口。

## 目标接口设计

```kotlin
/**
 * 工具接口，所有工具实现类需实现此接口
 */
interface Tool {
    /** 工具名称，用于唯一标识 */
    val name: String

    /** 所需权限列表，无权限要求则为空列表 */
    val requiredPermissions: List<String>

    /** 工具风险等级 */
    val riskLevel: RiskLevel

    /** 检查是否已授予所需权限 */
    fun hasPermissions(context: Context): Boolean

    /** 请求所需权限
     * @param activity 用于启动权限请求的 Activity
     * @param callback 权限授予结果回调，true 表示已授予
     */
    fun requestPermissions(activity: Activity, callback: (Boolean) -> Unit)

    /** 执行工具
     * @param context Android 上下文
     * @param arguments JSON 格式的工具参数
     * @return 工具执行结果
     */
    fun execute(context: Context, arguments: String): ToolResult
}
```

## 实现方案

### 1. 修改 Tool.kt
**文件**: `app/src/main/java/com/example/dodroidai/ai/tools/Tool.kt`

新增 Tool 接口（保留原有数据结构）：

```kotlin
/**
 * 工具接口，所有工具实现类需实现此接口
 */
interface Tool {
    /** 工具名称，用于唯一标识 */
    val name: String

    /** 所需权限列表，无权限要求则为空列表 */
    val requiredPermissions: List<String>

    /** 工具风险等级 */
    val riskLevel: RiskLevel

    /** 检查是否已授予所需权限 */
    fun hasPermissions(context: Context): Boolean

    /** 请求所需权限
     * @param activity 用于启动权限请求的 Activity
     * @param callback 权限授予结果回调，true 表示已授予
     */
    fun requestPermissions(activity: Activity, callback: (Boolean) -> Unit)

    /** 执行工具
     * @param context Android 上下文
     * @param arguments JSON 格式的工具参数
     * @return 工具执行结果
     */
    fun execute(context: Context, arguments: String): ToolResult
}
```

### 2. 创建各个 Tool 实现类
**新增文件**:
- `app/src/main/java/com/example/dodroidai/ai/tools/GetCurrentTimeTool.kt`
- `app/src/main/java/com/example/dodroidai/ai/tools/SetAlarmTool.kt`
- `app/src/main/java/com/example/dodroidai/ai/tools/AddCalendarEventTool.kt`
- `app/src/main/java/com/example/dodroidai/ai/tools/SendSmsTool.kt`
- `app/src/main/java/com/example/dodroidai/ai/tools/AddNoteTool.kt`

示例 GetCurrentTimeTool：

```kotlin
/**
 * 获取当前时间工具
 */
class GetCurrentTimeTool : Tool {
    override val name = "get_current_time"
    override val requiredPermissions = emptyList()
    override val riskLevel = RiskLevel.LOW

    override fun hasPermissions(context: Context) = true

    override fun requestPermissions(activity: Activity, callback: (Boolean) -> Unit) {
        callback(true)
    }

    override fun execute(context: Context, arguments: String): ToolResult {
        val now = Date()
        val dateFormat = SimpleDateFormat("yyyy年MM月dd日 HH:mm:ss", Locale.getDefault())
        return ToolResult(
            toolCallId = "",
            toolName = name,
            success = true,
            result = dateFormat.format(now)
        )
    }
}
```

### 3. 重写 ToolExecutor
**文件**: `app/src/main/java/com/example/dodroidai/ai/tools/ToolExecutor.kt`

ToolExecutor 变为工具注册中心：

```kotlin
/**
 * 工具执行器，负责管理所有工具并分发执行
 */
class ToolExecutor(private val context: Context) {
    private val tools: Map<String, Tool> = listOf(
        GetCurrentTimeTool(),
        SetAlarmTool(),
        AddCalendarEventTool(context),
        SendSmsTool(context),
        AddNoteTool()
    ).associateBy { it.name }

    fun execute(toolCall: ToolCall): ToolResult {
        return tools[toolCall.name]?.execute(context, toolCall.arguments)
            ?: ToolResult(toolCallId = toolCall.id, toolName = toolCall.name,
                success = false, result = "", error = "未知工具: ${toolCall.name}")
    }

    fun hasPermissions(toolName: String): Boolean {
        return tools[toolName]?.hasPermissions(context) ?: false
    }

    fun requestPermissions(toolName: String, activity: Activity, callback: (Boolean) -> Unit) {
        tools[toolName]?.requestPermissions(activity, callback)
    }
}
```

### 4. 简化 ToolManager
**文件**: `app/src/main/java/com/example/dodroidai/ai/tools/ToolManager.kt`

权限检查委托给各 Tool 实例，提供 requestPermissions 方法。

## 文件清单

| 操作 | 文件路径 |
|------|----------|
| 修改 | `ai/tools/Tool.kt` - 新增 Tool 接口 |
| 新增 | `ai/tools/GetCurrentTimeTool.kt` - 获取当前时间工具 |
| 新增 | `ai/tools/SetAlarmTool.kt` - 设置闹钟工具 |
| 新增 | `ai/tools/AddCalendarEventTool.kt` - 添加日历事件工具 |
| 新增 | `ai/tools/SendSmsTool.kt` - 发送短信工具 |
| 新增 | `ai/tools/AddNoteTool.kt` - 添加笔记工具 |
| 重写 | `ai/tools/ToolExecutor.kt` - 简化为注册中心 |
| 修改 | `ai/tools/ToolManager.kt` - 权限委托 |
| 修改 | `ai/tools/ToolsDefinition.kt` - 使用 Tool 类生成定义 |

## 验证方案

1. 运行应用，发送"现在几点了" → 验证 get_current_time 正常工作
2. 发送"设置明天早上8点闹钟" → 验证 set_alarm 正常工作
3. 发送"添加一个日历事件" → 验证 add_calendar_event 正常工作（需要日历权限）
4. 测试缺少权限时是否正确请求权限
