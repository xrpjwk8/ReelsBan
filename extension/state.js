export const PLATFORMS = ['instagram', 'youtube', 'tiktok'];
export function localDay(now = new Date()) {
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}
export function platformFromUrl(value) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:') return null;
    const host = url.hostname.replace(/^www\./, '');
    return ({ 'instagram.com': 'instagram', 'youtube.com': 'youtube', 'tiktok.com': 'tiktok' })[host] || null;
  } catch { return null; }
}
export function normalize(raw = {}, day = localDay()) {
  const services = {};
  for (const platform of PLATFORMS) {
    const old = raw.services?.[platform] || (platform === 'instagram' ? raw : {});
    services[platform] = {
      count: raw.day === day && Number.isSafeInteger(old.count) ? Math.max(0, old.count) : 0,
      limit: Number.isInteger(old.limit) && old.limit >= 1 && old.limit <= 500 ? old.limit : 20,
      enabled: old.enabled !== false,
      lastByTab: raw.day === day && old.lastByTab && typeof old.lastByTab === 'object' ? { ...old.lastByTab } : {}
    };
  }
  return { version: 2, day, services };
}
export function reduce(raw, message, tabId, day = localDay()) {
  const state = normalize(raw, day);
  if (message.type === 'settings') {
    for (const platform of PLATFORMS) {
      const setting = message.services?.[platform];
      const limit = Number(setting?.limit);
      if (!Number.isInteger(limit) || limit < 1 || limit > 500 || typeof setting?.enabled !== 'boolean') throw new Error('각 한도는 1~500 사이의 정수로 입력해 주세요.');
      state.services[platform].limit = limit;
      state.services[platform].enabled = setting.enabled;
    }
  }
  if (message.type === 'visit') {
    if (!PLATFORMS.includes(message.platform)) throw new Error('지원하지 않는 서비스입니다.');
    const service = state.services[message.platform];
    if (service.enabled && service.count < service.limit) {
      if (!Number.isInteger(tabId) || typeof message.key !== 'string' || !message.key || message.key.length > 2048) throw new Error('잘못된 감지 정보입니다.');
      const slot = String(tabId);
      if (service.lastByTab[slot] !== message.key) {
        service.count++;
        service.lastByTab[slot] = message.key;
      }
    }
  }
  return state;
}
export function publicState(state) {
  return { day: state.day, services: Object.fromEntries(PLATFORMS.map(platform => {
    const { lastByTab, ...service } = state.services[platform];
    return [platform, { ...service, blocked: service.enabled && service.count >= service.limit }];
  })) };
}
