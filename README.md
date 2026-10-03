# Inmore Operations System

Internal operations system for Inmore — branding, advertising and printed packaging, Qatar.

**V1 goal:** capture what is actually happening inside the business, centralize it, and collect
reliable data. Visibility first; optimization, automation and analytics come later.

The full technical design is in **[docs/blueprint.md](docs/blueprint.md)** — read §0 and the
Decision Register before changing anything structural.

## Layout

```
supabase/            PostgreSQL schema, RLS, triggers, local seed
packages/inmore_core Shared Dart: models, enums, repositories, providers, realtime, Excel export
packages/inmore_ui   Shared look and language: theme, brand, English/Arabic, shared widgets
apps/ops_desktop     Flutter Desktop (Windows) — the main app for staff
apps/owner_mobile    Flutter Mobile (Android) — the owner's read-only dashboard
docs/                Blueprint; docs/brand/ holds the icon and splash sources
```

## Running the database locally

Requires Docker Desktop running.

```bash
npx supabase start
```

That applies every migration in `supabase/migrations/` and then `supabase/seed.sql`, which
creates six dev accounts (one per role) and a few placeholder partners. Credentials are listed
at the top of `supabase/seed.sql` — local only.

Studio: http://localhost:54323 · API: http://localhost:54321 · Mail: http://localhost:54324

```bash
npx supabase stop          # stop, keep data
npx supabase db reset      # wipe, re-run migrations + seed
```

## Testing the database

```bash
for f in supabase/tests/*.sql; do docker exec -i supabase_db_inmore-ops psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q < "$f"; done
```

About 240 assertions in eight files:

- `rls_test.sql` — the money boundary, the quotation invariants, the write guards, the public
  website RPC.
- `customers_requests_test.sql` — phone normalization, customer search and duplicate detection,
  `create_request`.
- `tasks_test.sql` — responsibility vs execution, self-assignment, partner turnaround.
- `quotations_test.sql` — versioning, per-product totalling, revision, approval overlap.
- `lifecycle_payments_test.sql` — stage vs waiting, cancellation and reopening, stage durations,
  payments and balance, the activity feed per role.
- `export_test.sql` — the two Excel sheets, and that they sum to the same number.
- `workflow_test.sql` — closing a request closes its open work, a priced product is cancelled
  rather than deleted, a draft quotation can be corrected and only a draft.
- `back_office_test.sql` — staff management (supervisors manage everyone but the owner, nobody
  changes their own access), stock that is the sum of its ledger and can't go below zero,
  expenses that are money-only and corrected by editing or voiding, never deleted.

They all create their own fixture data and roll back, so they are safe to run against a database
with real records in it. Run them after any change to a policy, a trigger, a view or an RPC.

## Running the desktop app

Needs the local stack running. Flutter is installed at `C:\Users\meste\flutter`.

```bash
cd apps/ops_desktop && flutter create --platforms=windows . && flutter run -d windows
```

`flutter create` only fills in the `windows/` platform folder; the Dart sources are already
written. Defaults point at the local stack, so no arguments are needed — see `lib/env.dart` for
pointing it at a hosted project.

## Four things to know before writing code

**Money is visible to OWNER and SUPERVISOR only.** It is enforced in the database, at the table
level — `quotations`, `quotation_lines`, `payments`, `task_costs` — because Supabase gives every
signed-in user the same `authenticated` Postgres role, so column privileges cannot distinguish
an owner from a designer. Consequences worth remembering:

- Every view is `security_invoker = on`, or it would read straight past that boundary.
- Amounts go only into `quotation.*`, `payment.*` and `task_cost.*` activity events. Never into
  a `request.*` or `task.*` event — those are readable by everyone.
- Sign in as `sara@inmore.local` (designer) to check: money tables must return zero rows.

**The activity log is written by database triggers, not by the app.** Do not insert state-change
events from Dart. If an event is missing, add it to a trigger in
`supabase/migrations/..._functions.sql`. The log has no UPDATE or DELETE grant for anyone —
corrections are new events. Every future metric depends on that staying true.

**Order the timeline by `activities.id`, never by `occurred_at`.** `now()` is the transaction
timestamp, so every event written by one operation shares it — `create_request` alone writes
`request.created` plus one `item.added` per item, all with the identical value. Sorting by
`occurred_at` scrambles those groups at random. `occurred_at` is for date filtering and
durations; `id` is the order things happened in.

**A denied write fails in two different ways, and the client must handle both.** An RLS policy
filters the row out *silently* — the update affects zero rows and no error is raised. A trigger
guard *raises* an exception. So a repository that treats "no exception" as success will show a
fake "saved" when a designer tries to update someone else's task. Check the returned row, not
just the absence of an error: prefer `.select()` on updates and treat an empty result as a
denial.

