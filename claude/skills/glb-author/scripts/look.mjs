// Render a GLB to a labeled PNG sheet in headless Chromium (software WebGL, no GPU needed), then Read the PNG.
// Usage: node look.mjs model.glb [--sheet geo|diag|anim] [--clip Walk] [--frames 8] [--t 0.5] [--zoom nodeName]
//                     [--view front|back|left|right|top|bottom|34|34back  (geo: comma list)]  (left = model's left = +X) [--out file.png]
//   geo  (default) 6 views, lit: FRONT RIGHT 3/4 / BACK LEFT TOP. Grid at y=0, orange bbox.
//   diag normals (magenta = hole or flipped face), clay, wireframe, node axes + labels for empties/sockets/bones.
//   anim filmstrip of --frames poses of --clip from --view (default right).
// Writes <glb dir>/look/<name>-<sheet>[-clip][-zoom].png; the previous render is kept as ...-prev.png for before/after.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const THREE_DIR = path.join(HERE, '..', 'node_modules', 'three');
const argv = process.argv.slice(2);
const opt = k => { const i = argv.indexOf(`--${k}`); return i >= 0 ? argv[i + 1] : undefined; };
const file = argv.find((a, i) => !a.startsWith('--') && !(argv[i - 1] || '').startsWith('--'));
if (!file || !fs.existsSync(file)) { console.error('usage: node look.mjs model.glb [--sheet geo|diag|anim] [--clip name] [--frames 8] [--t sec] [--zoom node] [--view v] [--out png]'); process.exit(2); }
const name = path.basename(file, path.extname(file));
const L = { name, sheet: opt('sheet') || 'geo', clip: opt('clip'), t: opt('t') != null ? +opt('t') : undefined, frames: opt('frames') ? +opt('frames') : undefined, zoom: opt('zoom'), view: opt('view') };
const out = opt('out') || path.join(path.dirname(file), 'look', [name, L.sheet, L.clip, L.zoom, L.t != null && L.sheet !== 'anim' ? `t${L.t}` : null].filter(Boolean).join('-') + '.png');

async function launch() {
  try { return await chromium.launch(); } catch (e) {
    if (!/Executable doesn't exist/.test(e.message)) throw e;
    // Playwright wants a browser build that isn't downloaded: use the newest one that is.
    const cache = process.env.PLAYWRIGHT_BROWSERS_PATH || path.join(os.homedir(), '.cache', 'ms-playwright');
    const found = (fs.existsSync(cache) ? fs.readdirSync(cache) : [])
      .map(d => [d, d.startsWith('chromium_headless_shell-') ? path.join(cache, d, 'chrome-headless-shell-linux64', 'chrome-headless-shell') : d.startsWith('chromium-') ? path.join(cache, d, 'chrome-linux64', 'chrome') : null])
      .filter(([, p]) => p && fs.existsSync(p))
      .sort((a, b) => (b[0].includes('headless') - a[0].includes('headless')) || (+b[0].split('-').pop() - +a[0].split('-').pop()));
    const exe = process.env.GLB_AUTHOR_CHROME || found[0]?.[1];
    if (!exe) throw new Error('no Chromium found: run `npx playwright install chromium-headless-shell` in the skill folder');
    return chromium.launch({ executablePath: exe });
  }
}

const t0 = Date.now();
const browser = await launch();
try {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await page.route('http://look.local/**', route => {
    const u = new URL(route.request().url()).pathname;
    let p, type = 'application/octet-stream';
    if (u === '/page.html') { p = path.join(HERE, 'page.html'); type = 'text/html'; }
    else if (u === '/model.glb') p = path.resolve(file);
    else if (u.startsWith('/three/')) { p = path.join(THREE_DIR, u.slice(7)); type = 'text/javascript'; }
    if (!p || !fs.existsSync(p)) return route.fulfill({ status: 404, body: '' });
    return route.fulfill({ status: 200, contentType: type, body: fs.readFileSync(p) });
  });
  await page.addInitScript(o => { window.LOOK = o; }, L);
  const pageFailed = new Promise(r => page.on('pageerror', e => r({ fail: e.message })));
  await page.goto('http://look.local/page.html');
  const res = await Promise.race([page.waitForFunction(() => window.__done, null, { timeout: 60000 }).then(h => h.jsonValue()), pageFailed])
    .catch(e => ({ fail: errors.join('\n') || e.message }));
  if (!res?.png) { console.error(`look failed: ${res?.fail || errors.join('\n')}`); process.exit(1); }
  fs.mkdirSync(path.dirname(out), { recursive: true });
  if (fs.existsSync(out)) fs.renameSync(out, out.replace(/\.png$/, '-prev.png'));
  fs.writeFileSync(out, Buffer.from(res.png.split(',')[1], 'base64'));
  const prev = out.replace(/\.png$/, '-prev.png');
  console.log(`wrote ${out}${fs.existsSync(prev) ? `  (previous: ${prev})` : ''}`);
  console.log(`  ${L.sheet} sheet, bbox min [${res.bbox.min.map(v => v.toFixed(2))}] max [${res.bbox.max.map(v => v.toFixed(2))}], grid cell ${res.cell} m, ${res.tris} tris${L.sheet === 'diag' ? `, labels ${res.labels}${res.droppedSockets.length ? ` (socket labels hidden by overlap: ${res.droppedSockets.join(', ')}; try --zoom <socket>)` : ''}` : ''}, ${Date.now() - t0} ms`);
  if (errors.length) console.log(`  page errors: ${errors.join(' | ')}`);
} finally { await browser.close(); }
