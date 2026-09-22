// Local emulator only. No credentials, dependencies, or production writes.
// Start Firestore on 127.0.0.1:8189 with project demo-tastewise-tests and this repo's rules.
const assert = require('node:assert/strict');
const base = 'http://127.0.0.1:8189/v1/projects/demo-tastewise-tests/databases/(default)/documents';
const name = p => 'projects/demo-tastewise-tests/databases/(default)/documents/' + p;
const token = uid => [Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url'),
  Buffer.from(JSON.stringify({ sub: uid, user_id: uid, email: uid+'@example.com', email_verified: true,
    aud: 'demo-tastewise-tests', iss: 'https://securetoken.google.com/demo-tastewise-tests',
    iat: Math.floor(Date.now()/1000), exp: Math.floor(Date.now()/1000)+3600,
    firebase: { sign_in_provider: 'password', identities: {} } })).toString('base64url'), ''].join('.');
const encode = v => v === null ? {nullValue:null} : typeof v === 'boolean' ? {booleanValue:v} :
  typeof v === 'number' ? {integerValue:String(v)} : typeof v === 'string' ? {stringValue:v} :
  Array.isArray(v) ? {arrayValue:{values:v.map(encode)}} : {mapValue:{fields:fields(v)}};
const fields = data => Object.fromEntries(Object.entries(data).map(([k,v])=>[k,encode(v)]));
const write = (path,data,timestamps=[]) => ({update:{name:name(path),fields:fields(data)},
  ...(timestamps.length ? {updateTransforms: timestamps.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}: {})});
