globalThis.ReelsBanLocation = (() => {
  const SEOUL_URL = 'https://mcdonalds.recruiter.co.kr/career/jobs/120676';
  const OTHER_URL = 'https://mcdonalds.recruiter.co.kr/career/jobs/130416';
  function inRing(lng, lat, ring) {
    let inside = false;
    for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      const [x, y] = ring[i], [xx, yy] = ring[j];
      if ((y > lat) !== (yy > lat) && lng < (xx - x) * (lat - y) / (yy - y) + x) inside = !inside;
    }
    return inside;
  }
  function isSeoul(coords) {
    const { longitude: lng, latitude: lat } = coords || {};
    const rings = globalThis.ReelsBanSeoulBoundary;
    return Number.isFinite(lng) && Number.isFinite(lat) && !!rings?.length &&
      inRing(lng, lat, rings[0]) && !rings.slice(1).some(ring => inRing(lng, lat, ring));
  }
  function resolveJobUrl(nav = navigator, timeout = 2500) {
    return new Promise(resolve => {
      let completed = false;
      const finish = url => {
        if (completed) return;
        completed = true;
        clearTimeout(timer);
        resolve(url);
      };
      const timer = setTimeout(() => finish(OTHER_URL), timeout);
      (async () => {
        try {
          if (!nav.permissions?.query || !nav.geolocation) return finish(OTHER_URL);
          const permission = await nav.permissions.query({ name: 'geolocation' });
          // Never invoke geolocation while permission is prompt/denied.
          if (completed) return;
          if (permission.state !== 'granted') return finish(OTHER_URL);
          nav.geolocation.getCurrentPosition(
            position => finish(isSeoul(position.coords) ? SEOUL_URL : OTHER_URL),
            () => finish(OTHER_URL),
            { enableHighAccuracy: false, maximumAge: 60000, timeout }
          );
        } catch { finish(OTHER_URL); }
      })();
    });
  }
  return { SEOUL_URL, OTHER_URL, isSeoul, resolveJobUrl };
})();
