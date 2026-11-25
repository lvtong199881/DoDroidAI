#!/usr/bin/env node
/**
 * SVG → PNG 栅格化（本机替代：Chrome 无头在沙箱内被命名管道限制，改用 @resvg/resvg-js）。
 * 同一份 SVG、同样 scale、透明底；SVG 仍是唯一设计源。
 *
 * 用法：node svg2png.cjs <svg 目录或单个 .svg> <png 输出目录> [--scale=3]
 */
'use strict'
const fs = require('fs')
const path = require('path')
const { Resvg } = require('@resvg/resvg-js')

const src = process.argv[2]
const outDir = process.argv[3]
const scale = Number((process.argv.find((a) => a.startsWith('--scale=')) ?? '--scale=3').split('=')[1]) || 3
if (!src || !outDir) {
  console.error('用法：node svg2png.cjs <svg 目录或单个 .svg> <png 输出目录> [--scale=3]')
  process.exit(2)
}

const MIME = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.svg': 'image/svg+xml' }
function inlineImages(svgText, baseDir) {
  return svgText.replace(/(href|xlink:href)="([^"]+)"/g, (all, k, ref) => {
    if (/^(data:|https?:|#)/.test(ref)) return all
    const abs = path.resolve(baseDir, ref)
    if (!fs.existsSync(abs)) {
      console.error(`  ! 缺图 ${ref}`)
      return all
    }
    const mime = MIME[path.extname(abs).toLowerCase()] || 'application/octet-stream'
    const b64 = fs.readFileSync(abs).toString('base64')
    return `${k}="data:${mime};base64,${b64}"`
  })
}

const files = fs.statSync(src).isDirectory()
  ? fs.readdirSync(src).filter((f) => f.endsWith('.svg')).map((f) => path.join(src, f))
  : [src]

fs.mkdirSync(outDir, { recursive: true })
for (const f of files) {
  const raw = fs.readFileSync(f, 'utf8')
  const head = raw.slice(0, 3000)
  const w = Math.round(Number(/<svg[^>]*\swidth="([\d.]+)"/.exec(head)[1]))
  const h = Math.round(Number(/<svg[^>]*\sheight="([\d.]+)"/.exec(head)[1]))
  const svg = inlineImages(raw, path.dirname(path.resolve(f)))
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: w * scale },
    background: 'rgba(0,0,0,0)',
    font: {
      loadSystemFonts: true,
      defaultFontFamily: 'Microsoft YaHei',
      serifFamily: 'Microsoft YaHei',
      sansSerifFamily: 'Microsoft YaHei',
    },
  })
  const png = resvg.render().asPng()
  const out = path.join(outDir, path.basename(f).replace(/\.svg$/, '.png'))
  fs.writeFileSync(out, png)
  console.log(`  ${path.basename(out)}  ${w * scale}x${h * scale}  ${(png.length / 1024).toFixed(1)}KB`)
}
