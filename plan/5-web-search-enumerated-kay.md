# 联网搜索（Web Search）实现计划

## Context
根据 TodoTasks.md P1 级任务，需要实现联网搜索功能，获取实时信息（天气、新闻、股票等）。用户选择将 Brave Search API Key 作为独立设置项管理，与 AI 模型配置分开。

## 实现方案

### 1. 新增 Brave Search API Key 配置

**修改文件**：
- `app/src/main/java/com/example/dodroidai/ai/config/AppConfigManager.kt` — 添加 `braveSearchApiKey` 存储
- `app/src/main/java/com/example/dodroidai/ai/config/AppConfig.kt` — 添加配置数据类字段
- `app/src/main/java/com/example/dodroidai/ui/setting/SettingsFragment.kt` — 添加联网搜索配置按钮，使用 CustomDialog 弹窗输入 API Key

**弹窗实现**：
- 使用 `CustomDialog` + `EditText` 作为自定义 View
- 输入框用于填写 Brave Search API Key
- 确认后保存到 DataStore

**不新增布局文件和 Fragment**

### 2. 创建 WebSearchTool

**新增文件**：`app/src/main/java/com/example/dodroidai/ai/tools/WebSearchTool.kt`

实现要点：
- 实现 `Tool` 接口
- 使用 OkHttp 调用 Brave Search API `https://api.search.brave.com/res/v1/web/search`
- 参数：`query`（搜索关键词）
- 返回：前 3-5 条结果（标题 + 链接 + 摘要）
- 添加缓存：相同关键词 10 分钟内复用结果（使用 LinkedHashMap 实现 LRU 缓存）
- 风险等级：`LOW`

### 3. 注册工具

**修改文件**：
- `app/src/main/java/com/example/dodroidai/ai/tools/ToolsDefinition.kt` — 添加 `WEB_SEARCH` 定义
- `app/src/main/java/com/example/dodroidai/ai/tools/ToolExecutor.kt` — 注册 `WebSearchTool`
- `app/src/main/java/com/example/dodroidai/DoDroidAIApplication.kt` — 初始化时传入配置

## 关键文件

| 文件 | 作用 |
|------|------|
| `AppConfigManager.kt` | 管理 Brave Search API Key 存储 |
| `WebSearchTool.kt` | 搜索工具实现（新建） |
| `ToolsDefinition.kt` | 添加工具定义 |
| `ToolExecutor.kt` | 注册新工具 |
| `SettingsFragment.kt` | 添加配置按钮 |

## 验证方案

1. 在 Settings 页面点击"联网搜索"配置项
2. 输入 Brave Search API Key 并保存
3. 对话中触发搜索（如"帮我搜索今天的天气"）
4. 验证搜索结果正确返回并显示
5. 验证 10 分钟内相同关键词使用缓存