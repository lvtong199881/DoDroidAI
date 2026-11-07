# 对话列表按时间分组实现计划

## Context
当前对话列表按 `updatedAt` 降序排列显示。用户希望按时间区间分组展示：今天、昨天、7天内、30天内、一个月前。

## 实现方案

### 1. 新增分组标题布局
文件：`app/src/main/res/layout/item_chat_section_header.xml`

用于显示分组标题文字，如"今天"、"昨天"等。

### 2. 修改 Adapter 支持多视图类型
文件：`app/src/main/java/com/example/dodroidai/ui/chat/ChatSessionAdapter.kt`

- 新增 `SECTION_HEADER` 视图类型
- 支持同时展示分组标题和会话项
- 使用 SealedClass 表示列表项：
```kotlin
sealed class ChatListItem {
    data class SectionHeader(val title: String) : ChatListItem()
    data class SessionItem(val session: ChatSession) : ChatListItem()
}
```

### 3. 新增分组工具函数
文件：`app/src/main/java/com/example/dodroidai/ui/chat/ChatListFragment.kt`

```kotlin
fun groupSessionsByTime(sessions: List<ChatSession>): List<ChatListItem>
```

分组逻辑：
- `今天`: 今天 0点 ~ 现在
- `昨天`: 昨天 0点 ~ 今天 0点
- `7天内`: 7天前 ~ 昨天 0点
- `30天内`: 30天前 ~ 7天前
- `一个月前`: 一个月前之前

### 4. 修改 ChatListFragment
文件：`app/src/main/java/com/example/dodroidai/ui/chat/ChatListFragment.kt`

- `observeSessions()` 中调用 `groupSessionsByTime()` 替代直接 `sortedByDescending`
- Adapter 接收 `List<ChatListItem>` 类型

### 5. 多语言支持
文件：`values/strings.xml` 和 `values-zh-rCN/strings.xml`

添加分组标题字符串：
- `chat_section_today` = "今天"
- `chat_section_yesterday` = "昨天"
- `chat_section_last_7_days` = "7天内"
- `chat_section_last_30_days` = "30天内"
- `chat_section_older` = "一个月前"

## 关键文件

| 文件 | 作用 |
|------|------|
| `app/src/main/java/com/example/dodroidai/ui/chat/ChatListFragment.kt` | 分组逻辑、Fragment |
| `app/src/main/java/com/example/dodroidai/ui/chat/ChatSessionAdapter.kt` | 支持多视图类型的 Adapter |
| `app/src/main/java/com/example/dodroidai/ui/chat/ChatSessionViewHolder.kt` | ViewHolder |
| `app/src/main/res/layout/item_chat_section_header.xml` | 分组标题布局 |
| `app/src/main/res/values/strings.xml` | 英文字符串 |
| `app/src/main/res/values-zh-rCN/strings.xml` | 中文字符串 |

## 验证方式
1. 创建多个不同时间的测试会话
2. 运行应用，验证分组显示是否正确
3. 测试中英文切换是否正常显示分组标题