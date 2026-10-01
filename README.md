# Inmore Operations System

Internal operations system for Inmore — branding, advertising and printed packaging, Qatar.

**V1 goal:** capture what is actually happening inside the business, centralize it, and collect
reliable data. Visibility first; optimization, automation and analytics come later.

The full technical design is in **[docs/blueprint.md](docs/blueprint.md)** — read §0 and the
Decision Register before changing anything structural.

## Layout

```
supabase/            PostgreSQL schema, RLS, triggers, local seed
packages/inmore_core Shared Dart: models, enums, repositories, providers, Excel export
apps/ops_desktop     Flutter Desktop (Windows) — the main app for staff
apps/owner_mobile    Flutter Mobile — the owner's read-only dashboard (not started)
docs/                Blueprint and design notes
```

## Running the database locally

Requires Docker Desktop running.

```bash
npx supabase start
```

That applies every migration in `supabase/migrations/` and then `supabase/seed.sql`, which
creates six dev accounts (one per role) and the starting product catalog. Credentials are listed
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

175 assertions in six files:

- `rls_test.sql` — the money boundary, the quotation invariants, the write guards, the public
  website RPC.
- `customers_requests_test.sql` — phone normalization, customer search and duplicate detection,
  `create_request`.
- `tasks_test.sql` — responsibility vs execution, self-assignment, partner turnaround.
- `quotations_test.sql` — versioning, per-product totalling, revision, approval overlap.
- `lifecycle_payments_test.sql` — stage vs waiting, cancellation and reopening, stage durations,
  payments and balance, the activity feed per role.
- `export_test.sql` — the two Excel sheets, and that they sum to the same number.

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
| 0 | Foundation — schema, RLS, triggers, seed, tests | database done; shell written and analyzing clean |
| 1 | Customers — search, duplicate detection | database done; screens pending |
| 2 | Requests + items — atomic creation | database done; screens pending |
| 3 | Tasks — assignment, My Work read model | database done; screens pending |
| 4 | Quotations — creation, versioning, revision | database done; screens pending |
| 5 | Status + timeline — waiting states, activity feed | database done; screens pending |
| 6 | Payments — balance per request | database done; screens pending |
| 7 | Excel reports — Items and Requests read models | database done; export code pending |

The whole operational backend is in place and covered by 175 assertions. What remains is the
Flutter side: every screen, plus the `.xlsx` writer in `inmore_core/export/`.

`apps/ops_desktop` passes `flutter analyze` with no issues but has never been run — it has no
`windows/` folder yet. Create it with `flutter create --platforms=windows .` before the first
`flutter run`.
