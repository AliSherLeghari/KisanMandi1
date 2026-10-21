# KisanMandi — Crop Prices & Produce Marketplace

**Team:** Confirm_Jannati · **Challenge:** [HacktoberFest 3.0 Issue #11](https://github.com/AWSCloudClubMuet/HacktoberFest-3.0/issues/11)

A **Flutter Android app** for Sindh farmers and buyers, backed by a seeded **HTTP mock API**. All names, phone numbers, and PKR/kg crop prices are fictional demonstration data, not real-time mandi prices.

> **Important:** An APK needs a reachable HTTP API. The API is written in Node.js and must be deployed to a persistent HTTPS Node host before the APK can fetch its data outside a local development network. An APK built without `KISAN_API_BASE_URL` displays a setup error rather than falsely presenting static prices.

## Implemented milestone mapping

| Issue #11 milestone | Features |
|---|---|
| 1. Roles & prices | HTTP onboarding, Farmer/Buyer navigation, market selection, crop search/category filter, latest and previous daily price/change, `RefreshIndicator` |
| 2. Trends & comparison | `fl_chart` 14-day line chart, min/max/average, ranking across three markets |
| 3. Alerts | Add/edit/enable/delete Above/Below thresholds, equality-inclusive triggers, refresh evaluation, tab badge |
| 4. Marketplace | Active listing search/filter/sort, details, Call/WhatsApp links, create/edit/Sold/delete; server ownership checks |
| 5. Calculator | Market price, quantity, unit production cost, revenue/cost/profit/margin, ±20% simulation |
| 6. Seeded HTTP API | `users`, `crops`, `markets`, `prices`, `listings`, `alerts`; 6 users, 8 crops/4 categories, 3 markets in different districts, 336 prices (14 dates × 24 pairs), 12 listings, 5 alerts |

## Requirements

- Flutter stable + Dart 3.4 or later for app development
- Node.js 20+ for the backend (uses only built-in modules; no `npm install` necessary)
- Android device or cloud CI runner for APK compilation

## Run the HTTP mock API

```bash
cd api
npm start                    # defaults to http://localhost:3001
npm test                     # HTTP integration and seed verification
npm run seed                 # DESTRUCTIVELY reset the fictional dataset
```

`api/data/store.json` is generated on first run and persists records across ordinary restarts. Set `KISAN_DB_PATH` to change its location (e.g. a persistent mounted disk). **Do not reset during normal operation.** The sample data is generated for the current Pakistan date when seeded; if left running for weeks, the demo will still display the latest seeded date and listing validation uses the current Pakistan date.

Verify endpoints with `http://localhost:3001/health`, `/api/crops`, `/api/markets`, `/api/prices`, `/api/users`, `/api/listings?active=true`. Private alerts require a demo session token sent as `X-Demo-Token`. `POST /api/users` registers an unverified demo user and returns `{user,token}`; `POST /api/demo-login` with `{ "user_id": "u1" }` creates a seeded farmer demo session or use `u5` for a buyer.

### API routes

| Resource | Supported HTTP operations |
|---|---|
| `/api/users` | GET, POST registration |
| `/api/crops`, `/api/markets`, `/api/prices` | GET list, GET by ID |
| `/api/listings` | GET list or `?active=true` / `?mine=true`, POST Farmer listing |
| `/api/listings/:id` | GET, PATCH edit/`{ "status": "Sold" }`, DELETE owner-only |
| `/api/alerts` | GET current farmer alerts, POST |
| `/api/alerts/:id` | GET owner-only, PATCH, DELETE owner-only |
| `/api/session` | GET current demo user |
| `/api/demo-login` | POST `{ "user_id": "u1" }` or another seeded fictional user ID |

Listings use positive `quantity` (kg) and `asking_price` (PKR/kg), grade A/B/C, Sindh district, ISO date no earlier than today, and fictional `contact_phone`. Market-rate labels compare the listing PKR/kg price to the same crop's latest average across markets; 95–105% inclusive is **At market**. No cross-crop comparison.

### Security caveats

The backend **checks a server-issued session token**, Farmer role, record ownership, and positive-value/date rules. It does not trust client-supplied ownership IDs. However, `POST /api/demo-login` deliberately lets anyone impersonate fictional seeded personas; this is **not production authentication**. Seeded phone numbers are non-working, deliberately fictional. Demo contacts open a dialer or WhatsApp but are not actual reachable sellers. Do not deploy as a real farmer marketplace without genuine authentication, rate limiting, HTTPS, privacy review, and data safeguards.

## Run Flutter

When cloning the repository for the first time, generate the Android platform wrapper (this is also done automatically in CI):

```bash
flutter create --platforms=android --org pk.kisanmandi --project-name kisanmandi .
python3 scripts/ensure_android_internet.py
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001
```

`10.0.2.2` is the Android emulator's alias for the host computer, not a hosted URL. Release Android should use **HTTPS** (configure a public deployed endpoint, not localhost). For local HTTP debugging, Android may require a debug-only cleartext network security configuration.

## Cloud APK build (no local Flutter setup)

The `.github/workflows/android-apk.yml` workflow generates the Android wrapper, runs backend tests, Flutter analysis/tests, builds a release APK, and uploads the downloadable `kisanmandi-android-apk` artifact. It runs on pushes/PRs and supports **Actions → Run workflow**.

To make the APK function over mobile data, deploy the backend and set the repository GitHub Actions variable:

`Settings → Secrets and variables → Actions → Variables → New repository variable`

**Name:** `KISAN_API_BASE_URL`

**Value:** the actual deployed HTTPS URL without `/api` (for example `https://your-own-host.example`, which is only a format illustration—not an actual deployed endpoint).

Trigger a new Actions run and install the fresh APK artifact. A successful APK build does **not** verify a deployed backend; test the HTTPS `/health` endpoint first and then open the APK on Android.

## Demo walkthrough

1. Start the HTTP API, then configure the app to connect to it.
2. Choose **Demo Farmer** (u1), or register fictional details.
3. Select Hyderabad Mandi, inspect prices and daily change, open Wheat for 14-day chart and market ranking.
4. Open Alerts, create a threshold equal to the selected price, then refresh and see its triggered badge.
5. Create a Grade A listing with quantity, price, fictional phone, district and nonpast date; filter marketplace and open details.
6. Edit the listing, mark it Sold, confirm it disappears from public active listings.
7. Open Profit Calculator via the calculator icon and move the price slider from −20% to +20%.
8. Switch to **Demo Buyer** (u5) and confirm only Prices and Marketplace tabs are visible.

## Verified vs unverified

- API automated integration tests are executable with Node.js (`cd api && npm test`).
- Flutter tests and APK compilation require Flutter SDK; GitHub Actions runs them in a hosted environment. No claim of passing Flutter analysis or a successful APK should be made until the workflow completes.
- This repository contains no deployment account credentials or public backend URL; hosting requires a separate deployment step.
