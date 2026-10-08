// Bundle finished GLBs into the interactive viewer (viewer/template.html) so the user can orbit them and play clips.
// Usage: node showcase.mjs --out <dir> [--title "Farm animals"] [--lede "one sentence"] [--group "Animals"] a.glb b.glb [--group "Props"] c.glb
// Per model it reads <name>.spec.json (optional "title" and "description" fields) and runs validate.mjs for the verdict.
// Writes <dir>/<title-slug>.html + <dir>/models.js (GLBs embedded as base64, since artifacts don't serve .glb files).
// Then publish with the Artifact tool: file_path = the .html, files = { "models.js": "<dir>/models.js" }, icon "cube".
// The page also works opened locally in a browser (it loads three.js from jsdelivr).
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { findSpec } from './lib.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);
const opt = k => { const i = argv.indexOf(`--${k}`); return i >= 0 ? argv[i + 1] : undefined; };
const out = opt('out'), title = opt('title') || 'Model Showcase', lede = opt('lede') || 'Drag to orbit, pick a clip to play it. Each verdict is the validate.mjs result.';
if (!out) { console.error('usage: node showcase.mjs --out <dir> [--title t] [--lede s] [--group g] a.glb [b.glb ...]'); process.exit(2); }

const groups = []; let group = null;
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--group') { group = { group: argv[++i], items: [] }; groups.push(group); continue; }
  if (a.startsWith('--')) { i++; continue; }
  if (!group) { group = { group: 'Models', items: [] }; groups.push(group); }
  group.items.push(a);
}
const files = groups.flatMap(g => g.items);
if (!files.length) { console.error('no .glb files given'); process.exit(2); }

const data = {}, used = new Set();
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
for (const g of groups) g.items = g.items.map(file => {
  if (!fs.existsSync(file)) { console.error(`missing ${file}`); process.exit(2); }
  let key = path.basename(file); while (used.has(key)) key = '_' + key; used.add(key);
  data[key] = fs.readFileSync(file).toString('base64');
  const spec = findSpec(file)?.spec ?? {};
  const r = spawnSync('node', [path.join(HERE, 'validate.mjs'), file, '--quiet'], { encoding: 'utf8' });
  const last = r.stdout.trim().split('\n').pop() || '';
  const warns = +(last.match(/with (\d+) warning/)?.[1] ?? 0), failing = last.match(/FAIL: (\d+) failing/)?.[1];
  const verdict = failing ? `FAIL · ${failing}` : warns ? `PASS · ${warns} warn` : 'PASS';
  const base = path.basename(file, '.glb');
  return { file: key, name: esc(spec.title || base.replace(/[-_]+/g, ' ').replace(/^\w/, c => c.toUpperCase())), verdict, v: failing ? 'fail' : 'pass', note: esc(spec.description || '') };
});

fs.mkdirSync(out, { recursive: true });
const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'models';
const html = fs.readFileSync(path.join(HERE, '..', 'viewer', 'template.html'), 'utf8').replaceAll('__TITLE__', esc(title)).replaceAll('__LEDE__', esc(lede));
const htmlPath = path.resolve(out, `${slug}.html`), jsPath = path.resolve(out, 'models.js');
fs.writeFileSync(htmlPath, html);
fs.writeFileSync(jsPath, `window.GLB_MODELS = ${JSON.stringify({ groups, data })};\n`);
const mb = fs.statSync(jsPath).size / 1048576;
for (const g of groups) for (const m of g.items) console.log(`  ${g.group} / ${m.name}: ${m.verdict}${m.note ? '' : '  (no description: add "description" to its spec)'}`);
console.log(`wrote ${htmlPath}\n      ${jsPath} (${mb.toFixed(2)} MB${mb > 12 ? ' — too big for one artifact; split into several showcases' : ''})`);
console.log(`publish: Artifact file_path="${htmlPath}" files={"models.js": "${jsPath}"} icon="cube"`);
