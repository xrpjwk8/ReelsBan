import { normalize, reduce, publicState, PLATFORMS, platformFromUrl } from './state.js';

// Serialize read/modify/write across tabs, including service worker wake-ups.
let queue = Promise.resolve();
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (sender.id !== chrome.runtime.id || !['get', 'visit', 'settings'].includes(message?.type)) return;
  const internal = sender.url?.startsWith(chrome.runtime.getURL('')) && !sender.tab;
  if (message.type === 'settings' && !internal) return;
  if (message.type === 'visit' && (!sender.tab || !PLATFORMS.includes(message.platform) || platformFromUrl(sender.url) !== message.platform)) return;
  queue = queue.then(async () => {
    const { state: raw } = await chrome.storage.local.get('state');
    const state = reduce(raw, message, sender.tab?.id);
    if (JSON.stringify(raw) !== JSON.stringify(state)) await chrome.storage.local.set({ state });
    const total = Object.values(state.services).reduce((sum, service) => sum + service.count, 0);
    await chrome.action.setBadgeText({ text: String(total) });
    await chrome.action.setBadgeBackgroundColor({ color: '#171717' });
    respond({ ok: true, state: publicState(state) });
  }).catch(error => respond({ ok: false, error: error.message }));
  return true;
});

chrome.tabs.onRemoved.addListener(tabId => {
  queue = queue.then(async () => {
    const { state: raw } = await chrome.storage.local.get('state');
    const state = normalize(raw);
    for (const service of Object.values(state.services)) delete service.lastByTab[String(tabId)];
    await chrome.storage.local.set({ state });
  }).catch(console.error);
});
