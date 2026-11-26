#!/usr/bin/env node
/**
 * 设计稿渲染器（本机版）：layouts.json → SVG + boxes.json。
 *
 * 本次会话的 <skillAssets> 未挂载，沿用项目内既有的「布局清单 → SVG」本机替代渲染器，
 * 并按本次「半露出关闭按钮 / 2 倍字号 / 滚动 / 无图」需求做了扩展：
 *   - frame.textScale / frame.scrollOffset / frame.showHero / frame.showConfigureAi / frame.closeState
 *   - node.if 条件节点、node.type='spacer'
 *   - component.closeButton：圆心钉在弹窗右上角、一半露出弹窗，绘制在弹窗裁切之外（最高层）
 * 所有坐标由 designTokens 与布局规则计算，不手写设计坐标。
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
function resolveNumber(value, theme) {
  const c = tokens.colors[theme] || {}
  return c[value] !== undefined ? c[value] : value
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
function shouldRender(node, env) {
  if (!node.if) return true
  if (node.if === 'showHero') return env.showHero !== false
  if (node.if === 'showConfigureAi') return !!env.showConfigureAi
  return true
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
    if (clip) {
      if (box.y + box.h > clip.bottom + 0.01) box.clipped = true
      if (clip.top != null && box.y < clip.top - 0.01) box.clipped = true
    }
    return box
  }

  if (node.type === 'spacer') {
    return { h: node.height || 0, ops, boxes }
  }

  if (node.type === 'text') {
    const typo = tokens.typography[node.typography]
    const scale = env.textScale || 1
    const fs = round(typo.fontSize * scale)
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
      const box = { name: node.name, type: 'text', x: round(x), y: round(y), width: round(maxW), height: round(h), fontSize: fs, lines, text }
      boxes.push(markClip(box))
    }
    return { h, ops, boxes }
  }

  if (node.type === 'image') {
    const w = node.width != null ? node.width : width
    const h = node.height != null ? node.height : node.aspectRatio ? w / node.aspectRatio : 0
    const src = node.srcRef ? (tokens.assets[theme] || {})[node.srcRef] : node.src
    if (!opts.measure) {
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
  const children = (node.children || []).filter((c) => shouldRender(c, env))

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
  const env = {
    theme,
    locale: frame.locale || 'zh',
    textScale: frame.textScale || 1,
    showHero: frame.showHero !== false,
    showConfigureAi: !!frame.showConfigureAi,
    closeState: frame.closeState || 'default',
    clip: null,
  }
  const canvas = frame.canvas
  const bg = resolveColor(frame.background && frame.background.fill, theme)
  const op = []
  op.push(`<rect width="${canvas.width}" height="${canvas.height}" fill="${bg}"/>`)
  if (frame.scrim) op.push(`<rect width="${canvas.width}" height="${canvas.height}" fill="${resolveColor('scrim', theme)}"/>`)

  const boxes = []
  let dialogBox = null
  let closeInfo = ''
  let closeShadowOpacity = 0
  const component = frame.contentRef ? spec.components[frame.contentRef] : null
  const cb = component && component.closeButton ? component.closeButton : null
  if (cb) {
    closeShadowOpacity =
      resolveNumber(cb.shadowOpacity != null ? cb.shadowOpacity : 'closeShadowOpacity', theme) *
      (env.closeState === 'pressed' ? 0.6 : 1)
  }

  if (component) {
    const node = component
    const inset = node.inset != null ? node.inset : 20
    const W = canvas.width - inset * 2
    const maxH = canvas.height * (node.maxHeightRatio || 0.8)
    const children = (node.children || []).filter((c) => shouldRender(c, env))
    const footerIdx = children.findIndex((c) => c.name === 'footer')
    const topInset = env.showHero ? 0 : node.noHeroTopInset || 0
    const heights = children.map((c) => measureOnly(c, W, env))
    const natural = heights.reduce((a, b) => a + b, 0) + topInset
    const footerH = footerIdx >= 0 ? heights[footerIdx] : 0
    const overflow = natural > maxH + 0.01
    const H = Math.min(natural, maxH)
    const y = Math.max(inset, (canvas.height - H) / 2)
    const x = inset
    const viewportH = H - footerH
    const maxOffset = Math.max(0, natural - viewportH)
    const scrollOffset = overflow ? Math.min(frame.scrollOffset || 0, maxOffset) : 0
    const contentEnv = { ...env, clip: overflow ? { top: y, bottom: y + viewportH } : null }

    const contentOps = []
    const contentBoxes = []
    let curY = y + topInset - scrollOffset
    for (let i = 0; i < children.length; i++) {
      if (i === footerIdx) continue
      if (overflow && curY >= y + viewportH - 0.01) continue
      const r = layoutNode(children[i], x, curY, W, contentEnv)
      contentOps.push(...r.ops)
      contentBoxes.push(...r.boxes)
      curY += r.h
    }

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
    if (overflow) {
      op.push(`<clipPath id="scrollClip"><rect x="${round(x)}" y="${round(y)}" width="${W}" height="${round(viewportH)}"/></clipPath>`)
      op.push(`<g clip-path="url(#scrollClip)">`)
      op.push(...contentOps)
      op.push(`</g>`)
    } else {
      op.push(...contentOps)
    }
    op.push(...footerOps)
    op.push(`</g>`)

    /* ---- 关闭按钮：圆心 = 弹窗右上角，绘制在弹窗裁切之外（最高层） ---- */
    if (cb) {
      const s = cb.size || 32
      const hs = cb.hitSize || 48
      const scale = env.closeState === 'pressed' ? cb.pressedScale || 0.94 : 1
      const vs = s * scale
      const cx = x + W
      const cy = y
      const bx = cx - vs / 2
      const by = cy - vs / 2
      const fillToken = env.closeState === 'pressed' && cb.pressedFill ? cb.pressedFill : cb.fill
      const fill = resolveColor(fillToken, theme)
      const border = resolveColor(cb.border, theme)
      const iconColor = resolveColor(cb.iconColor, theme)
      const iconHalf = (cb.iconSize || 16) / 2 - 2.5
      const sw = cb.strokeWidth || 2
      const label = resolveText('{{LOCALE}}.close', env.locale)

      op.push(`<!-- close_button: 32dp visual / 48dp hit, center pinned to dialog top-right, 50% exposed -->`)
      op.push(
        `<rect x="${round(cx - s / 2)}" y="${round(cy - s / 2)}" width="${s}" height="${s}" rx="${s / 2}" fill="${border}" filter="url(#closeShadow)"/>`
      )
      op.push(`<g><title>${esc(label)}</title>`)
      op.push(`<g transform="translate(${round(cx)} ${round(cy)}) scale(${scale}) translate(${round(-cx)} ${round(-cy)})">`)
      op.push(
        `<rect x="${round(cx - s / 2)}" y="${round(cy - s / 2)}" width="${s}" height="${s}" rx="${s / 2}" fill="${border}"/>`
      )
      op.push(
        `<rect x="${round(cx - s / 2 + 1)}" y="${round(cy - s / 2 + 1)}" width="${s - 2}" height="${s - 2}" rx="${(s - 2) / 2}" fill="${fill}"/>`
      )
      op.push(
        `<path d="M${round(cx - iconHalf)} ${round(cy - iconHalf)}L${round(cx + iconHalf)} ${round(cy + iconHalf)}M${round(cx + iconHalf)} ${round(cy - iconHalf)}L${round(cx - iconHalf)} ${round(cy + iconHalf)}" stroke="${iconColor}" stroke-width="${sw}" stroke-linecap="round" fill="none"/>`
      )
      op.push(`</g></g>`)

      boxes.push({
        name: 'close_button',
        type: 'close_button',
        x: round(bx),
        y: round(by),
        width: round(vs),
        height: round(vs),
        centerX: round(cx),
        centerY: round(cy),
        visualSize: s,
        outsideDialog: { width: round(vs / 2), height: round(vs / 2) },
        exposedPercent: { width: round((vs / 2 / vs) * 100), height: round((vs / 2 / vs) * 100) },
        state: env.closeState,
        z: 'above-dialog-clip',
      })
      boxes.push({
        name: 'close_hit_area',
        type: 'hit',
        x: round(cx - hs / 2),
        y: round(cy - hs / 2),
        width: hs,
        height: hs,
        offCanvasRight: round(Math.max(0, cx + hs / 2 - canvas.width)),
        note: '命中盒 48×48 居中于视觉按钮；右侧可越出屏幕 4dp（PRD 风险表已接受），可见部分可点',
      })
      closeInfo = `  close=${s}dp@(${round(cx)},${round(cy)})  exposed=${round((vs / 2 / vs) * 100)}%  hit=${hs}dp`
    }

    dialogBox = {
      name: 'dialog',
      type: 'dialog',
      x: round(x),
      y: round(y),
      width: W,
      height: round(H),
      naturalHeight: round(natural),
      overflow,
      scrollOffset: round(scrollOffset),
      scrolled: overflow ? { viewportHeight: round(viewportH), offset: round(scrollOffset) } : null,
    }
    boxes.push(dialogBox)
    boxes.push(...contentBoxes, ...footerBoxes)
  }

  const svg = [
    `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${canvas.width}" height="${canvas.height}" viewBox="0 0 ${canvas.width} ${canvas.height}">`,
    `<defs><filter id="dlgShadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="8" stdDeviation="12" flood-color="#000000" flood-opacity="${theme === 'dark' ? 0.55 : 0.18}"/></filter>`,
    cb
      ? `<filter id="closeShadow" x="-80%" y="-80%" width="260%" height="260%"><feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#000000" flood-opacity="${round(closeShadowOpacity)}"/></filter>`
      : '',
    `</defs>`,
    ...op,
    `</svg>`,
    ``,
  ].join('\n')
  return { svg, boxes, dialogBox, closeInfo }
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
  const { svg, boxes, dialogBox, closeInfo } = renderFrame(frame)
  fs.writeFileSync(path.join(outDir, `${frame.id}.svg`), svg)
  allBoxes[frame.id] = boxes

  const cw = frame.canvas.width
  const ch = frame.canvas.height
  for (const b of boxes) {
    if (b.type === 'hit') continue
    // 滚动帧中被滚动视口裁掉的内容盒，超出画布是预期行为，不算溢出
    if (b.clipped) continue
    if (b.x < -0.01 || b.y < -0.01 || b.x + b.width > cw + 0.01 || b.y + b.height > ch + 0.01) {
      warnings.push(`${frame.id}: ${b.name} 超出画布 (${b.x},${b.y},${b.width}x${b.height})`)
    }
    if (b.type === 'text') {
      const maxLine = Math.max(0, ...b.lines.map((l) => round(measureText(l, b.fontSize || 15))))
      if (maxLine > b.width + 0.5) warnings.push(`${frame.id}: 文本 ${b.name} 行宽 ${maxLine} > 容器 ${b.width}`)
    }
  }
  // 关闭按钮与文字/底部按钮不得相交（AC-6、AC-8）；与欢迎图重叠是预期层级
  const closeBox = boxes.find((b) => b.type === 'close_button')
  if (closeBox) {
    const noTouch = boxes.filter((b) => b.type === 'text' || b.name === 'primary_button' || b.name === 'secondary_button')
    for (const b of noTouch) {
      const intersects =
        closeBox.x < b.x + b.width && b.x < closeBox.x + closeBox.width && closeBox.y < b.y + b.height && b.y < closeBox.y + closeBox.height
      if (intersects) warnings.push(`${frame.id}: close_button 与 ${b.name} 相交`)
    }
    const pct = closeBox.exposedPercent
    if (pct.width < 45 || pct.width > 55 || pct.height < 45 || pct.height > 55) {
      warnings.push(`${frame.id}: close_button 露出比例 ${pct.width}%/${pct.height}% 不在 45%–55%`)
    }
  }
  if (dialogBox) {
    if (dialogBox.y < 0 || dialogBox.y + dialogBox.height > ch + 0.01) {
      warnings.push(`${frame.id}: 弹窗超出画布`)
    }
    console.log(
      `  ${frame.id}  canvas=${cw}x${ch}  dialog=${dialogBox.width}x${dialogBox.height}@(${dialogBox.x},${dialogBox.y})  natural=${dialogBox.naturalHeight}  overflow=${dialogBox.overflow}${closeInfo}`
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
