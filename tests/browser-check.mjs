import http from 'node:http';
import { readFile, mkdtemp, rm } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';
import path from 'node:path';
const root = path.resolve(import.meta.dirname, '..');
const preview = process.argv.includes('--preview');
const platform = process.argv.find(arg => arg.startsWith('--platform='))?.split('=')[1] || 'instagram';
const guest = process.argv.includes('--guest');
const startPath = guest && platform === 'tiktok' ? '/ko-KR/' : {instagram:'/reels/test/',youtube:'/shorts/first',tiktok:'/foryou'}[platform];
const server = http.createServer(async (req, res) => {
  if (req.url === '/preview') {
    const html = await readFile(path.join(root, 'extension/popup.html'), 'utf8');
    const mock = `<base href="/extension/"><script>globalThis.chrome={runtime:{async sendMessage(){return {ok:true,state:{day:'2026-10-08',services:{instagram:{count:12,limit:30,enabled:true},youtube:{count:8,limit:20,enabled:true},tiktok:{count:5,limit:15,enabled:true}}}}}},storage:{onChanged:{addListener(){}}}};</script>`;
    res.setHeader('Content-Type', 'text/html');
    res.end(html.replace('<head>', '<head>' + mock));
    return;
  }
  const name = req.url.split('?')[0] === startPath ? '/tests/browser.html' : req.url;
  if (!/^\/(extension\/[\w.-]+|tests\/browser.html)$/.test(name)) { res.writeHead(404).end(); return; }
  try {
    res.setHeader('Content-Type', name.endsWith('.js') ? 'text/javascript' : name.endsWith('.css') ? 'text/css' : 'text/html');
    let source = await readFile(path.join(root, name), 'utf8');
    // Capture navigation at the browser boundary without visiting the external job site.
    if (name === '/extension/content.js') source = source.replace('location.assign(url)', 'globalThis.recordNavigation(url)').replace('platformForHost(location.hostname)', JSON.stringify(platform));
    res.end(source);
  } catch { res.writeHead(404).end(); }
});
await new Promise((resolve, reject) => { server.on('error', reject); server.listen(0, '127.0.0.1', resolve); });
const profile = await mkdtemp(path.join(tmpdir(), 'reelsban-check-'));
try {
  const chrome = process.env.CHROME_BIN || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  const extra = preview ? ['--window-size=390,650', `--screenshot=${path.join(tmpdir(), 'reelsban-popup.png')}`] : ['--window-size=1000,900'];
  const child = spawn(chrome, ['--headless=new', '--no-first-run', '--no-default-browser-check', '--disable-background-networking', `--user-data-dir=${profile}`, ...extra, '--virtual-time-budget=6500', '--dump-dom', `http://127.0.0.1:${server.address().port}${preview ? '/preview' : startPath + '?platform=' + platform + (guest ? '&guest=1' : '')}`]);
  let output = '', errors = '';
  child.stdout.on('data', data => output += data);
  child.stderr.on('data', data => errors += data);
  const timeout = setTimeout(() => child.kill(), 30000);
  await new Promise((resolve, reject) => { child.on('error', reject); child.on('close', resolve); });
  clearTimeout(timeout);
  const result = output.match(/<pre id="result">([^<]+)<\/pre>/)?.[1];
  if (!preview && !result?.startsWith('PASS:')) throw new Error(result || errors.slice(-1500) || 'Chrome did not complete checks');
  console.log(preview ? path.join(tmpdir(), 'reelsban-popup.png') : `${platform}${guest ? ' guest' : ''}: ${result}`);
} finally { server.close(); await rm(profile, { recursive: true, force: true, maxRetries: 3, retryDelay: 200 }); }
