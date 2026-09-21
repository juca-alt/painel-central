import fs from 'node:fs'; import os from 'node:os'; import path from 'node:path'; import { execFileSync } from 'node:child_process';
const html = fs.readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const scripts = [...html.matchAll(/<script(?![^>]*(?:src|type="(?!text\/javascript)))[^>]*>([\s\S]*?)<\/script>/g)].map(m => m[1]);
const f = path.join(os.tmpdir(), 'painel-inline.js'); fs.writeFileSync(f, scripts.join('\n;\n'));
execFileSync('node', ['--check', f], { stdio: 'inherit' }); execFileSync('node', ['--check', new URL('../sw.js', import.meta.url).pathname], { stdio: 'inherit' });
console.log(`  ✓ ${scripts.length} scripts inline + sw.js sem erro de sintaxe`);
