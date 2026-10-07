import test from 'node:test';
import assert from 'node:assert/strict';
import { normalize, reduce, publicState, localDay, platformFromUrl, PLATFORMS } from '../extension/state.js';
import '../extension/detector.js';
const { stableTracker, isVideoPage, videoId, visibility } = globalThis.ReelsBanDetector;
const day = '2026-10-08';
const visit = (platform,key) => ({type:'visit',platform,key});
const settings = (limit=2) => ({type:'settings',services:Object.fromEntries(PLATFORMS.map(p=>[p,{limit,enabled:true}]))});
test('migrates legacy Reels settings and usage without assigning them to new services',()=>{
 const state=normalize({day,count:12,limit:45,enabled:false,lastByTab:{1:'a'}},day);
 assert.equal(state.services.instagram.count,12); assert.equal(state.services.instagram.limit,45); assert.equal(state.services.instagram.enabled,false);
 assert.equal(state.services.youtube.count,0); assert.equal(state.services.youtube.limit,20);
 assert.equal(localDay(new Date(2026,9,8)),day);
});
test('separate quotas, multiple tabs, deduplication and reload',()=>{
 let s=reduce(undefined,settings(),undefined,day);
 for(const platform of PLATFORMS){s=reduce(s,visit(platform,'a'),1,day);s=reduce(s,visit(platform,'a'),1,day);assert.equal(s.services[platform].count,1);}
 s=reduce(s,visit('youtube','b'),2,day);
 assert.equal(publicState(s).services.youtube.blocked,true);
 assert.equal(publicState(s).services.instagram.blocked,false);
 s=reduce(s,visit('youtube','c'),3,day);assert.equal(s.services.youtube.count,2);
});
test('returning to a previous video counts again',()=>{
 let s;for(const key of ['a','b','a'])s=reduce(s,visit('tiktok',key),1,day);
 assert.equal(s.services.tiktok.count,3);
});
test('midnight resets all usage and preserves preferences',()=>{
 let s=reduce(undefined,settings(42),undefined,day);
 for(const p of PLATFORMS)s=reduce(s,visit(p,'a'),1,day);
 s=normalize(s,'2026-10-09');
 for(const p of PLATFORMS){assert.equal(s.services[p].count,0);assert.equal(s.services[p].limit,42);assert.deepEqual(s.services[p].lastByTab,{});}
});
test('disabled services do not count; settings do not erase existing usage',()=>{
 let s=reduce(undefined,visit('instagram','a'),1,day);const m=settings(1);m.services.instagram.enabled=false;
 s=reduce(s,m,undefined,day);s=reduce(s,visit('instagram','b'),1,day);
 assert.equal(s.services.instagram.count,1);assert.equal(publicState(s).services.instagram.blocked,false);
 m.services.instagram.enabled=true;s=reduce(s,m,undefined,day);assert.equal(publicState(s).services.instagram.blocked,true);
 m.services.instagram.limit=10;s=reduce(s,m,undefined,day);assert.equal(publicState(s).services.instagram.blocked,false);
});
test('invalid setting does not mutate old data and hostile origins are not platforms',()=>{
 const s=normalize(undefined,day);const m=settings();m.services.tiktok.limit=0;
 assert.throws(()=>reduce(s,m,undefined,day));assert.equal(s.services.instagram.limit,20);
 assert.equal(platformFromUrl('https://www.youtube.com/shorts/abc'),'youtube');
 assert.equal(platformFromUrl('https://youtube.com.evil.test/'),null);
 assert.throws(()=>reduce(s,visit('unknown','a'),1,day));
});
test('only supported viewing surfaces count, excluding Live, photos, search and standard YouTube',()=>{
 for(const [p,path] of [['instagram','/reels/abc/'],['youtube','/shorts/abc-123'],['tiktok','/foryou'],['tiktok','/following'],['tiktok','/@user/video/12345']]) assert.equal(isVideoPage(p,path),true);
 for(const [p,path] of [['instagram','/direct/inbox/'],['youtube','/watch'],['youtube','/'],['tiktok','/@user/live'],['tiktok','/@user/photo/123'],['tiktok','/search'],['tiktok','/@user']])assert.equal(isVideoPage(p,path),false);
 assert.equal(videoId('youtube','https://www.youtube.com/shorts/abc-123?x=1'),'abc-123');
 assert.equal(videoId('tiktok','https://www.tiktok.com/@user/video/12345'),'12345');
});
test('visibility and dwell filter reject transient or hidden videos',()=>{
 assert.equal(visibility({width:400,height:600,top:700,left:0,right:400,bottom:1300},800,800)<.65,true);
 const t=stableTracker();assert.equal(t.observe('a',0),null);assert.equal(t.observe('a',650),'a');assert.equal(t.observe('a',900),null);
 assert.equal(t.observe('b',1000),null);assert.equal(t.observe('c',1100),null);assert.equal(t.observe('c',1800),'c');
 t.observe(null,2000);assert.equal(t.observe('d',5000),null);
});

test('TikTok guest locale routes and player IDs work without video links', () => {
  const { tiktokPlayerId } = globalThis.ReelsBanDetector;
  for (const path of ['/ko-KR/', '/en/', '/ko-KR/foryou', '/ko-KR/@user/video/12345']) assert.equal(isVideoPage('tiktok',path),true);
  for (const path of ['/ko-KR/live', '/ko-KR/search', '/ko-KR/@user/photo/12345']) assert.equal(isVideoPage('tiktok',path),false);
  assert.equal(videoId('tiktok','https://www.tiktok.com/ko-KR/@user/video/12345'),'12345');
  assert.equal(tiktokPlayerId('xgwrapper-0-7669893881223302414'),'7669893881223302414');
  assert.equal(tiktokPlayerId('xgwrapper-1-7669893881223302414'),'7669893881223302414');
  assert.equal(tiktokPlayerId('media-card-5'),null);
});
