# 实现桌面小组件功能

## Context

项目需要实现桌面小组件（Widget），支持 1x2、1x4、2x2 三种布局。点击小组件后开启新对话。目前项目没有 Widget 相关代码。

## 实现方案

### 1. 创建 WidgetProvider

创建 `AgentWidgetProvider.kt` 继承 `AppWidgetProvider`：

- 文件路径：`app/src/main/java/com/example/dodroidai/widget/AgentWidgetProvider.kt`
- 处理点击事件，点击后通过 `Intent.FLAG_ACTIVITY_NEW_TASK` 启动 `MainActivity` 并传入 `newChat=true`

### 2. 创建 Widget 布局 XML

在 `res/layout/` 下创建三个布局文件：

| 文件 | 尺寸 | 用途 |
|------|------|------|
| `widget_agent_1x2.xml` | 1x2 | 简洁按钮 |
| `widget_agent_1x4.xml` | 1x4 | 带快捷指令 |
| `widget_agent_2x2.xml` | 2x2 | 大图标+快捷指令 |

布局包含：
- 背景/圆角
- App图标
- 点击提示文字
- 快捷指令文字（1x4和2x2）

### 3. 创建 Widget 信息 XML

在 `res/xml/` 下创建 `agent_widget_info.xml`：

- 使用 `appwidget-provider` 声明 minWidth/minHeight 等属性
- 支持三种尺寸通过 `minResizeWidth/minResizeHeight`

### 4. 注册 Receiver

在 `AndroidManifest.xml` 中添加 widget receiver 配置。

### 5. 修改 MainActivity

修改 `MainActivity` 接收参数，启动时检测 `newChat=true` 时直接打开新对话页面（`ChatFragment.newInstance(null)`）。

### 6. 创建 Widget 尺寸资源文件

在 `res/values/dimens.xml` 中定义小中大三种 widget 的具体尺寸。

## 关键文件

- 新建：`app/src/main/java/com/example/dodroidai/widget/AgentWidgetProvider.kt`
- 新建：`res/layout/widget_agent_1x2.xml`
- 新建：`res/layout/widget_agent_1x4.xml`
- 新建：`res/layout/widget_agent_2x2.xml`
- 新建：`res/xml/agent_widget_info.xml`
- 修改：`AndroidManifest.xml`
- 修改：`MainActivity.kt`

## 验证方法

1. Android Studio 中构建项目，确认编译通过
2. 在模拟器或真机上长按桌面 → 添加小组件 → 查看三种尺寸是否正常显示
3. 点击小组件，确认是否打开新对话页面