const patch = (path,data,timestamps=[]) => ({...write(path,data,timestamps),updateMask:{fieldPaths:Object.keys(data)}});
let passed = 0;
async function commit(uid,writes,allowed,label) {
  const r=await fetch(base+':commit',{method:'POST',headers:{'Authorization':'Bearer '+(uid==='owner'?'owner':token(uid)),'Content-Type':'application/json'},body:JSON.stringify({writes})});
  const body=await r.text();
  assert.equal(r.ok,allowed,label+': '+body);
  if(!allowed)assert.equal(r.status,403,label+': expected permission denied, not transport/rules compilation error');
  passed++;console.log('PASS '+label);
}
async function readDoc(uid,path,allowed,label) {
  const headers = uid ? {'Authorization':'Bearer '+(uid==='owner'?'owner':token(uid))} : {};
  const r=await fetch(base+'/'+path,{headers});
  const body=await r.text();
  assert.equal(r.ok,allowed,label+': '+body);
  if(!allowed)assert.ok(r.status===401||r.status===403,label+': expected unauthenticated or permission denied');
  passed++;console.log('PASS '+label);
  return r.ok ? JSON.parse(body) : null;
}
const profile = uid => ({email:uid+'@example.com',displayName:uid,displayNameLower:uid,photoUrl:null,role:'user',messagePrivacy:'everyone',emailVerified:true,followerCount:0,followingCount:0,postCount:0,phone:'legacy phone'});
const publicProfile = data => Object.fromEntries(Object.entries(data).filter(([key])=>[
  'displayName','displayNameLower','username','usernameLower','photoUrl','bio','role',
  'businessName','businessVerificationStatus','ownedRestaurantId','messagePrivacy',
  'followerCount','followingCount','postCount','suspended'
].includes(key)));
const profileWrites = uid => {
  const data=profile(uid);return [
    write('users/'+uid,data,['createdAt','updatedAt']),
    write('publicProfiles/'+uid,publicProfile(data),['createdAt','updatedAt'])
  ];
};
const post = uid => ({authorId:uid,restaurantId:'place',restaurantName:'Cafe',caption:'Lunch',media:[{url:'https://example.com/photo.jpg'}],likeCount:0,commentCount:0,shareCount:0,trendingScore:0});
async function main(){
  const reset=await fetch('http://127.0.0.1:8189/emulator/v1/projects/demo-tastewise-tests/databases/(default)/documents',{method:'DELETE'});
  assert(reset.ok);
  await commit('alice',profileWrites('alice'),true,'new private and public profile can be created atomically');
  await commit('bob',profileWrites('bob'),true,'second private and public profile can be created atomically');
  await readDoc(null,'publicProfiles/alice',false,'anonymous users cannot read profiles');
  await readDoc('bob','users/alice',false,'another user cannot read private account data');
  const publicAlice=await readDoc('bob','publicProfiles/alice',true,'signed-in users can read public profile');
  assert.equal(publicAlice.fields.email,undefined);assert.equal(publicAlice.fields.phone,undefined);
  passed++;console.log('PASS public profile excludes email and legacy phone');
  await commit('alice',[patch('publicProfiles/alice',{email:'leak@example.com'})],false,'public profile schema rejects private fields');
  await commit('alice',[write('posts/pre-consent',post('alice'))],false,'publishing requires terms');
  await commit('alice',[patch('users/alice',{termsAcceptedVersion:'wrong'},['termsAcceptedAt'])],false,'wrong terms version rejected');
  for(const uid of ['alice','bob'])await commit(uid,[patch('users/'+uid,{termsAcceptedVersion:'2026-09-21'},['termsAcceptedAt'])],true,uid+' accepts terms');
  await commit('alice',[
    patch('users/alice',{bio:'Food lover\nCoffee enthusiast'},['updatedAt']),
    patch('publicProfiles/alice',{bio:'Food lover\nCoffee enthusiast'},['updatedAt'])
  ],true,'bio saves to private and public profiles atomically');
  await commit('alice',[patch('users/alice',{bio:'x'.repeat(161)})],false,'oversized bio denied');
  await commit('alice',[patch('users/alice',{role:'admin'})],false,'cannot self-grant moderation access');
  await commit('alice',[write('posts/alice-post',post('alice'))],true,'publishing works after terms');
  await commit('bob',[write('posts/bob-post',post('bob'))],true,'second author publishes');
  await commit('alice',[write('chats/alice_bob',{participants:['alice','bob']})],true,'unblocked chat allowed');
  await commit('alice',[write('users/alice/blocked/bob',{},['createdAt'])],false,'partial block without reverse index denied');
  await commit('alice',[write('users/alice/blocked/bob',{},['createdAt']),write('users/bob/blockedBy/alice',{},['createdAt'])],true,'atomic bilateral block index allowed');
  await commit('bob',[write('users/bob/following/alice',{})],false,'blocked peer cannot follow');
  await commit('alice',[write('users/alice/following/bob',{})],false,'blocker cannot follow peer');
  await commit('bob',[write('posts/alice-post/likes/bob',{})],false,'blocked peer cannot like');
  await commit('bob',[write('posts/alice-post/comments/reply',{authorId:'bob',text:'hello'})],false,'blocked peer cannot comment');
  await commit('bob',[write('chats/alice_bob/messages/reply',{senderId:'bob',type:'text',text:'hello'})],false,'blocked peer cannot message existing chat');
  await commit('alice',[write('chats/alice_bob/messages/reply2',{senderId:'alice',type:'text',text:'hello'})],false,'blocker cannot message existing chat');
  await commit('bob',[write('users/alice/notifications/spam',{actorId:'bob',actorName:'Bob',type:'follow',read:false})],false,'blocked peer cannot send notification');
  await commit('bob',[{delete:name('users/alice/blocked/bob')}],false,'peer cannot remove someone else block');
  const report={reporterId:'alice',targetType:'post',targetId:'bob-post',targetUserId:'bob',reason:'Harassment',status:'open'};
  await commit('alice',[write('reports/alice-report',report,['createdAt'])],true,'report is persisted');
  await commit('bob',[write('reports/forged-report',report,['createdAt'])],false,'reporter cannot be forged');
  await commit('alice',[patch('reports/alice-report',{status:'dismissed'})],false,'reporter cannot resolve their report');
  await commit('alice',[{delete:name('users/alice/blocked/bob')},{delete:name('users/bob/blockedBy/alice')}],true,'atomic unblock allowed');
  await commit('bob',[write('chats/alice_bob/messages/unblocked',{senderId:'bob',type:'text',text:'hello again'})],true,'messaging resumes after unblock');
  await commit('owner',[patch('users/bob',{suspended:true})],true,'admin fixture suspends account');
  await commit('bob',[write('posts/suspended',post('bob'))],false,'suspended account cannot publish with existing token');
  await commit('bob',[patch('users/bob',{suspended:false})],false,'suspension cannot be self-cleared');
  const r=await fetch(base+'/users/alice',{headers:{Authorization:'Bearer owner'}});const data=await r.json();
  assert.equal(data.fields.phone.stringValue,'legacy phone');passed++;console.log('PASS existing phone preserved');
  console.log('All '+passed+' Firestore emulator checks passed.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
