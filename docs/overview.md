# Inmore Operations — System Overview

A snapshot of what the system is, how it is built, and what exists today (October 2026).
For the full design and the reasoning behind each decision, see [blueprint.md](blueprint.md).

---

## 1. What it is

Inmore is a branding, advertising and printed-packaging shop in Qatar. Work arrives by phone,
WhatsApp, in person or the website; it is priced verbally, produced in-house or by outside
partners, and paid in cash, transfer or cheque.

**V1's goal is visibility, not automation:** capture what actually happens to every job, in one
place, as reliable data. Optimization, analytics and automation come later — and depend on the
data V1 collects being trustworthy.

## 2. Who uses it

| Role | App | Sees money? | What they do |
|---|---|---|---|
| **Owner** | Phone (read-only) + desktop | Yes | Watches the business; can do anything on desktop |
| **Supervisor** | Desktop | Yes | Takes requests, prices them, assigns work, records payments and expenses, manages staff |
| **Designer** | Desktop | **No** | Works their tasks; can add customers and their own tasks; views stock |
| **Production** | Desktop | **No** | Works their tasks; records stock in and out |

Staff accounts are created from the desktop app's **Staff** screen by the owner or a supervisor
(only the very first owner account is made in the Supabase dashboard). There is no self sign-up.

## 3. The core idea: the request

A **request** is one customer asking for something. It holds everything about that job:

```
Customer ─┬─ Request ─┬─ Products (request items)  — what was asked for, from catalog or free text
          │           ├─ Tasks                     — who is doing what (an employee or a partner)
          │           ├─ Quotations (versioned)    — the price told to the customer, per product
          │           ├─ Payments                  — money received (insert-only ledger)
          │           └─ Activities                — the permanent history of all of the above
```

Two things move independently:

- **Stage** — `New → Quotation → Design → Customer approval → Production → Delivery → Completed`
  (or `Cancelled`). Stages can be set forward or back; they are not enforced transitions.
- **Waiting** — whether it's blocked: on the *customer*, *payment*, a *partner*, or *on hold*.
  Blocking never changes the stage, so "in production, waiting for payment" stays answerable.

**Quotations are verbal.** Nothing is sent from the app. *Presented* means "told the customer, by
any channel". A presented quotation is never edited — revising creates v2, v3… and the earlier
version is kept as *Superseded*. Approving one marks its products approved and sets what's owed.
A product can be in only one approved quotation at a time, so totals never double-count.

## 4. Architecture

```
┌──────────────────────┐   ┌──────────────────────┐
│ Desktop app (Windows) │   │ Owner app (Android)  │   Flutter, one codebase style
│ apps/ops_desktop      │   │ apps/owner_mobile    │
└──────────┬───────────┘   └──────────┬───────────┘
           │   packages/inmore_ui   — theme, brand, English/Arabic, shared widgets
           │   packages/inmore_core — models, repositories, providers, realtime, Excel export
           └──────────────┬──────────────┘
                          │  supabase_flutter (REST + RPC + Realtime), publishable key
                ┌─────────▼──────────┐
                │ Supabase (hosted)   │  Postgres 15 + Auth (email/password) + Realtime
                │ supabase/migrations │  schema, RLS, triggers, views, RPCs — the source of truth
                │ supabase/functions  │  staff-admin: account create / password / delete
                └────────────────────┘
```

The one Edge Function exists because creating a sign-in, resetting a password and deleting an
account need the Auth admin key, which no app may hold. It checks the caller is an active owner or
supervisor. Everything else about an account (name, role, access) is an ordinary table update that
Postgres polices, so the history records who did it.

**The database is where the rules live.** Anything that must be true no matter which app wrote
it is enforced in Postgres; the apps are presentation. Four rules shape everything:

1. **Money is invisible to designers and production — enforced by row-level security**, not by
   hiding buttons. Quotations, quotation lines, payments, task costs, stock unit costs and
   expenses live in tables only the owner and supervisors can read. Every view is `security_invoker`, so views can't leak
   past that. Money never appears in a non-money history event.
2. **The history is written by database triggers, never by the apps**, and nobody can edit or
   delete it. A correction is a new event. Every future metric (time per stage, who did what,
   how long waiting on customers) is computed from this log, so its integrity is the asset.
