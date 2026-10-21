import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApi } from '../server.js';
const setup = async (fn) => {
  const folder = mkdtempSync(join(tmpdir(), 'kisan-test-'));
  const file = join(folder, 'db.json');
  const { server } = createApi(file);
  await new Promise(ok => server.listen(0, '127.0.0.1', ok));
  const base = `http://127.0.0.1:${server.address().port}`;
  const request = async (path, method='GET', data, token) => {
    const r = await fetch(base + path, { method, headers: { 'Content-Type':'application/json', ...(token ? {'X-Demo-Token': token} : {}) }, ...(data===undefined?{}:{body:JSON.stringify(data)}) });
    return { status:r.status, body:await r.json() };
  };
  try { await fn(request, file); } finally { await new Promise(ok => server.close(ok)); rmSync(folder,{ recursive:true,force:true }); }
};

test('all six collections and required seed counts with 14 dates per pair', async () => setup(async req => {
  const all = {};
  for(const name of ['users','crops','markets','prices','listings']) all[name] = (await req(`/api/${name}`)).body;
  const token=(await req('/api/demo-login','POST',{user_id:'u1'})).body.token;
  all.alerts=(await req('/api/alerts','GET',undefined,token)).body;
  assert.equal(all.users.length,6);assert.equal(all.crops.length,8);assert.equal(all.markets.length,3);
  assert.equal(all.prices.length,336);assert.equal(all.listings.length,12);assert.ok(all.alerts.length>=1);
  assert.equal(new Set(all.crops.map(x=>x.category)).size,4);
  assert.equal(new Set(all.markets.map(x=>x.district)).size,3);
  for(const crop of all.crops)for(const market of all.markets){const arr=all.prices.filter(x=>x.crop_id===crop.id&&x.market_id===market.id).sort((a,b)=>a.date.localeCompare(b.date));assert.equal(arr.length,14);for(let i=1;i<arr.length;i++)assert.equal((Date.parse(arr[i].date)-Date.parse(arr[i-1].date))/86400000,1);}
}));

test('registration persists and permits owner but rejects cross-user and buyer writes', async()=>setup(async(req,file)=>{
  const registered=await req('/api/users','POST',{name:'Test Demo',phone:'+920000001234',district:'Hyderabad',role:'Farmer'});
  assert.equal(registered.status,201);
  const token=registered.body.token;
  const today=(await req('/health')).body.date;
  const values={crop_id:'c1',quantity:100,asking_price:90,district:'Hyderabad',grade:'A',available_from:today,contact_phone:'+920000000000'};
  const created=await req('/api/listings','POST',values,token);assert.equal(created.status,201);
  const id=created.body.id;
  assert.equal(created.body.user_id,registered.body.user.id);
  assert.equal((await req(`/api/listings/${id}`)).status,200);
  const other=(await req('/api/demo-login','POST',{user_id:'u2'})).body.token;
  assert.equal((await req(`/api/listings/${id}`,'DELETE',undefined,other)).status,403);
  const buyer=(await req('/api/demo-login','POST',{user_id:'u5'})).body.token;
  assert.equal((await req('/api/listings','POST',values,buyer)).status,403);
  assert.equal((await req('/api/listings','POST',{...values,quantity:0},token)).status,400);
  assert.equal((await req(`/api/listings/${id}`,'PATCH',{status:'Sold'},token)).status,200);
  assert.equal((await req('/api/listings?active=true')).body.some(x=>x.id===id),false);
  const fresh=createApi(file);assert.ok(fresh.db.listings.some(x=>x.id===id&&x.status==='Sold'));
}));

test('alerts validate and isolate owner and allow toggling and deletion', async()=>setup(async(req)=>{
  const token=(await req('/api/demo-login','POST',{user_id:'u1'})).body.token;
  const other=(await req('/api/demo-login','POST',{user_id:'u2'})).body.token;
  const body={crop_id:'c1',market_id:'m1',condition:'Above',target_price:100,active_status:true};
  const created=await req('/api/alerts','POST',body,token);assert.equal(created.status,201);
  const id=created.body.id;
  assert.equal((await req(`/api/alerts/${id}`,'PATCH',{active_status:false},other)).status,403);
  assert.equal((await req(`/api/alerts/${id}`,'PATCH',{active_status:false},token)).body.active_status,false);
  assert.equal((await req(`/api/alerts/${id}`,'DELETE',undefined,token)).status,200);
  assert.equal((await req(`/api/alerts/${id}`,'GET',undefined,token)).status,404);
}));
