// Shared by the content script and the dependency-free test harness.
globalThis.ReelsBanDetector = (() => {
  function isReelPage(pathname) { return /^\/reels?(?:\/|$)/.test(pathname); }
  function reelId(value) {
    try { return new URL(value, 'https://www.instagram.com').pathname.match(/^\/reels?\/([\w-]+)\/?$/)?.[1] || null; }
    catch { return null; }
  }
  function platformForHost(host) {
    return ({ 'instagram.com': 'instagram', 'youtube.com': 'youtube', 'tiktok.com': 'tiktok' })[host.replace(/^www\./, '')] || null;
  }
  function tiktokPath(path) {
    return path.replace(/^\/[a-z]{2}(?:-[a-z]{2})?(?=\/|$)/i, '') || '/';
  }
  function tiktokPlayerId(id) {
    return /^xgwrapper-\d+-(\d+)$/.exec(id || '')?.[1] || null;
  }
  function isVideoPage(platform, path) {
    if (platform === 'tiktok') path = tiktokPath(path);
    if (platform === 'instagram') return isReelPage(path);
    if (platform === 'youtube') return /^\/shorts\/[\w-]+\/?$/.test(path);
    if (platform === 'tiktok') return /^\/(?:foryou|following)?\/?$/.test(path) || /^\/@[^/]+\/video\/\d+\/?$/.test(path);
    return false;
  }
  function videoId(platform, value) {
    try {
      let path = new URL(value, 'https://example.com').pathname;
      if (platform === 'tiktok') path = tiktokPath(path);
      if (platform === 'instagram') return reelId(value);
      return platform === 'youtube' ? path.match(/^\/shorts\/([\w-]+)\/?$/)?.[1] || null : path.match(/^\/@[^/]+\/video\/(\d+)\/?$/)?.[1] || null;
    } catch { return null; }
  }
  function visibility(rect, width, height) {
    if (rect.width < 100 || rect.height < 150) return 0;
    const area = Math.max(0, Math.min(rect.right, width) - Math.max(rect.left, 0)) * Math.max(0, Math.min(rect.bottom, height) - Math.max(rect.top, 0));
    return area / (rect.width * rect.height);
  }
  function stableTracker(delay = 650) {
    let candidate = null, since = 0, committed = null;
    return {
      observe(key, now) {
        if (!key) { candidate = null; return null; }
        if (candidate !== key) { candidate = key; since = now; }
        if (now - since < delay || committed === key) return null;
        committed = key;
        return key;
      },
      reset() { candidate = null; committed = null; }
    };
  }
  return { isReelPage, reelId, tiktokPlayerId, platformForHost, isVideoPage, videoId, visibility, stableTracker };
})();
