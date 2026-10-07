import test from 'node:test';
import assert from 'node:assert/strict';
import '../extension/seoul-boundary.js';
import '../extension/location.js';
const { isSeoul, resolveJobUrl, SEOUL_URL, OTHER_URL } = globalThis.ReelsBanLocation;
const coords = (latitude, longitude) => ({ latitude, longitude });
test('Seoul boundary distinguishes city from neighbouring cities', () => {
  for (const c of [coords(37.5665,126.978),coords(37.5088,127.0632),coords(37.558,126.803)]) assert.equal(isSeoul(c),true);
  for (const c of [coords(37.4563,126.7052),coords(37.4292,126.9876),coords(37.6584,126.832),coords(35.1796,129.0756)]) assert.equal(isSeoul(c),false);
  assert.equal(isSeoul({}), false);
});
test('prompt and denied never call geolocation', async () => {
  for (const state of ['prompt','denied']) {
    let calls=0;
    const nav={permissions:{query:async()=>({state})},geolocation:{getCurrentPosition(){calls++;}}};
    assert.equal(await resolveJobUrl(nav), OTHER_URL);
    assert.equal(calls,0);
  }
});
test('granted routes Seoul and outside coordinates',async()=>{
  for (const [c,url] of [[coords(37.5665,126.978),SEOUL_URL],[coords(35.1796,129.0756),OTHER_URL]]) {
    const nav={permissions:{query:async()=>({state:'granted'})},geolocation:{getCurrentPosition(ok){ok({coords:c});}}};
    assert.equal(await resolveJobUrl(nav),url);
  }
});
test('OS denial, unavailable location, missing API and exceptions fall back',async()=>{
  for (const code of [1,2,3]) {
    const nav={permissions:{query:async()=>({state:'granted'})},geolocation:{getCurrentPosition(ok,fail){fail({code});}}};
    assert.equal(await resolveJobUrl(nav),OTHER_URL);
  }
  assert.equal(await resolveJobUrl({}),OTHER_URL);
  assert.equal(await resolveJobUrl({permissions:{query:async()=>{throw Error('blocked');}},geolocation:{}}),OTHER_URL);
});
test('hung location or permission query cannot block redirect indefinitely',async()=>{
  const nav={permissions:{query:async()=>({state:'granted'})},geolocation:{getCurrentPosition(){}}};
  assert.equal(await resolveJobUrl(nav,10),OTHER_URL);
  let release,calls=0;
  nav.permissions.query=()=>new Promise(resolve=>{release=resolve;});
  nav.geolocation.getCurrentPosition=()=>{calls++;};
  assert.equal(await resolveJobUrl(nav,10),OTHER_URL);
  release({state:'granted'});
  await Promise.resolve();
  assert.equal(calls,0);
});