## Status

Blueprint §G slice:

| Step | | |
|---|---|---|
| 0 | Foundation — schema, RLS, triggers, seed, tests | done |
| 1 | Customers — search, duplicate warning | done |
| 2 | Requests + items — atomic creation | done |
| 3 | Tasks — assignment, My Work | done |
| 4 | Quotations — versioning, revision, approval | done |
| 5 | Status + timeline — waiting states, history | done |
| 6 | Payments — balance per request | done |
| 7 | Excel reports — two sheets, saved to Documents\Inmore | done |
| 8 | Back office — inventory, expenses, staff management, printable reports | done |

The V1 slice is complete and runs: sign in, find a customer, create a request with several
products, assign work, price it, approve, record a payment, read the history, export the month.

Not yet built: the website RPC wired into the React site, and a partner management screen
(partners are added from the task dialog).

## Testing the Dart layer

```bash
cd packages/inmore_core && flutter test
```

Runs the real repositories against the local stack. **This is the only thing that catches a
mis-mapped column** — models are hand-written, so `waiting_on` vs `waitingOn` is a runtime
failure the analyzer cannot see, and a field that silently reads null looks exactly like an empty
one on screen. It writes real rows; run `npx supabase db reset` afterwards.

## Testing the screens

```bash
cd apps/ops_desktop && flutter test
cd apps/owner_mobile && flutter test
```

No database needed. Every screen is drawn with sample data (`package:inmore_ui/testing.dart`) in
English and Arabic, light and dark. The run **fails on any layout overflow** — the usual way a
longer Arabic label breaks a row — and leaves a PNG of each screen in `build/screenshots/`, so a
change can be looked at without signing in.

## Look and language

Everything both apps draw with lives in `packages/inmore_ui`: the theme (neutral ink and paper,
the logo's CMYK inks for meaning and brand moments), the Rubik font (Latin and Arabic in one
family), and the shared widgets — loading placeholders, error and empty states, the stage
stepper. Decisions 22 and 23 in the blueprint say why.

- **Translations** are in `packages/inmore_ui/lib/l10n/app_en.arb` and `app_ar.arb`. After
  editing either, run `flutter gen-l10n` in `packages/inmore_ui` and commit the generated files.
  Every key needs both languages. Screens read `context.l10n`; enums use `.tr(l10n)`. Their
  English `label` is kept for the Excel export, which is always in English.
- **Right-to-left**: use `EdgeInsetsDirectional`, `AlignmentDirectional` and `start`/`end`,
  never `left`/`right`. Text a person typed goes through `UserText` or `AppField`, which lay it
  out in its own direction.
- **Theme and language** are chosen per device in Settings (sidebar account menu on the
  desktop, avatar on the phone), and on the sign-in screen.
- **Icons and splash** are generated from `docs/brand/`: `dart run flutter_launcher_icons` in
  either app, and `dart run flutter_native_splash:create` in `apps/owner_mobile`.

**Live updates.** Both apps subscribe to realtime on `requests`, `tasks` and `activities`, so
screens refresh themselves when someone else changes something. The owner's phone also keeps its
last overview on disk, encrypted, so it opens instantly and still works on a weak signal. That
data is wiped on sign-out.

**Desktop shortcuts:** Ctrl+K finds any request, Ctrl+N starts a new one, F5 refreshes, F1
opens help.

**Tour and help center (desktop).** The first time someone signs in on a computer, a short tour
points out each part of the shell; it can be replayed from Help or the account menu. The help
center (`/help`) holds step-by-step articles in both languages, shown only to the roles they
apply to. The articles are in `apps/ops_desktop/lib/features/help/help_content.dart`, English
and Arabic side by side — **update them when a screen changes**, because they quote button names
exactly. `test/tour_help_test.dart` checks every article has both languages.

## Apps

| App | Target | Who | Writes? |
|---|---|---|---|
| `apps/ops_desktop` | Windows desktop | Supervisors, designers, production | yes |
| `apps/owner_mobile` | Android (web target kept for quick verification) | The owner | **no** — read only |

The owner's app is deliberately read-only. If the owner could move a status from his phone, the
history would stop reflecting who actually did the work, and the history is the whole point.

### Demo data

```bash
docker exec -i supabase_db_inmore-ops psql -U postgres -d postgres -q < supabase/demo_data.sql
```

Six requests spread across the pipeline — blocked, overdue, unassigned, finished — so the
screens have something real in them. Not part of `seed.sql` on purpose: an empty database is the
honest starting point, and tests should not lean on fixtures they did not create.

### Running the owner app

