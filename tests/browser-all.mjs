import { spawn } from 'node:child_process';
const variants = [['instagram'], ['youtube'], ['tiktok'], ['tiktok', '--guest']];
const results = await Promise.all(variants.map(([platform, ...flags]) => new Promise(resolve => {
  const child = spawn(process.execPath, ['tests/browser-check.mjs', `--platform=${platform}`, ...flags], { stdio: 'inherit' });
  child.on('error', error => { console.error(error.message); resolve(1); });
  child.on('exit', code => resolve(code ?? 1));
})));
process.exitCode = results.some(code => code !== 0) ? 1 : 0;
