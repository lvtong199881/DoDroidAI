# 多 AI 配置管理功能实现计划

## Context

用户希望 AI 设置页支持多个配置的管理和切换。当前实现只能存储单个 AI 配置，用户无法创建、保存多个不同的 AI 服务商配置。

## 实现方案

### 1. 数据模型修改

**文件**: `app/src/main/java/com/example/dodroidai/ai/config/AIConfig.kt`

- 添加 `id: String` 字段（UUID）
- 添加 `createdAt: Long` 和 `updatedAt: Long` 时间戳

### 2. AppConfigManager 重构

**文件**: `app/src/main/java/com/example/dodroidai/ai/config/AppConfigManager.kt`

将旧的平铺 Key 替换为 JSON 列表存储：

```kotlin
// 新增 Key
private val configsKey = stringPreferencesKey("configs") // JSON 数组存储配置列表
private val activeConfigIdKey = stringPreferencesKey("active_config_id")  // 当前激活配置 ID

// 新增 Flow
val configsFlow: Flow<List<AIConfig>> // 所有配置列表
val activeConfigIdFlow: Flow<String?>      // 当前激活配置 ID
val activeConfigFlow: Flow<AIConfig?>      // 当前激活配置（组合 flow）
val configFlow: Flow<AIConfig>             // 保持向后兼容，返回激活配置

// 新增方法
suspend fun addConfig(config: AIConfig): String
suspend fun updateConfig(config: AIConfig)
suspend fun deleteConfig(configId: String)
suspend fun setActiveConfig(configId: String)
suspend fun cloneConfig(configId: String): String?  // 返回新配置 ID
suspend fun getConfig(configId: String): AIConfig?

// 迁移逻辑：首次启动时将旧配置迁移为第一个配置
```

### 3. 新建 AIConfigListFragment（配置列表页）

**新文件**: `app/src/main/java/com/example/dodroidai/ui/setting/AIConfigListFragment.kt`

功能：
- RecyclerView 显示所有配置
- 每个 Item 显示：提供商名称、模型、激活状态指示
- 点击 Item 进入编辑页
- FAB 添加新配置
- 长按/滑动删除配置
- 长按弹出菜单：删除、克隆（复制配置创建新配置）
- 点击"激活"按钮设为当前配置

**布局**: `app/src/main/res/layout/fragment_ai_config_list.xml`

**Item布局**: `app/src/main/res/layout/item_ai_config.xml`

### 4. 新建 AIConfigListViewModel

**新文件**: `app/src/main/java/com/example/dodroidai/ui/setting/AIConfigListViewModel.kt`

```kotlin
class AIConfigListViewModel : ViewModel() {
    val configs: StateFlow<List<AIConfig>>
    val activeConfigId: StateFlow<String?>

    fun addConfig(config: AIConfig)
    fun updateConfig(config: AIConfig)
    fun deleteConfig(configId: String)
    fun setActiveConfig(configId: String)
    fun cloneConfig(configId: String)
}
```

### 5. 修改 AIConfigFragment（编辑页）

**文件**: `app/src/main/java/com/example/dodroidai/ui/setting/AIConfigFragment.kt`

修改点：
- 通过参数传入 `configId: String?`（null 表示新建）
- 根据模式显示不同标题："New Configuration" / "Edit Configuration"
- 编辑模式下显示"删除"和"设为激活"按钮
- 保存时调用 `addConfig` 或 `updateConfig`

### 6. 修改 AIConfigViewModel

**文件**: `app/src/main/java/com/example/dodroidai/ui/setting/AIConfigViewModel.kt`

- 支持加载指定配置进行编辑
- 保存时区分新建和更新

### 7. 修改 SettingsFragment

**文件**: `app/src/main/java/com/example/dodroidai/ui/setting/SettingsFragment.kt`

```kotlin
aiConfigCard?.setOnItemClickListener {
    navigateTo(AIConfigListFragment())  // 改为打开列表页
}
```

同时 `updateAIConfigUI` 需要改为显示当前激活配置的提供商名称。

### 8. 字符串资源

**文件**: `app/src/main/res/values/strings.xml`

新增：
- `ai_config_list_title` = "AI Configurations"
- `ai_config_new` = "New Configuration"
- `ai_config_edit` = "Edit Configuration"
- `ai_config_delete_confirm` = "Delete this configuration?"
- `ai_config_set_active` = "Set as Active"
- `ai_config_clone` = "Clone"
- `ai_config_active` = "Active"

## 关键文件清单

| 文件 | 操作 |
|------|------|
| `ai/config/AIConfig.kt` | 修改 |
| `ai/config/AppConfigManager.kt` | 修改 |
| `ui/setting/AIConfigListFragment.kt` | 新增 |
| `ui/setting/AIConfigListViewModel.kt` | 新增 |
| `ui/setting/AIConfigFragment.kt` | 修改 |
| `ui/setting/AIConfigViewModel.kt` | 修改 |
| `ui/setting/SettingsFragment.kt` | 修改 |
| `res/layout/fragment_ai_config_list.xml` | 新增 |
| `res/layout/item_ai_config.xml` | 新增 |
| `res/values/strings.xml` | 修改 |

## 复用已有实现

- `GsonUtil.fromJsonWithTypeToken()` - 用于 JSON 转 List<AIConfig>
- `GsonUtil.toJson()` - 用于 List<AIConfig> 转 JSON
- `SettingsItemView` - 用于配置列表 Item
- 现有的 Fragment 导航动画资源

## 验证方案

1. **功能测试**：
   - 新建配置 →列表显示
   - 编辑配置 → 数据正确回显
   - 删除配置 → 列表更新，若删激活配置则自动切换
   - 设为激活 → 列表和设置页同步更新
   - 切换激活配置后发送消息 → 使用新配置

2. **迁移测试**：
   - 保留旧 DataStore 数据的情况下启动 →旧配置自动迁移为第一个配置并激活