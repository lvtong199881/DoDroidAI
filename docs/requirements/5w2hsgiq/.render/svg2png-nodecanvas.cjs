// 沙箱内 Chrome 起不来（命名管道被禁），用 node-canvas 复刻 svg2png.cjs 的栅格化行为：
// 同一份 SVG 源码、同样的 scale、透明底；仅替换渲染引擎。
'use strict'
const fs = require('fs')
const path = require('path')
const { createCanvas, loadImage } = require('canvas')

const src = process.argv[2]
const outDir = process.argv[3]
const scale = Number((process.argv.find((a) => a.startsWith('--scale=')) ?? '--scale=3').split('=')[1]) || 3
if (!src || !outDir) {
  console.error('用法：node svg2png-nodecanvas.cjs <svg 目录或单个 .svg> <png 输出目录> [--scale=3]')
  process.exit(2)
}

const MIME = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.svg': 'image/svg+xml' }
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

async function main() {
  const files = fs.statSync(src).isDirectory()
    ? fs.readdirSync(src).filter((f) => f.endsWith('.svg')).map((f) => path.join(src, f))
    : [src]
  fs.mkdirSync(outDir, { recursive: true })
  for (const f of files) {
    const raw = fs.readFileSync(f, 'utf8')
    const head = raw.slice(0, 2000)
    const w = Math.round(Number(/<svg[^>]*\swidth="([\d.]+)"/.exec(head)[1]))
    const h = Math.round(Number(/<svg[^>]*\sheight="([\d.]+)"/.exec(head)[1]))
    const svg = inlineImages(raw, path.dirname(path.resolve(f)))
    const img = await loadImage(Buffer.from(svg))
    const canvas = createCanvas(w * scale, h * scale)
    const ctx = canvas.getContext('2d')
    ctx.scale(scale, scale)
    ctx.drawImage(img, 0, 0, w, h)
    const out = path.join(outDir, path.basename(f).replace(/\.svg$/, '.png'))
    fs.writeFileSync(out, canvas.toBuffer('image/png'))
    console.log(`  ${path.basename(out)}  ${w * scale}x${h * scale}`)
  }
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
