package com.example.dodroidai.toolprocessor

import com.google.devtools.ksp.processing.CodeGenerator
import com.google.devtools.ksp.processing.Dependencies
import com.google.devtools.ksp.processing.KSPLogger
import com.google.devtools.ksp.processing.Resolver
import com.google.devtools.ksp.processing.SymbolProcessor
import com.google.devtools.ksp.processing.SymbolProcessorEnvironment
import com.google.devtools.ksp.processing.SymbolProcessorProvider
import com.google.devtools.ksp.symbol.KSAnnotated
import com.google.devtools.ksp.symbol.KSClassDeclaration
import com.google.devtools.ksp.symbol.KSFunctionDeclaration

/**
 * 收集所有 @ToolProvider 类，生成 `GeneratedTools.all`。
 *
 * 约定：被注解的类必须提供 `fun spec(): ToolSpec`，否则编译期报错。
 */
class ToolProviderProcessor(
    private val codeGenerator: CodeGenerator,
    private val logger: KSPLogger
) : SymbolProcessor {

    private var generated = false

    override fun process(resolver: Resolver): List<KSAnnotated> {
        // KSP 会多轮调用 process，生成文件只需一次
        if (generated) return emptyList()
        generated = true

        val annotationName = "com.example.dodroidai.ai.tools.ToolProvider"
        val classes = resolver.getSymbolsWithAnnotation(annotationName)
            .filterIsInstance<KSClassDeclaration>()
            .toList()

        val valid = classes.filter { cls ->
            val spec = cls.declarations
                .filterIsInstance<KSFunctionDeclaration>()
                .firstOrNull { fn -> fn.simpleName.asString() == "spec" && fn.parameters.isEmpty() }
            if (spec == null) {
                logger.error(
                    "@ToolProvider 类 ${cls.qualifiedName?.asString()} 必须提供无参的 fun spec(): ToolSpec",
                    cls
                )
                return@filter false
            }
            val returnType = spec.returnType?.resolve()?.declaration?.qualifiedName?.asString()
            if (returnType != "com.example.dodroidai.ai.tools.ToolSpec") {
                logger.error(
                    "${cls.qualifiedName?.asString()}.spec() 的返回类型必须是 ToolSpec，当前为 $returnType",
                    spec
                )
                return@filter false
            }
            true
        }

        val files = valid.mapNotNull { it.containingFile }.distinct()
        val output = codeGenerator.createNewFile(
            Dependencies(true, *files.toTypedArray()),
            "com.example.dodroidai.ai.tools",
            "GeneratedTools",
            "kt"
        )

        output.bufferedWriter().use { writer ->
            writer.write("package com.example.dodroidai.ai.tools\n\n")
            writer.write("// 由 tool-processor 生成，请勿手改\n")
            writer.write("internal object GeneratedTools {\n")
            writer.write("    val all: List<ToolSpec> = listOf(\n")
            valid.forEach { cls ->
                writer.write("        ${cls.qualifiedName!!.asString()}.spec(),\n")
            }
            writer.write("    )\n}\n")
        }
        return emptyList()
    }
}

class ToolProviderProcessorProvider : SymbolProcessorProvider {
    override fun create(environment: SymbolProcessorEnvironment): SymbolProcessor =
        ToolProviderProcessor(environment.codeGenerator, environment.logger)
}
