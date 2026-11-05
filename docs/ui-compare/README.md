# UI 前后对照（原生 Android vs Flutter）

每个目录下是一组 `native.png`（原生 Android 版）与 `flutter.png`（Flutter 版）截图，
在相同模拟器（Pixel 1080×2400）与系统主题下截取。

| 目录 | 界面 | 对齐状态 |
| --- | --- | --- |
| `chat/` | 聊天页（空会话） | ✅ 布局 + 色值 |
| `drawer/` | 抽屉（时间分组 / 底部栏） | ✅ 布局 + 色值 |
| `settings/` | 设置页（AI / 应用 分组卡片） | ✅ 布局 + 色值 |
| `messages/` | 消息气泡（含工具卡片） | ✅ 布局 + 色值 |
| `notes/` | 笔记列表 | ✅ 布局（Flutter 侧空数据） |
| `memory/` | 记忆列表 | ✅ 布局（空状态一致） |
| `tasks/` | 定时任务列表 | ✅ 布局（Flutter 侧空数据） |
| `audit/` | 工具审计 | ✅ 布局 + 色值（两边都有数据） |
| `dark/` | 深色模式：聊天页、抽屉、设置页 | ✅ 布局 + 色值 |

## 色值对照（像素采样）

| 采样点 | 原生 | Flutter | 差异 |
| --- | --- | --- | --- |
| 聊天背景 | `#FFFFFF` | `#FFFFFF` | 0 |
| 顶栏 | `#FFFFFF` | `#FFFFFF` | 0 |
| 输入框卡片 | `#F1F3F7` | `#F1F3F7` | 0 |
| chips | `#FFFFFF` | `#FFFFFF` | 0 |
| 用户气泡 | `#DCE4FF` | `#DCE4FF` | 0 |
| 深色背景 | `#161920` | `#161920` | 0 |
| 深色输入框 | `#1E222B` | `#1E222B` | 0 |
| 抽屉 / 底部栏 | `#FFFFFF` | `#FFFFFF` | 0 |
| 设置页卡片 | `#FFFFFF` | `#FFFFFF` | 0 |
| 深色抽屉背景 | `#161920` | `#161920` | 0 |
| 深色抽屉底栏 | `#161920` | `#161920` | 0 |
| 深色设置页背景 | `#161920` | `#161920` | 0 |
| 深色设置页卡片 | `#161920` | `#161920` | 0 |

Flutter 侧色板定义在 `flutter_app/lib/theme/app_theme.dart`（`AppColors`），
与原生 `app/src/main/res/values/colors_m3.xml`、`values-night/colors_m3.xml` 逐项一致。

## 已知差异（有意保留）

1. **FAB**：笔记 / 记忆 / 定时任务的 Flutter 页保留了右下角新建按钮，原生侧无 FAB（新增入口在别处）。功能优先，视觉上多一个按钮。
2. **小组件**：无桌面截图——已尝试 `am start -a android.appwidget.action.APPWIDGET_PICK` 与 `cmd appwidget`，
   模拟器上均无法稳定添加 widget，目前只做布局 XML / 文案 / 颜色代码级对照；Flutter 小组件已改为与原一致的静态文案。
   如需桌面截图，请在设备桌面上长按 → 小组件 → DoDroidAI 手动添加后截图。
3. **数据差异**：Flutter 使用独立包名（`com.mohanlv.dodroidai`）与独立数据库，笔记/记忆/任务截图多为空状态，卡片样式的实际渲染可参考 `audit/`（两边都有数据）。
4. **定时任务语义**：原生列表展示「执行结果」（已完成/失败），Flutter 列表展示「启用/停用」配置状态。
