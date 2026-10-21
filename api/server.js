import { createServer as makeHttpServer } from 'node:http';
import { readFileSync, writeFile, rename } from 'node:fs';
import { mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { ensureSeed, DEFAULT_DB, pakistanToday } from './seed.js';

const collections = new Set(['users', 'crops', 'markets', 'prices', 'listings', 'alerts']);
const bad = (message, status = 400) => Object.assign(new Error(message), { status });
const exists = (items, id) => items.some(x => x.id === id);
const numeric = (v) => typeof v === 'number' && Number.isFinite(v) && v > 0;
const isDate = (s) => typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(`${s}T00:00:00Z`)) && new Date(`${s}T00:00:00Z`).toISOString().slice(0,10) === s;
const validPhone = (s) => typeof s === 'string' && /^\+?[0-9]{8,15}$/.test(s);
const listingFields = ['crop_id','quantity','asking_price','district','grade','available_from','contact_phone'];
const alertFields = ['crop_id','market_id','condition','target_price','active_status'];

export function createApi(dbPath = process.env.KISAN_DB_PATH || DEFAULT_DB) {
  ensureSeed(dbPath);
  const db = JSON.parse(readFileSync(dbPath, 'utf8'));
  let writeQueue = Promise.resolve();
  function persist() {
    const snapshot = JSON.stringify(db, null, 2);
    writeQueue = writeQueue.catch(() => {}).then(async () => {
      await mkdir(dirname(dbPath), { recursive: true });
      const temp = `${dbPath}.${randomUUID()}.tmp`;
      await new Promise((yes, no) => writeFile(temp, snapshot, error => error ? no(error) : yes()));
      await new Promise((yes, no) => rename(temp, dbPath, error => error ? no(error) : yes()));
    });
    return writeQueue;
  }
  function identity(req) {
    const token = req.headers['x-demo-token'];
    const session = db.sessions.find(s => s.token === token);
    return session && db.users.find(u => u.id === session.user_id) || null;
  }
  function farmer(req) { const user = identity(req); if (!user || user.role !== 'Farmer') throw bad('Farmer session required', 403); return user; }
  function validateListing(input) {
    if (!exists(db.crops, input.crop_id)) throw bad('Valid crop required');
    if (!numeric(input.quantity) || !numeric(input.asking_price)) throw bad('Quantity and asking price must be positive');
    if (typeof input.district !== 'string' || !input.district.trim() || input.district.length > 80) throw bad('Valid district required');
    if (!['A', 'B', 'C'].includes(input.grade)) throw bad('Grade must be A, B or C');
    if (!isDate(input.available_from) || input.available_from < pakistanToday()) throw bad('Availability date cannot be in the past');
    if (!validPhone(input.contact_phone)) throw bad('Valid fictional demonstration phone number required');
  }
  function validateAlert(input) {
    if (!exists(db.crops, input.crop_id) || !exists(db.markets, input.market_id)) throw bad('Valid crop and market required');
    if (!['Above', 'Below'].includes(input.condition)) throw bad('Condition must be Above or Below');
    if (!numeric(input.target_price)) throw bad('Target price must be positive');
    if (typeof input.active_status !== 'boolean') throw bad('Active status must be boolean');
  }
  async function respond(req, res) {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Demo-Token');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
    if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }
    const send = (code, data) => { res.writeHead(code); res.end(JSON.stringify(data)); };
    try {
      const url = new URL(req.url, 'http://localhost');
      if (url.pathname === '/health' && req.method === 'GET') return send(200, { status: 'ok', fictional: true, date: db.meta.today });
      if (!url.pathname.startsWith('/api/')) throw bad('Not found', 404);
      const [collection, id, extra] = url.pathname.slice(5).split('/');
      let body = {};
      if (['POST', 'PATCH', 'PUT'].includes(req.method)) {
        const chunks = []; let total = 0;
        for await (const chunk of req) { total += chunk.length; if (total > 32768) throw bad('Request too large', 413); chunks.push(chunk); }
        try { body = JSON.parse(Buffer.concat(chunks).toString() || '{}'); } catch { throw bad('Malformed JSON'); }
        if (!body || typeof body !== 'object' || Array.isArray(body)) throw bad('JSON object required');
      }
      if (collection === 'session' && req.method === 'GET') {
        const user = identity(req); if (!user) throw bad('Invalid session', 401);
        return send(200, user);
      }
      if (collection === 'demo-login' && req.method === 'POST') {
        const user = db.users.find(x => x.id === body.user_id);
        if (!user) throw bad('Unknown demo user', 404);
        const token = randomUUID(); db.sessions.push({ token, user_id: user.id }); await persist();
        return send(200, { user, token, demo_only: true });
      }
      if (!collections.has(collection) || extra) throw bad('Not found', 404);
      const records = db[collection];
      if (req.method === 'GET') {
        if (id) {
          const item = records.find(x => x.id === id); if (!item) throw bad('Not found', 404);
          if (['alerts'].includes(collection) && item.user_id !== identity(req)?.id) throw bad('Forbidden', 403);
          return send(200, item);
        }
        if (collection === 'alerts') { const user = farmer(req); return send(200, records.filter(x => x.user_id === user.id)); }
        if (collection === 'listings' && url.searchParams.get('mine') === 'true') { const user = farmer(req); return send(200, records.filter(x => x.user_id === user.id)); }
        if (collection === 'listings' && url.searchParams.get('active') === 'true') return send(200, records.filter(x => x.status === 'Active'));
        return send(200, records);
      }
      if (req.method === 'POST' && !id) {
        if (collection === 'users') {
          const { name, phone, district, role } = body;
          if (typeof name !== 'string' || !name.trim() || name.length > 80 || !validPhone(phone) || typeof district !== 'string' || !district.trim() || district.length > 80 || !['Farmer','Buyer'].includes(role)) throw bad('Invalid registration');
          const user = { id: randomUUID(), name: name.trim(), phone, district: district.trim(), role };
          records.push(user); const token = randomUUID(); db.sessions.push({ token, user_id: user.id }); await persist(); return send(201, { user, token, demo_only: true });
        }
        if (collection === 'listings') {
          const user = farmer(req); validateListing(body);
          const item = { id: randomUUID(), ...Object.fromEntries(listingFields.map(k => [k, body[k]])), user_id: user.id, status: 'Active', created_at: new Date().toISOString() };
          records.push(item); await persist(); return send(201, item);
        }
        if (collection === 'alerts') {
          const user = farmer(req); validateAlert(body);
          const item = { id: randomUUID(), ...Object.fromEntries(alertFields.map(k => [k, body[k]])), user_id: user.id };
          records.push(item); await persist(); return send(201, item);
        }
        throw bad('Collection is read-only', 405);
      }
      if (id && ['PATCH', 'DELETE'].includes(req.method)) {
        if (!['listings','alerts'].includes(collection)) throw bad('Collection is read-only', 405);
        const user = farmer(req); const idx = records.findIndex(x => x.id === id);
        if (idx < 0) throw bad('Not found', 404);
        if (records[idx].user_id !== user.id) throw bad('Cannot modify another user\'s record', 403);
        if (req.method === 'DELETE') { records.splice(idx, 1); await persist(); return send(200, { deleted: true }); }
        const current = records[idx];
        if (collection === 'listings') {
          if (body.status === 'Sold' && Object.keys(body).length === 1) { current.status = 'Sold'; await persist(); return send(200, current); }
          if (current.status !== 'Active') throw bad('Sold listings cannot be edited');
          const update = { ...current, ...Object.fromEntries(listingFields.filter(k => Object.hasOwn(body,k)).map(k => [k, body[k]])) };
          validateListing(update); records[idx] = update;
        } else {
          const update = { ...current, ...Object.fromEntries(alertFields.filter(k => Object.hasOwn(body,k)).map(k => [k, body[k]])) };
          validateAlert(update); records[idx] = update;
        }
        await persist(); return send(200, records[idx]);
      }
      throw bad('Not found', 404);
    } catch (error) { if (!error.status) console.error(error); send(error.status || 500, { error: error.status ? error.message : 'Internal error' }); }
  }
  return { db, server: makeHttpServer((req, res) => { void respond(req, res); }) };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.PORT || 3001);
  createApi().server.listen(port, '0.0.0.0', () => console.log(`KisanMandi fictional HTTP mock API listening on :${port}`));
}
