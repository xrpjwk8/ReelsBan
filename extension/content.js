(() => {
  const { platformForHost, isVideoPage, videoId, tiktokPlayerId, visibility, stableTracker } = globalThis.ReelsBanDetector;
  const platform = platformForHost(location.hostname);
  if (!platform) return;
  const label = { instagram: '릴스', youtube: '쇼츠', tiktok: '틱톡' }[platform];
  const isCurrentPage = () => isVideoPage(platform, location.pathname);
  const tracker = stableTracker();
  const { resolveJobUrl } = globalThis.ReelsBanLocation;
  let redirectVersion = 0;
  let redirecting = false;
  let state, busy = false, host, statusText, stopped = false;
  let lastDay = '', lastPoll = 0;
  const elementIds = new WeakMap();
  let sequence = 0;
  function fingerprint(value) {
    let hash = 2166136261;
    for (let i = 0; i < value.length; i++) hash = Math.imul(hash ^ value.charCodeAt(i), 16777619);
    return (hash >>> 0).toString(16);
  }

  async function request(type, extra = {}) {
    const response = await chrome.runtime.sendMessage({ type, platform, ...extra });
    if (!response?.ok) throw new Error(response?.error || '확장 프로그램 연결 실패');
    const service = response.state.services[platform];
    state = { ...service, day: response.state.day, blocked: service.enabled && service.count >= service.limit };
    render();
  }

  function activeReel() {
    const candidates = [...document.querySelectorAll('video')]
      .map(video => ({ video, score: visibility(video.getBoundingClientRect(), innerWidth, innerHeight) }))
      .filter(item => item.score >= 0.65 && item.video.getClientRects().length)
      .sort((a, b) => b.score - a.score);
    if (!candidates.length) return null;
    const video = candidates[0].video;
    if (platform === 'youtube') {
      const id = videoId(platform, location.href);
      return id ? `youtube:${id}` : null;
    }
    if (platform === 'tiktok') {
      if (video.closest('[data-e2e*="live"], a[href*="/live"]')) return null;
      // Guest feeds omit permalinks but expose the video ID on the player wrapper.
      const id = tiktokPlayerId(video.closest('[id^="xgwrapper-"]')?.id);
      if (id) return `tiktok:${id}`;
    }
    // Prefer a permalink belonging to this video; do not use a neighbouring card's link.
    let parent = video.parentElement;
    for (let depth = 0; parent && depth < 7; depth++, parent = parent.parentElement) {
      if (parent.querySelectorAll('video').length > 1) break;
      const ids = [...parent.querySelectorAll('a[href]')].map(a => videoId(platform, a.href)).filter(Boolean);
      if (new Set(ids).size === 1) return `${platform === 'instagram' ? 'reel' : platform}:${ids[0]}`;
    }
    if (platform === 'tiktok') {
      const id = videoId(platform, location.href);
      return id ? `tiktok:${id}` : null;
    }
    // A media source is more reliable than the URL, which can lag behind a swipe.
    const source = video.currentSrc || video.src || video.querySelector('source')?.src;
    if (source) return `media:${fingerprint(source)}`;
    const id = videoId(platform, location.href);
    if (id) return `reel:${id}`;
    if (!elementIds.has(video)) elementIds.set(video, `element:${crypto.randomUUID()}:${++sequence}`);
    return elementIds.get(video);
  }

  function createUI() {
    host = document.createElement('div');
    host.style.cssText = 'all:initial;position:fixed;inset:0;z-index:2147483647;pointer-events:none';
    const root = host.attachShadow({ mode: 'closed' });
    root.innerHTML = `<style>
      :host{font-family:-apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;color:#263c33}
      *{box-sizing:border-box} .badge{position:fixed;right:24px;bottom:24px;background:#f8f6ed;color:#263c33;padding:12px 18px;border:1px solid #d8ddcf;border-radius:99px;font-size:13px;box-shadow:0 4px 24px #0002;pointer-events:none}
    </style><div class="badge" role="status"></div>`;
    statusText = root.querySelector('.badge');
    document.documentElement.append(host);
    return root;
  }
  let ui;
  function render() {
    if (!state) return;
    const active = state.enabled && isCurrentPage();
    if (!active || !state.blocked) {
      redirecting = false;
      redirectVersion++;
    }
    if (!active) {
      if (host) host.style.display = 'none';
      return;
    }
    if (!ui) ui = createUI();
    host.style.display = 'block';
    statusText.textContent = `${label}  ${state.count} / ${state.limit}`;
    if (state.blocked) {
      document.querySelectorAll('video').forEach(video => { if (!video.paused) video.pause(); });
      // Use the current tab; hidden tabs wait until they become visible.
      if (!document.hidden && !redirecting) {
        redirecting = true;
        const version = ++redirectVersion;
        resolveJobUrl().then(url => {
          if (version !== redirectVersion) return;
          if (!state?.enabled || !state.blocked || !isCurrentPage() || document.hidden) {
            redirecting = false;
            return;
          }
          location.assign(url);
        });
      }
    }
  }
  document.addEventListener('play', event => {
    if (state?.blocked && isCurrentPage() && event.target instanceof HTMLVideoElement) event.target.pause();
  }, true);

  chrome.storage.onChanged.addListener((changes, area) => {
    if (area === 'local' && changes.state) {
      const all = changes.state.newValue;
      const service = all?.services?.[platform];
      const next = service ? { ...service, day: all.day } : null;
      if (!next) return;
      if (state?.day !== next.day || state?.enabled !== next.enabled) tracker.reset();
      state = { ...next, blocked: next.enabled && next.count >= next.limit };
      render();
    }
  });

  async function tick() {
    if (busy || stopped || document.hidden) return;
    busy = true;
    try {
      const day = new Date().toDateString();
      if (!state || lastDay !== day || Date.now() - lastPoll > 15000) {
        await request('get'); lastDay = day; lastPoll = Date.now();
      }
      render();
      if (!state.enabled || !isCurrentPage()) { tracker.reset(); return; }
      if (state.blocked) return;
      const key = tracker.observe(activeReel(), performance.now());
      if (key) await request('visit', { key });
    } catch (error) {
      tracker.reset();
      if (!chrome.runtime?.id) {
        stopped = true;
        host?.remove();
      }
      console.warn('[ReelsBan] 새로고침이 필요할 수 있습니다.', error);
    } finally { busy = false; }
  }
  document.addEventListener('visibilitychange', () => { tracker.observe(null, 0); if (!document.hidden) tick(); });
  setInterval(tick, 250);
  tick();
})();
