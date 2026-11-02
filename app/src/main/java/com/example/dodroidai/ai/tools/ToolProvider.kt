package com.example.dodroidai.ai.tools

/**
 * 标记一个工具类由 KSP 自动注册。
 *
 * 约定：被注解的类必须是 object（或带无参构造的类），并提供 `fun spec(): ToolSpec`。
 */
@Target(AnnotationTarget.CLASS)
@Retention(AnnotationRetention.SOURCE)
annotation class ToolProvider