```bash
cd apps/owner_mobile && flutter run
```

On a phone, `127.0.0.1` is the phone itself. Use `10.0.2.2` for an Android emulator, or the
machine's LAN address for a real handset:

```bash
flutter run --dart-define=SUPABASE_URL=http://10.0.2.2:54321
```

## Going live

### 1. The hosted database

Once per project. `login` opens a browser; `link` asks for the database password (Project
Settings → Database).

```bash
npx supabase login
npx supabase link --project-ref <ref>      # <ref> is the xxxx in https://xxxx.supabase.co
npx supabase db push
npx supabase functions deploy staff-admin
```

`db push` applies every migration — schema, RLS, triggers, realtime, the product catalog. It does
**not** run `seed.sql`, so no dev accounts or placeholder partners reach the hosted project. It
expects an empty `public` schema; if tables were made there by hand, drop them first.

Then, in the dashboard:

- **Authentication → Sign In / Providers**: turn **off** "Allow new users to sign up". (Locally
  `config.toml` does this; `db push` doesn't carry auth settings.) Leave the Email provider on.
- **The first owner account**: add it under Authentication → Users, then set its role and
  activate it with [`supabase/staff.sql`](supabase/staff.sql) in the SQL Editor. Everyone else is
  added from the desktop app's **Staff** screen. That needs the `staff-admin` Edge Function
  deployed above: it holds the admin key no app may have, and checks that the caller is an active
  owner or supervisor.

Later schema changes: add a migration, test locally, `npx supabase db push`. After changing
[`supabase/functions/staff-admin`](supabase/functions/staff-admin/index.ts), deploy it again.

**Trying it out before go-live.** Make `@inmore.test` accounts and activate them with
[`supabase/test_accounts.sql`](supabase/test_accounts.sql), then optionally load the demo
requests: `npx supabase db query --linked -f supabase/demo_data.sql`. Before real work starts,
run [`supabase/go_live_wipe.sql`](supabase/go_live_wipe.sql) the same way — it clears every
request, customer, partner and the activity log, and removes the test accounts. It is the only
time the activity log is ever cleared.

### 2. Pointing the apps at it

Copy `.env.example` to `.env.production` and fill in the Project URL and the publishable key
(Project Settings → API Keys). Both build scripts read it and refuse to build if it still points
at `127.0.0.1`. To try a hosted project from a dev run:

```bash
flutter run -d windows --dart-define-from-file=../../.env.production
```

### 3. Desktop installer

Needs Inno Setup 6 once: `winget install JRSoftware.InnoSetup`.

```powershell
.\scripts\build_windows.ps1
```

Produces `apps\ops_desktop\build\installer\InmoreOperations-Setup-<version>.exe` — one file,
with the VC++ runtime DLLs bundled. On each PC: run it, and since it is unsigned, SmartScreen
will say "Windows protected your PC" once → **More info → Run anyway**. It installs for the
current Windows user (no admin needed) with a Start-menu entry and an optional desktop
shortcut, and appears in Settings → Apps for uninstalling.

To ship an update, bump `version:` in `apps/ops_desktop/pubspec.yaml`, rebuild, and run the new
setup on each PC over the old one. Settings and sign-in survive.

### 4. Android app

**Signing key, once.** Every APK given to the owner must be signed with the same key, or
Android refuses to install it over the previous one. Make it outside the repo and back it up
(password manager + a copy off this PC):

```powershell
mkdir $env:USERPROFILE\.inmore
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore $env:USERPROFILE\.inmore\inmore-release.jks -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias inmore
```

Then put the password in `apps/owner_mobile/android/key.properties` (git-ignored; create it if
missing — the build script refuses while it still says `CHANGE_ME`). With PKCS12 the key
password is the store password:

```properties
storeFile=C:/Users/<you>/.inmore/inmore-release.jks
storePassword=<the password>
keyAlias=inmore
keyPassword=<the password>
```

**NDK, once.** The build needs NDK 28.2.13676358: Android Studio → Settings → Languages &
Frameworks → Android SDK → SDK Tools → tick "Show Package Details" → NDK (Side by side) →
28.2.13676358. If an empty `%LOCALAPPDATA%\Android\Sdk\ndk\28.2.13676358` folder is left from a
failed automatic install, delete it first.

**Build:**

```powershell
.\scripts\build_android.ps1
```

Produces `apps\owner_mobile\build\Inmore-<version>.apk`. Send it to the phone (cable, Drive,
WhatsApp to self), open it, and allow "Install unknown apps" for whichever app opened it.

For an update, bump **both** parts of `version: x.y.z+N` in `apps/owner_mobile/pubspec.yaml` —
`N` must go up every time — rebuild, and install over the old one.