3. **Writes are guarded twice.** RLS filters rows (a denied update silently affects zero rows);
   trigger guards raise errors (e.g. a designer changing a request's title). Repositories check
   the returned row, never "no exception = success".
4. **Multi-step writes are single database functions** (RPCs) so a failure can't leave half a
   request: `create_request`, `create_quotation`, `revise_quotation`, `edit_draft_quotation`,
   `remove_request_item`, `search_customers`, `create_public_request` (for the website).

**Read models** are views: `v_request_summary` (the board), `v_request_financials` (approved /
paid / balance), `v_task_summary` (My work), `v_activity_feed` (the timeline),
`v_request_stage_durations` (time in each stage — the analytics seed), `v_export_items` /
`v_export_requests` (the two Excel sheets), `v_report_payments` (money in), `v_inventory` (stock
on hand, computed from the movement ledger) and `v_stock_movements`.

**Live updates:** both apps subscribe to Realtime on `requests`, `tasks` and `activities`, and the
desktop also on stock, expenses and staff; screens refresh themselves when someone else changes
something.

**Client stack:** Flutter 3.47, Riverpod, go_router (desktop), supabase_flutter, `excel`, `pdf` +
`printing` (reports).
Bilingual English/Arabic with full right-to-left, chosen per device; Western digits; currency
`ر.ق` / QAR. Excel exports are always English.

## 5. What's built

### Desktop app — the working tool
- **Work board** — every open request; blocked, overdue and unassigned ones pulled to the top;
  stage tabs with counts, search, "mine", include closed, sort.
- **My work** — a person's tasks grouped doing / to do / blocked, status changed in place.
- **Request page** — stage stepper and blocking; products (add, edit while pending, remove —
  a priced product is cancelled rather than deleted); work (assign to staff or a partner, due
  dates, reassign, status, partner cost, cancel); quotations (draft, edit draft, present,
  approve/reject, revise); payments; money panel (approved / paid / balance); details
  (supervisor, due date, notes); full history. Mark completed and reopen.
- **New request** — find or add the customer, title, due date, notes, several products at once.
- **Customers** — search by name/company/phone (phone matching ignores formatting); duplicate
  phone warning (warns, never blocks).
- **Inventory** — stock items with on-hand quantity (computed from an insert-only ledger of
  received / taken out / stock count), reorder levels with Low and Out flags, per-item history,
  unit cost and stock value for managers. Not linked to requests yet.
- **Expenses** — a month at a time: day-to-day and monthly fixed costs, by category, against
  payments received (net). Copy last month's fixed costs forward. Corrected by editing or
  voiding with a reason; never deleted; every step in the history. Managers only.
- **Reports** — six reports (sales by product, requests, payments received, expenses, stock,
  income vs expenses). Shape them on screen (columns and order, sort, group with subtotals,
  search, leave rows out, title and note) without changing any record; print or save a PDF on
  Inmore's letterhead (logo, business details, who prepared it); export to Excel as shown, or the
  accountant's two-sheet workbook. Business details are editable.
- **Staff** — add accounts (temporary password shown once), edit name / phone / role, reset
  passwords, remove or restore access, delete a never-used account. Supervisors manage everyone
  but the owner; nobody changes their own role or access.
- **Ctrl+K** finds any request from anywhere; Ctrl+N, F5, F1 shortcuts.
- **First-run tour** and a **help center** (role-filtered, bilingual, searchable).
- Launch animation, light/dark themes, offline banner.

### Owner app — read-only by design
Overview (pipeline, this week's numbers, latest), Attention (blocked / overdue / unassigned),
Money (approved, received, still owing), People (who has what, who's late), request detail with
stage progress and timeline. The last overview is kept encrypted on the phone so it opens
instantly and works on a weak signal; wiped on sign-out. Read-only on purpose: if the owner moved
statuses from their phone, the history would stop showing who did the work.

### Delivery
- One hosted Supabase project; apps point at it via `.env.production`.
- `scripts/build_windows.ps1` → Inno Setup installer (per-user, no admin, unsigned).
- `scripts/build_android.ps1` → release-signed APK, sideloaded to the owner's phone.
- Tests: ~240 database assertions (`supabase/tests/`), screen tests that render every desktop and
  phone screen in both languages and themes, repository integration tests against a local stack.

## 6. Known limits and gaps (true today)

- **Status:** pre-launch. The hosted project holds test data and must be wiped
  (`supabase/go_live_wipe.sql`) before real use; migrations 012–013 still need `supabase db push`,
  and the `staff-admin` function `supabase functions deploy`.
- **Payments can't be corrected in the app** — insert-only, amounts must be positive.
- **No "forgot password" on the sign-in screen** — a manager resets it from the Staff screen.
- **Inventory isn't linked to requests** — stock is recorded by hand; no purchase orders or
  suppliers.
- **Expenses aren't linked to requests or partners** — partner costs live on tasks, separately.
- **Designers and production can't move a request's stage** in the app (the database allows it).
- **No notifications** — nothing pushes to anyone; people look at the board or the phone.
- **Website form not wired** — `create_public_request` exists; the website doesn't call it yet.
- **In the schema but not on any screen:** per-product *fulfillment* (in-house / external),
  quotation *valid until* and notes, product catalog editing, customer archiving, task notes.
- **Partners** can be added (from the task dialog) but not edited or listed on their own screen.
- **Installers are unsigned** (SmartScreen warning) and **updates are manual** (re-run setup /
  reinstall APK). No crash or error reporting.
- No attachments (artwork, proofs), no customer-facing documents (quotation PDF, invoice), no
  purchasing — deliberately out of V1.
- **PDF reports use Windows' Segoe UI for Arabic text** (Rubik lacks the joined letter forms the
  PDF library needs); fine on any Windows PC, the only platform the desktop app runs on.

## 7. Useful context for new ideas

- **The data already being collected** — every stage change, block, assignment, task start/finish,
  quotation step and payment, with who and when — supports later work on cycle times, bottlenecks,
  waiting-on-customer time, workload per person, partner turnaround and cost, conversion from
  quotation to approval, and cash collection. `v_request_stage_durations` is the starting point.
- **Constraints any enhancement should respect:** money stays behind RLS; the history stays
  append-only and trigger-written; quotations stay verbal-first; multi-step writes go through RPCs;
  every new string in both languages and every layout right-to-left safe; the owner's app stays
  read-only unless that decision is revisited deliberately.
- **Scale:** a small team (a handful of staff, one owner) — simple,
  reliable and fast to use beats clever.
