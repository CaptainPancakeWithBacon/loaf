// "Seem busy": the same browser work in any desktop, for measuring power in use instead of idle.
// Chrome (own throwaway profile, local files only, no network) with three tabs: two long pages that scroll
// themselves while visible and a 1080p video; every 15 s the next tab comes to the front.
// Usage: node tools/busy.mjs SECONDS   (tools/busy-baseline.sh runs it next to the power measurement)
import { spawn, execFileSync } from 'node:child_process'
import { mkdirSync, writeFileSync, existsSync } from 'node:fs'
import { homedir } from 'node:os'

const secs = Number(process.argv[2] || 400)
const dir = `${homedir()}/.cache/loaf/busy`
const port = 9444
const sleep = ms => new Promise(r => setTimeout(r, ms))
mkdirSync(dir, { recursive: true })

// a long page, made up of numbered paragraphs and coloured blocks, scrolling itself while visible
const words = 'bread crust oven flour proof knead rise bake loaf crumb warm slow quiet nap paper ink'.split(' ')
let body = ''
for (let i = 0; i < 400; i++) {
  body += `<h2>Part ${i + 1}</h2><p>${Array.from({ length: 90 }, (_, j) => words[(i * 7 + j * 3) % words.length]).join(' ')}.</p>`
  if (i % 4 === 0) body += `<div style="height:240px;border-radius:18px;background:linear-gradient(${i * 9}deg,#d5cdbe,#6e6a62)"></div>`
}
const page = `<!doctype html><meta charset=utf-8><title>busy</title>
<body style="font:17px/1.6 sans-serif;max-width:760px;margin:40px auto;padding:0 20px">${body}
<script>(function tick(){ if (!document.hidden) { scrollBy(0, 4); if (innerHeight + scrollY >= document.body.scrollHeight) scrollTo(0, 0) } requestAnimationFrame(tick) })()</script>`
writeFileSync(`${dir}/page.html`, page)
if (!existsSync(`${dir}/video.mp4`))  // 60 s of moving test picture, H.264 1080p30, made once
  execFileSync('ffmpeg', ['-loglevel', 'error', '-f', 'lavfi', '-i', 'testsrc2=size=1920x1080:rate=30', '-t', '60',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'veryfast', `${dir}/video.mp4`])
writeFileSync(`${dir}/video.html`, `<!doctype html><title>video</title><body style="margin:0;background:#000">
<video src="video.mp4" autoplay muted loop style="width:100vw;height:100vh"></video>`)

const chrome = spawn('google-chrome', [
  `--user-data-dir=${dir}/profile`, `--remote-debugging-port=${port}`, '--no-first-run', '--no-default-browser-check',
  '--ozone-platform-hint=auto', '--start-maximized', '--autoplay-policy=no-user-gesture-required', '--hide-crash-restore-bubble',
  `file://${dir}/page.html`, `file://${dir}/video.html`, `file://${dir}/page.html#2`,
], { stdio: 'ignore', detached: true })  // own process group: google-chrome is a wrapper script
const stop = () => { try { process.kill(-chrome.pid) } catch {} process.exit(0) }
process.on('SIGTERM', stop); process.on('SIGINT', stop)

let tabs = []
for (let i = 0; i < 40 && tabs.length < 3; i++) {
  await sleep(500)
  try { tabs = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).filter(t => t.type === 'page') } catch {}
}
if (tabs.length < 3) { console.error('chrome did not open its three tabs'); stop() }

const end = Date.now() + secs * 1000
for (let i = 0; Date.now() < end; i++) {
  await fetch(`http://127.0.0.1:${port}/json/activate/${tabs[i % 3].id}`).catch(() => {})
  await sleep(15000)
}
stop()
