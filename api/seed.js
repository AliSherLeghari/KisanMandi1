import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
export const DEFAULT_DB = resolve(dirname(fileURLToPath(import.meta.url)), 'data', 'store.json');

export const pakistanToday = (now = new Date()) => new Date(now.getTime() + 5 * 60 * 60 * 1000).toISOString().slice(0, 10);
const shiftDay = (iso, delta) => new Date(Date.parse(iso + 'T12:00:00Z') + delta * 86400000).toISOString().slice(0, 10);
export function createSeed(today = pakistanToday()) {
  const crops = [
    ['Wheat', 'Grains'], ['Rice', 'Grains'], ['Maize', 'Grains'],
    ['Cotton', 'Cash crops'], ['Sugarcane', 'Cash crops'],
    ['Onion', 'Vegetables'], ['Tomato', 'Vegetables'], ['Potato', 'Tubers'],
  ].map(([name, category], i) => ({ id: `c${i + 1}`, name, category }));
  const markets = [['Hyderabad Mandi', 'Hyderabad'], ['Sukkur Mandi', 'Sukkur'], ['Larkana Mandi', 'Larkana']]
    .map(([name, district], i) => ({ id: `m${i + 1}`, name, district }));
  const users = [
    ['Aman Example', 'Hyderabad', 'Farmer'], ['Sana Example', 'Sukkur', 'Farmer'],
    ['Bilal Example', 'Larkana', 'Farmer'], ['Noor Example', 'Hyderabad', 'Farmer'],
    ['Rida Example', 'Sukkur', 'Buyer'], ['Danish Example', 'Larkana', 'Buyer'],
  ].map(([name, district, role], i) => ({ id: `u${i + 1}`, name, phone: `+92000000000${i}`, district, role }));
  const bases = [110, 185, 95, 225, 80, 145, 125, 120];
  const prices = [];
  for (let c = 0; c < crops.length; c++) {
    for (let m = 0; m < markets.length; m++) {
      for (let day = 0; day < 14; day++) {
        prices.push({
          id: `p${c + 1}_${m + 1}_${day + 1}`,
          crop_id: crops[c].id, market_id: markets[m].id,
          date: shiftDay(today, day - 13),
          price: bases[c] + m * 7 + Math.round(Math.sin((day + c * 2 + m) / 2) * 7) + day * (c % 2 === 0 ? 1 : -0.5),
        });
      }
    }
  }
  const listings = Array.from({ length: 12 }, (_, i) => ({
    id: `l${i + 1}`, user_id: `u${(i % 4) + 1}`, crop_id: `c${(i % 8) + 1}`,
    quantity: (i + 2) * 75, asking_price: bases[i % 8] + (i % 3 - 1) * 13,
    district: markets[i % 3].district, grade: ['A', 'B', 'C'][i % 3],
    available_from: shiftDay(today, i % 4),
    contact_phone: users[i % 4].phone,
    status: i < 10 ? 'Active' : 'Sold', created_at: new Date(Date.parse(`${today}T12:00:00Z`) - i * 3600000).toISOString(),
  }));
  const alerts = Array.from({ length: 5 }, (_, i) => ({
    id: `a${i + 1}`, user_id: `u${(i % 4) + 1}`, crop_id: `c${i + 1}`, market_id: `m${(i % 3) + 1}`,
    condition: i % 2 ? 'Below' : 'Above', target_price: bases[i] + (i % 2 ? 20 : -20), active_status: true,
  }));
  return { users, crops, markets, prices, listings, alerts, sessions: [], meta: { today, fictional: true } };
}
export function ensureSeed(path = DEFAULT_DB) {
  if (!existsSync(path)) { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, JSON.stringify(createSeed(), null, 2)); }
  return path;
}
if (process.argv.includes('--reset')) {
  const path = process.env.KISAN_DB_PATH || DEFAULT_DB;
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(createSeed(), null, 2));
  console.log(`Reset 6 HTTP collections at ${path}`);
}
