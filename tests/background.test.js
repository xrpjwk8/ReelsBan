import test from 'node:test';
import assert from 'node:assert/strict';
let listener, removed, stored;
const extensionId = 'test-extension';
const popup = { id: extensionId, url: `chrome-extension://${extensionId}/popup.html` };
const sender = (platform, tabId) => ({id: extensionId, url: `https://www.${platform}.com/`, tab:{id: tabId}});
globalThis.chrome = {
  runtime:{ id:extensionId, getURL:path=>`chrome-extension://${extensionId}/${path}`, onMessage:{addListener:fn=>{listener=fn;}} },
  storage:{local:{async get(){return {state:structuredClone(stored)};},async set({state}){stored=structuredClone(state);}}},
  action:{async setBadgeText(){},async setBadgeBackgroundColor(){}},
  tabs:{onRemoved:{addListener:fn=>{removed=fn;}}}
};
await import('../extension/background.js');
const send=(message,source=popup)=>new Promise(resolve=>listener(message,source,resolve));
test('worker serializes concurrent tabs, isolates services and rejects spoofed origins',async()=>{
 await send({type:'get'});
 assert.equal(stored.services.instagram.limit,20);
 await Promise.all(Array.from({length:10},(_,i)=>send({type:'visit',platform:'youtube',key:`youtube:${i}`},sender('youtube',i))));
 assert.equal(stored.services.youtube.count,10);
 assert.equal(stored.services.instagram.count,0);
 const ignored=()=>{throw Error('untrusted message was processed');};
 assert.equal(listener({type:'visit',platform:'youtube',key:'spoof'},sender('tiktok',1),ignored),undefined);
 assert.equal(listener({type:'settings',services:{}},sender('youtube',1),ignored),undefined);
 assert.equal(listener({type:'get'},{...popup,id:'other-extension'},ignored),undefined);
 assert.equal(stored.services.youtube.count,10);
 removed(1);await send({type:'get'});
 assert.equal(stored.services.youtube.lastByTab['1'],undefined);
});
