#!/usr/bin/env node
/**
 * 本机替代渲染器：读取 design/layouts.json，自动排版并输出 SVG + boxes.json。
 *
 * 说明：设计卡指定的 svggen.cjs 在本次会话的 <skillAssets> 中不可用（见设计说明 §8），
 * 因此在本机复刻同一份「布局清单 → SVG」管线：坐标全部由本脚本按 token/约束计算，
 * 不手写任何设计坐标；输出目录、文件命名、boxes 结构与项目金标准保持一致。
 *
 * 用法：node svggen.cjs <layouts.json> <svg 输出目录> --json=<boxes.json>
 */
'use strict'
const fs = require('fs')
const path = require('path')

const args = process.argv.slice(2)
const input = args[0]
const outDir = args[1]
const jsonArg = args.find((a) => a.startsWith('--json='))
const boxesOut = jsonArg ? jsonArg.slice('--json='.length) : null
if (!input || !outDir) {
  console.error('用法：node svggen.cjs <layouts.json> <svg 输出目录> [--json=<boxes.json>]')
  process.exit(2)
}

const spec = JSON.parse(fs.readFileSync(input, 'utf8'))
const tokens = spec.designTokens
const previewStack = tokens.fonts.preview.stack

/* ---------- 文本度量（无浏览器环境下的稳定近似） ---------- */
const CJK = /[\u2E80-\u9FFF\u3000-\u303F\uFF00-\uFFEF]/
function charWidth(ch, fs) {
  if (CJK.test(ch)) return fs * 1.0
  if (ch === ' ') return fs * 0.26
  if (/[A-Z]/.test(ch)) return fs * 0.64
  if (/[a-z0-9]/.test(ch)) return fs * 0.545
  if (/[.,:;'!|]/.test(ch)) return fs * 0.27
  if (/[()[\]{}]/.test(ch)) return fs * 0.33
  return fs * 0.52
}
function measureText(text, fs) {
  let w = 0
  for (const ch of text) w += charWidth(ch, fs)
  return w
}
function wrapText(text, fs, maxW) {
  const raw = text.match(/[\u2E80-\u9FFF\u3000-\u303F\uFF00-\uFFEF]|[^\s\u2E80-\u9FFF\u3000-\u303F\uFF00-\uFFEF]+|\s+/g) || []
  const spaceW = fs * 0.26
  const lines = []
  let line = ''
  let lineW = 0
  let pendingSpace = false
  const pushLine = () => {
    lines.push(line)
    line = ''
    lineW = 0
    pendingSpace = false
  }
  for (const tok of raw) {
    if (/^\s+$/.test(tok)) {
      if (line) pendingSpace = true
      continue
    }
    const tw = measureText(tok, fs)
    if (tw > maxW && tok.length > 1) {
      // 超长单词：按字符硬切，避免溢出
      for (const ch of tok) {
        const cw = charWidth(ch, fs)
        if (line && lineW + (pendingSpace ? spaceW : 0) + cw > maxW) pushLine()
        const addSpace = pendingSpace && line
        line += (addSpace ? ' ' : '') + ch
        lineW += (addSpace ? spaceW : 0) + cw
        pendingSpace = false
      }
      continue
    }
    const need = lineW + (pendingSpace ? spaceW : 0) + tw
    if (line && need > maxW) pushLine()
    if (!line) {
      line = tok
      lineW = tw
    } else {
      line += (pendingSpace ? ' ' : '') + tok
      lineW += (pendingSpace ? spaceW : 0) + tw
    }
    pendingSpace = false
  }
  if (line || !lines.length) lines.push(line)
  return lines
}

/* ---------- token 解析 ---------- */
function resolveColor(value, theme) {
  if (!value) return null
  if (value === 'transparent' || value === 'none') return value
  const c = tokens.colors[theme] || {}
  return c[value] || value
}
function resolveText(textRef, locale) {
  const key = textRef.replace('{{LOCALE}}', locale)
  const [loc, ...rest] = key.split('.')
  const k = rest.join('.')
  return (spec.copy[loc] && spec.copy[loc][k]) || key
}
function normalizePad(p) {
  if (p == null) return [0, 0, 0, 0]
  if (typeof p === 'number') return [p, p, p, p]
  return p
}
function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}
function round(n) {
  return Math.round(n * 100) / 100
}

/* ---------- 布局 ---------- */
function measureOnly(node, width, env) {
  const r = layoutNode(node, 0, 0, width, env, { measure: true })
  return r.h
}

function layoutNode(node, x, y, width, env, opts = {}) {
  const theme = env.theme
  const ops = []
  const boxes = []
  const clip = env.clip || null
  const markClip = (box) => {
    if (clip && box.y + box.h > clip.bottom + 0.01) box.clipped = true
    return box
  }

  if (node.type === 'text') {
    const typo = tokens.typography[node.typography]
    const fs = typo.fontSize
    const lh = fs * typo.lineHeight
    const color = resolveColor(node.colorToken || typo.colorToken, theme)
    const text = resolveText(node.textRef, env.locale)
    const align = node.align || 'left'
    const maxW = node.width != null ? node.width : width
    const lines = wrapText(text, fs, maxW)
    const h = lines.length * lh
    if (!opts.measure) {
      const anchor = align === 'center' ? 'middle' : align === 'right' ? 'end' : 'start'
      const tx = align === 'center' ? x + maxW / 2 : align === 'right' ? x + maxW : x
      lines.forEach((line, i) => {
        const baseline = y + (lh - fs) / 2 + fs * 0.86 + i * lh
        ops.push(
          `<text x="${round(tx)}" y="${round(baseline)}" font-family="${esc(previewStack)}" font-size="${fs}" font-weight="${typo.fontWeight}" fill="${color}" text-anchor="${anchor}">${esc(line)}</text>`
        )
      })
      const box = { name: node.name, type: 'text', x: round(x), y: round(y), width: round(maxW), height: round(h), fontSize: fs, lines, text: text }
      boxes.push(markClip(box))
    }
    return { h, ops, boxes }
  }

  if (node.type === 'image') {
    const w = node.width != null ? node.width : width
    const h = node.height != null ? node.height : node.aspectRatio ? w / node.aspectRatio : 0
    const src = node.srcRef ? (tokens.assets[theme] || {})[node.srcRef] : node.src
    if (!opts.measure) {
      // 素材自带透明圆角大于弹窗 16dp 时，用同色底补齐，避免露出白色棱边
      if (node.backdrop) {
        ops.push(
          `<rect x="${round(x)}" y="${round(y)}" width="${round(w)}" height="${round(h)}" fill="${resolveColor(node.backdrop, theme)}"/>`
        )
      }
      ops.push(
        `<image href="${esc(src)}" x="${round(x)}" y="${round(y)}" width="${round(w)}" height="${round(h)}" preserveAspectRatio="xMidYMid slice"/>`
      )
      boxes.push(markClip({ name: node.name, type: 'image', x: round(x), y: round(y), width: round(w), height: round(h), src }))
    }
    return { h, ops, boxes }
  }

  if (node.type === 'rect') {
    const w = node.width != null ? node.width : width
    const h = node.height || 0
    if (!opts.measure) {
      ops.push(
        `<rect x="${round(x)}" y="${round(y)}" width="${round(w)}" height="${round(h)}" rx="${node.radius || 0}" fill="${resolveColor(node.fill, theme) || 'none'}"/>`
      )
      boxes.push(markClip({ name: node.name, type: 'rect', x: round(x), y: round(y), width: round(w), height: round(h) }))
    }
    return { h, ops, boxes }
  }

  // frame
  const pad = normalizePad(node.layout && node.layout.padding)
  const spacing = (node.layout && node.layout.spacing) || 0
  const align = (node.layout && node.layout.align) || 'stretch'
  const justify = (node.layout && node.layout.justify) || 'start'
  const contentW = width - pad[1] - pad[3]
  const children = node.children || []

  // 先量高度
  const heights = children.map((c) => measureOnly(c, contentW, { ...env, clip: null }))
  let contentH = heights.reduce((a, b) => a + b, 0) + spacing * Math.max(0, children.length - 1)
  let h = node.height != null ? Math.max(node.height, pad[0] + contentH + pad[2]) : pad[0] + contentH + pad[2]
  if (node.height != null) h = node.height

  if (!opts.measure) {
    const hasFill = node.fill && node.fill !== 'transparent' && node.fill !== 'none'
    if (hasFill || node.stroke) {
      const fill = hasFill ? resolveColor(node.fill, theme) : 'none'
      const stroke = node.stroke ? resolveColor(node.stroke, theme) : null
      const sw = node.strokeWidth || 0
      const strokeAttr = stroke ? ` stroke="${stroke}" stroke-width="${sw}"` : ''
      ops.push(
        `<rect x="${round(x)}" y="${round(y)}" width="${round(width)}" height="${round(h)}" rx="${node.radius || 0}" fill="${fill}"${strokeAttr}/>`
      )
    }
    const innerH = h - pad[0] - pad[2]
    let curY = y + pad[0]
    if (justify === 'center') curY = y + pad[0] + Math.max(0, (innerH - contentH) / 2)
    if (justify === 'end') curY = y + pad[0] + Math.max(0, innerH - contentH)
    for (let i = 0; i < children.length; i++) {
      const child = children[i]
      const cw = contentW
      const r = layoutNode(child, x + pad[3], curY, cw, { ...env, clip: null })
      ops.push(...r.ops)
      boxes.push(...r.boxes)
      curY += r.h + spacing
    }
    boxes.push(markClip({ name: node.name, type: 'frame', x: round(x), y: round(y), width: round(width), height: round(h) }))
  }
  return { h, ops, boxes }
}

/* ---------- 单帧渲染 ---------- */
function renderFrame(frame) {
  const theme = frame.theme
  const env = { theme, locale: frame.locale || 'zh', clip: null }
  const canvas = frame.canvas
  const bg = resolveColor(frame.background && frame.background.fill, theme)
  const op = []
  op.push(`<rect width="${canvas.width}" height="${canvas.height}" fill="${bg}"/>`)
  if (frame.scrim) op.push(`<rect width="${canvas.width}" height="${canvas.height}" fill="${resolveColor('scrim', theme)}"/>`)

  const boxes = []
  let dialogBox = null

  if (frame.contentRef) {
    const node = spec.components[frame.contentRef]
    const inset = node.inset != null ? node.inset : 20
    const W = canvas.width - inset * 2
    const maxH = canvas.height * (node.maxHeightRatio || 0.8)
    const children = node.children || []
    const footerIdx = children.findIndex((c) => c.name === 'footer')
    const heights = children.map((c) => measureOnly(c, W, env))
    const natural = heights.reduce((a, b) => a + b, 0)
    const footerH = footerIdx >= 0 ? heights[footerIdx] : 0
    const overflow = natural > maxH
    const H = Math.min(natural, maxH)
    const y = Math.max(inset, (canvas.height - H) / 2)
    const x = inset
    const viewportH = H - footerH
    const scrollClip = overflow

    const contentOps = []
    const contentBoxes = []
    let curY = y
    children.forEach((child, i) => {
      if (i === footerIdx) return
      // 滚动起点：完全落在视口下方的块不进入本帧（真机需滚动才可见）
      if (scrollClip && curY >= y + viewportH - 0.01) return
      const r = layoutNode(child, x, curY, W, env)
      if (r.boxes.some((b) => b.y + b.height > y + viewportH + 0.01)) {
        r.boxes.forEach((b) => {
          if (b.y + b.height > y + viewportH + 0.01) b.clipped = true
        })
      }
      contentOps.push(...r.ops)
      contentBoxes.push(...r.boxes)
      curY += r.h
    })

    let footerOps = []
    let footerBoxes = []
    if (footerIdx >= 0) {
      const fy = overflow ? y + H - footerH : curY
      const r = layoutNode(children[footerIdx], x, fy, W, env)
      footerOps = r.ops
      footerBoxes = r.boxes
    }

    op.push(
      `<rect x="${round(x)}" y="${round(y)}" width="${W}" height="${round(H)}" rx="${node.radius || 16}" fill="${resolveColor('surface', theme)}" filter="url(#dlgShadow)"/>`
    )
    op.push(`<clipPath id="dlgClip"><rect x="${round(x)}" y="${round(y)}" width="${W}" height="${round(H)}" rx="${node.radius || 16}"/></clipPath>`)
    op.push(`<g clip-path="url(#dlgClip)">`)
    if (scrollClip) {
      op.push(`<clipPath id="scrollClip"><rect x="${round(x)}" y="${round(y)}" width="${W}" height="${round(viewportH)}"/></clipPath>`)
      op.push(`<g clip-path="url(#scrollClip)">`)
      op.push(...contentOps)
      op.push(`</g>`)
    } else {
      op.push(...contentOps)
    }
    op.push(...footerOps)
    op.push(`</g>`)

    dialogBox = {
      name: 'dialog',
      type: 'dialog',
      x: round(x),
      y: round(y),
      width: W,
      height: round(H),
      naturalHeight: round(natural),
      overflow: overflow,
      scrolled: overflow ? { viewportHeight: round(viewportH), offset: 0 } : null,
    }
    boxes.push(dialogBox)
    boxes.push(...contentBoxes, ...footerBoxes)
  }

  const svg = [
    `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${canvas.width}" height="${canvas.height}" viewBox="0 0 ${canvas.width} ${canvas.height}">`,
    `<defs><filter id="dlgShadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="8" stdDeviation="12" flood-color="#000000" flood-opacity="${theme === 'dark' ? 0.55 : 0.18}"/></filter></defs>`,
    ...op,
    `</svg>`,
    ``,
  ].join('\n')
  return { svg, boxes, dialogBox }
}

/* ---------- 帧展开（variants 自动派生） ---------- */
function expandFrames(frames) {
  const out = []
  for (const f of frames) {
    const { variants, ...base } = f
    out.push(base)
    if (variants) {
      for (const v of variants) {
        const { id, ...rest } = v
        out.push({ ...base, ...rest, id, variants: undefined })
      }
    }
  }
  return out.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
}

/* ---------- 主流程 ---------- */
fs.mkdirSync(outDir, { recursive: true })
const frames = expandFrames(spec.frames)
const allBoxes = {}
const warnings = []
for (const frame of frames) {
  const { svg, boxes, dialogBox } = renderFrame(frame)
  fs.writeFileSync(path.join(outDir, `${frame.id}.svg`), svg)
  allBoxes[frame.id] = boxes

  const cw = frame.canvas.width
  const ch = frame.canvas.height
  for (const b of boxes) {
    if (b.x < -0.01 || b.y < -0.01 || b.x + b.width > cw + 0.01 || b.y + b.height > ch + 0.01) {
      warnings.push(`${frame.id}: ${b.name} 超出画布 (${b.x},${b.y},${b.width}x${b.height})`)
    }
    if (b.type === 'text') {
      const maxLine = Math.max(0, ...b.lines.map((l) => round(measureText(l, b.fontSize || 15))))
      if (maxLine > b.width + 0.5) warnings.push(`${frame.id}: 文本 ${b.name} 行宽 ${maxLine} > 容器 ${b.width}`)
    }
  }
  if (dialogBox) {
    if (dialogBox.y < 0 || dialogBox.y + dialogBox.height > ch + 0.01) {
      warnings.push(`${frame.id}: 弹窗超出画布`)
    }
    console.log(
      `  ${frame.id}  canvas=${cw}x${ch}  dialog=${dialogBox.width}x${dialogBox.height}@(${dialogBox.x},${dialogBox.y})  natural=${dialogBox.naturalHeight}  overflow=${dialogBox.overflow}`
    )
  } else {
    console.log(`  ${frame.id}  canvas=${cw}x${ch}  (无弹窗)`)
  }
}

if (boxesOut) {
  fs.mkdirSync(path.dirname(path.resolve(boxesOut)), { recursive: true })
  fs.writeFileSync(boxesOut, JSON.stringify(allBoxes, null, 2) + '\n')
}
console.log(`\n渲染完成：${frames.length} 帧 → ${outDir}`)
if (warnings.length) {
  console.log('\n[警告]')
  for (const w of warnings) console.log('  ! ' + w)
  process.exitCode = 1
} else {
  console.log('几何自查：无溢出/超容器')
}
