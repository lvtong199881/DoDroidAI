package com.example.dodroidai.ui.chat.adapter

/**
 * 把 Markdown 按代码块切分，用于分别渲染正文与代码块
 */
data class MarkdownSegment(
    val type: Type,
    val content: String,
    val language: String = ""
) {
    enum class Type { TEXT, CODE }
}

object MarkdownSegmenter {

    private const val FENCE = "```"
    private const val MAX_CODE_BLOCKS = 5

    fun segment(markdown: String): List<MarkdownSegment> {
        if (markdown.isBlank()) return emptyList()

        val segments = mutableListOf<MarkdownSegment>()
        val text = StringBuilder()
        val code = StringBuilder()
        var inCode = false
        var language = ""
        var codeBlockCount = 0

        fun flushText() {
            if (text.isNotBlank()) {
                segments.add(MarkdownSegment(MarkdownSegment.Type.TEXT, text.toString()))
                text.clear()
            }
        }

        markdown.lines().forEach { line ->
            val trimmed = line.trimStart()
            if (trimmed.startsWith(FENCE)) {
                if (inCode) {
                    segments.add(MarkdownSegment(MarkdownSegment.Type.CODE, code.toString(), language))
                    code.clear()
                    inCode = false
                    language = ""
                    codeBlockCount++
                } else {
                    flushText()
                    inCode = true
                    language = trimmed.removePrefix(FENCE).trim()
                }
            } else if (inCode) {
                code.appendLine(line)
            } else {
                text.appendLine(line)
            }
        }

        // 流式输出中未闭合的代码块也按代码处理
        if (inCode) {
            segments.add(MarkdownSegment(MarkdownSegment.Type.CODE, code.toString(), language))
            codeBlockCount++
        } else {
            flushText()
        }

        // 限制代码块数量，避免超长消息渲染卡顿
        if (codeBlockCount <= MAX_CODE_BLOCKS) return segments

        var seen = 0
        return segments.map { segment ->
            if (segment.type == MarkdownSegment.Type.CODE) {
                seen++
                if (seen > MAX_CODE_BLOCKS) {
                    MarkdownSegment(
                        MarkdownSegment.Type.TEXT,
                        "（代码块超出展示上限，可复制整条消息查看）"
                    )
                } else {
                    segment
                }
            } else {
                segment
            }
        }
    }
}
