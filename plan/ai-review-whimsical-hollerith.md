# AI Review Skill 实现方案

## 背景

在我修改完代码后自动触发检查，发现问题自动修复。沉淀为通用 skill，所有 Android 项目均可使用。

## 工具选型

| 工具 | 用途 | 自动修复 |前提 |
|------|------|---------|------|
| **ktlint** | Kotlin 风格、格式 | 支持 | 项目需已配置，若无则跳过 |
| **Android Lint** | Android 特定问题 | 部分支持 | 始终运行 |

## Skill 设计

### Skill名称
`android-review`

### 核心功能
1. **智能检测**: 检测项目是否已配置 ktlint
2. **按需集成**: 若未配置，询问用户是否要集成；用户拒绝则跳过 ktlint
3. **自动检查**: 修改文件后自动运行检查
4. **自动修复**: 支持自动修复可修复的问题
5. **结果输出**: 输出符合 Android Studio 格式的检查结果

### 参数
| 参数 | 类型 | 说明 |
|------|------|------|
| `autoFix` | boolean | 是否自动修复，默认 true |
| `changedOnly` | boolean | 是否仅检查改动文件，默认 true |

## 实现方案

### 1. 创建 Skill 文件

```
~/.claude/skills/android-review/
├── skill.md           # Skill 定义
└── hooks/
    └── afterEdit.sh   # after-edit hook 脚本
```

### 2. Hook 脚本逻辑

**文件**: `~/.claude/skills/android-review/hooks/afterEdit.sh`
```bash
#!/bin/bash
# after-edit hook: 修改文件后自动运行 lint 检查

AUTO_FIX="${autoFix:-true}"
CHANGED_ONLY="${changedOnly:-true}"

cd "$PROJECT_DIR"

# 智能检测 ktlint 是否可用
KTlint_ENABLED=false
if [ -f "gradlew" ]; then
    if ./gradlew tasks --all 2>/dev/null | grep -q "ktlintCheck"; then
        KTlint_ENABLED=true
    fi
fi

# ktlint 检查（仅当已配置时）
if [ "$KTLINT_ENABLED" = "true" ]; then
    if [ "$CHANGED_ONLY" = "true" ]; then
        ./gradlew ktlintCheck --changed --auto-correct 2>/dev/null
    else
        ./gradlew ktlintCheck --auto-correct 2>/dev/null
    fi
fi

# Android Lint 检查（始终运行）
if [ "$CHANGED_ONLY" = "true" ]; then
    ./gradlew lintDebug --changed 2>/dev/null
else
    ./gradlew lintDebug 2>/dev/null
fi
```

### 3. Skill 安装流程

1. 检测项目是否已有 ktlint 配置
2. 若无，提示用户是否要集成 ktlint
3. **若用户拒绝**:跳过 ktlint 配置，后续只运行 Android Lint
4. **若用户确认**: 自动配置 ktlint 依赖
5. 注册 after-edit hook

### 4. 安装检测逻辑

```bash
# 检测项目类型
is_android_project() {
    [ -f "app/build.gradle.kts" ] && [ -f "gradlew" ]
}

# 检测 ktlint 是否已配置
has_ktlint() {
    ./gradlew tasks --all 2>/dev/null | grep -q "ktlintCheck"
}

# 主流程
if is_android_project; then
    if has_ktlint; then
        echo "ktlint already configured, enabling review"
        register_hook
    else
        echo "ktlint not found. Configure now? (y/n)"
        read answer
        if [ "$answer" = "y" ]; then
            integrate_ktlint
            register_hook
        else
            echo "Skipping ktlint, will only run Android Lint"
            register_hook
        fi
    fi
fi
```

## 关键文件

| 文件 | 位置 |
|------|------|
| Skill 定义 | `~/.claude/skills/android-review/skill.md` |
| Hook 脚本 | `~/.claude/skills/android-review/hooks/afterEdit.sh` |
| 项目配置（可选）| `gradle/libs.versions.toml`, `build.gradle.kts`, `app/build.gradle.kts` |
| 规则配置（可选）| `.ktlint`, `.editorconfig` |

## 验证方式

1. 修改 Kotlin 文件后自动触发检查
2. 有 ktlint → 运行 ktlint + Android Lint；无 ktlint → 仅运行 Android Lint
3. 检查结果符合 Android Studio 显示规范
4. 可修复问题自动修复，无需手动介入