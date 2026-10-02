# Inmore Operations System — V1 Implementation Blueprint

Status: draft for review. No application code written yet.
Date: 2026-10-01

**V1 thesis:** capture operational reality, centralize it, and lay down a trustworthy data trail.
Everything below is sized for one developer, ~6 users, and a business that does not follow a clean
linear workflow.

---

## 0. Where the Sketch Slipped

The kickoff brief was a sketch, and a good one. These are the places where it contradicts itself
or where a stated field is not actually a field. Each is resolved below; none change the shape of
the system.

**1. `WAITING_*` and `ON_HOLD` were listed as statuses.** They are not stages — they are reasons a
stage is stuck. Folding them into one enum means a job blocked on payment loses the fact that it
was in production, and "time waiting for customer" becomes unrecoverable. → Two columns,
`status` + `waiting_on` (§B).

**2. "Payment can be PARTIAL or FULL" is not a property of a payment.** Partial-vs-full is a
relationship between the sum of payments and the request total. Stored on the row it goes stale
immediately: a payment marked FULL stops being full the moment a fourth item is added. → `kind`
records intent (`DOWN_PAYMENT | PARTIAL | FINAL`); partial-vs-full is always derived (§D).

**3. "Each product has its own quotation" + "the request has an overall total" do not compose.**
If Product B's quotation is rejected and re-issued while A's stands, "the overall total" is
undefined. → Header + lines, plus an explicit invariant: **an item may be covered by at most one
APPROVED quotation at a time**, trigger-enforced. Only then is the request total a sum (§D).

**4. Requests may originate from a designer — but designers were not given write access.** The
brief lists `DESIGNER` as a request source in §4 and then describes a permissions model where
supervisors own creation. → Designers can create requests and add items; they still cannot touch
money (§E).

**5. "Quotation approved" was treated as a system event, but the quotation is verbal.** There is
no document and no digital copy. Calling the state `SENT` with a `sent_at` invites a future
reader to assume something was emailed. → The state is `PRESENTED`, meaning *communicated to the
customer by any channel, including in person*. The system records the operational fact, not the
channel (§B).

**6. The real customer-facing artifact was missing from the brief entirely.** The quotation is
verbal; the thing that actually carries the numbers is **the supervisor's internal report**. If
the system does not produce that report, supervisors keep building it in Excel, and the system
holds a copy of the truth instead of the truth. → Excel export is promoted out of "deferred" and
into V1, as step 7 of the slice (§G). This is the single most important change in this revision.

**7. Restricting money to OWNER + SUPERVISOR leaks in three places the brief could not have
foreseen.** Worth stating plainly because each one is invisible until it isn't:
   - `task.external_cost` sat on a table everyone reads → moved to `task_costs` (§D).
   - The activity timeline carries payment amounts in `metadata` → policy-filtered by
     `entity_type` (§E).
   - **Postgres views bypass the RLS of their base tables** unless created with
     `security_invoker = on`. `v_request_summary` carried `balance`. → money is out of the
     shared view entirely, and every view is `security_invoker` (§D).

**8. My own first draft was wrong about column-level permissions.** It proposed
`GRANT UPDATE (status, waiting_on)` to restrict designers. In Supabase every signed-in user shares
the single `authenticated` Postgres role, so column GRANTs cannot distinguish an OWNER from a
DESIGNER. → Column-level write rules are enforced by trigger guards instead (§E).

---

## A. Domain Model

### Entities (11 core + the event log)

| Entity | Purpose | Notes |
|---|---|---|
| `employee` | Staff member and app user | 1:1 with a Supabase auth user |
| `customer` | Who is asking | Deliberately thin |
| `request` | **The spine.** One customer ask | Exists from first contact, even if it dies |
| `request_item` | One requested product/service inside a request | Catalog-linked *or* free-form |
| `product` | Catalog of common products/services | A vocabulary, not a constraint |
| `quotation` | A priced offer against a request | Versioned; may cover some or all items |
| `quotation_line` | Price for one request item | Where per-product pricing lives |
| `task` | A unit of work with an executor | Executor = employee **or** partner |
| `payment` | Money received against a request | Ledger of events, not accounting |
| `task_cost` | What an external task cost us | Split off `task` so money stays invisible to designers/production |
| `partner` | External supplier / printer | Thin for now |
| `activity` | Append-only event log | The foundation for later analytics |

### Relationships

```
customer 1──* request
request  1──* request_item      *──1 product (nullable)
request  1──* quotation         1──* quotation_line  *──1 request_item
request  1──* task              *──1 employee (assignee)  XOR  *──1 partner
task     1──0..1 task_cost
request  1──* payment
request  1──* activity          (activity also points at any entity)
employee 1──* request           (as responsible supervisor)
```

### Decisions worth naming

**1. `request_item`, not `request_product`.**
A line may be `500 custom printed boxes, 3-colour, matte` with no catalog row behind it.
`product_id` is nullable; `name` is always stored on the item as a snapshot, so renaming or
retiring a catalog entry never rewrites history. The catalog exists to make the common cases
structured enough to count later — it is a vocabulary, not a gate.

**2. Responsibility is not execution — two different columns on two different tables.**
`request.supervisor_id` is the customer-relationship owner. `task.assignee_id` is who does the
work. They are never the same field. A request has exactly one supervisor and any number of tasks.

**3. A partner is an executor, not a parallel universe.**
`task` carries either `assignee_id` (employee) or `partner_id` (external), enforced by a check
constraint. One table then answers *who is doing what*, *how long did the partner take*
(`started_at` → `completed_at`), *how often do we use this partner*, and *which jobs went
external* — without a second, near-duplicate `partner_job` table.
*Tradeoff:* if partner economics later grow POs, invoices, and per-partner pricing, split out a
`partner_job` table then. That migration is cheap; building it now produces a table nobody fills.

**4. Quotation is header + lines, scoped to the request.**
The brief says "Product A → Quotation A". Header/lines supports that *and* the common case,
because a quotation may cover one item or all of them:

- one quotation per item → three quotations, one line each
- one quotation for the whole request → one quotation, three lines

Either way the request total is a single query, and a customer-facing document maps to one row.
*Tradeoff:* a pure per-item quotation table is marginally simpler, but then "what we quoted this
customer" becomes a synthetic concept and revisions get ambiguous. Header + lines is the boring,
durable choice.

**5. No separate "order" entity.** A request that is approved and in production *is* the order.
A second entity would double the lifecycle at this size for no gain.

### Entities deliberately NOT created in V1

`invoice`, `delivery_note`, `purchase_order`, `inventory_item`, `stock_movement`,
`file`/`attachment`, `message`/`thread`, `notification`, `price_list`, `permission`,
`customer_contact` (a customer has one contact in V1: name + phone).

---

## B. Lifecycle

### The key modelling decision: stage and waiting are different things

A single flat enum containing both `PRODUCTION` and `WAITING_PAYMENT` destroys information. When
a job is stuck waiting for a down payment you no longer know it was in production, and when it
unblocks you have to guess where it returns to.

So a request carries **two** columns:

```
status      (where in the pipeline)   NEW → QUOTATION → DESIGN → CUSTOMER_APPROVAL
                                      → PRODUCTION → DELIVERY → COMPLETED
                                      (+ CANCELLED, terminal)

waiting_on  (why it is not moving)    NULL | CUSTOMER | PAYMENT | PARTNER | INTERNAL
```

`waiting_on IS NOT NULL` is the on-hold flag. It is orthogonal to stage and can be set or cleared
at any stage. This gives, correctly and for free:

- "time waiting for customer" and "time waiting for payment" as first-class metrics
- an owner-dashboard *blocked* list that does not lie about where the work actually is
- no combinatorial explosion of enum values

### Transition rules — intentionally loose

V1 enforces almost nothing:

- **Any** stage → **any** stage is allowed; every change is logged with `from` and `to`.
- `COMPLETED` / `CANCELLED` set `completed_at` / `cancelled_at` (trigger-enforced). Moving back out
  clears the timestamp and logs `request.reopened`.
- `CANCELLED` requires a `cancel_reason`.

Rationale: we do not yet know which transitions genuinely occur. A rigid state machine written
before the data exists will be fought by users within a week, and the workarounds will be worse
than the disorder they replace. After a few months the activity log shows exactly which
transitions happen — *then* we constrain the ones that are always mistakes.

### Items, quotations, and multiple executors inside one lifecycle

- **Items** carry a narrow `status`: `PENDING | APPROVED | REJECTED | CANCELLED`. This is a record
  of the customer's decision *per product*, not a second progress pipeline. Per-item progress is
  visible through that item's tasks. Resisting a full per-item lifecycle is deliberate — the
  request is the unit staff think in.
- **Quotations** have a small lifecycle of their own: `DRAFT → PRESENTED → APPROVED | REJECTED |
  SUPERSEDED`. A revision is a new row with `version = previous + 1`; the old row becomes
  `SUPERSEDED`. Nothing is edited in place once presented, so "the quotation changed" is
  answerable.
  `PRESENTED` means **communicated to the customer by any channel** — spoken across the counter,
  on the phone, on WhatsApp. Inmore's quotations are verbal and have no digital copy, so the
  system is recording an operational fact with a timestamp and an author, not sending anything.
  Approval arrives the same way: `decided_at` plus who recorded it.
  Approving a quotation sets its lines' request items to `APPROVED` (trigger), and is refused if
  any of those items is already covered by another APPROVED quotation — supersede or reject that
  one first. That invariant is what makes the request total a plain sum.
- **Multiple executors** need no lifecycle support: tasks are independent rows with their own
  `TODO | IN_PROGRESS | BLOCKED | DONE | CANCELLED`. A request's stage is moved by a human, not
  derived from its tasks. Deriving it would be wrong the first time someone starts printing before
  design is formally marked done — which will happen.
- **Payment** never gates a status transition in V1. It is recorded; `waiting_on = PAYMENT`
  expresses the block. Balance is derived: approved quotation total minus payments received.

---

## C. Activity Model

This is the part of V1 that must be right, because everything in V2–V4 reads from it.

### Shape

```
activity
  id            bigint identity        -- monotonic, cheap ordering
  occurred_at   timestamptz not null default now()
  actor_kind    EMPLOYEE | SYSTEM | CUSTOMER
  actor_id      uuid null → employee   -- null for SYSTEM / CUSTOMER
  entity_type   text                   -- 'request' | 'quotation' | 'task' | ...
  entity_id     uuid
  request_id    uuid null → request    -- denormalized: the request this happened under
  event_type    text                   -- e.g. 'request.status_changed'
  from_value    text null
  to_value      text null
  metadata      jsonb not null default '{}'
```

Three choices to defend:

**`request_id` is denormalized onto every row.** The request timeline is the most common read in
the system (desktop detail screen, owner mobile). Without this column, rendering one timeline is a
union across six tables; with it, it is one indexed query. The cost is a single column that
triggers populate automatically.

**`from_value` / `to_value` are typed-out columns; everything else is `metadata` jsonb.** Almost
every meaningful event is a transition, and durations come from from/to pairs. Keeping them as
real columns keeps the analytics SQL readable. Amounts, ids, and free text go to `metadata`.

**Events are written by database triggers, not by the client.** Flutter talks to Postgres directly
through PostgREST. Any log the client is responsible for writing *will* have holes — a crash, an
offline moment, a second client, a manual SQL fix. Triggers on `requests`, `request_items`,
`quotations`, `tasks`, and `payments` make the log a property of the data rather than of the app's
good behaviour. The client may insert *additional* events (e.g. `request.note_added`) but never
the state-change ones.

### Event vocabulary (V1)

`event_type` is `entity.verb_past_tense`, stored as plain text (not an enum, so adding one is a
no-op migration):

```
request.created             request.status_changed      request.waiting_set
request.supervisor_changed  request.waiting_cleared     request.reopened
request.cancelled           request.completed           request.note_added
item.added                  item.removed                item.decision_changed
quotation.created           quotation.presented         quotation.approved
quotation.rejected          quotation.superseded
task.created                task.assigned               task.status_changed
task.completed              task.partner_assigned       task_cost.recorded
payment.recorded
customer.created            customer.updated
```

**Rule for whoever writes the next trigger:** amounts go only into `quotation.*`, `payment.*` and
`task_cost.*` events. Never into a `request.*` or `task.*` event. Those are readable by every
employee, and money is not (§E). The read policy filters by `entity_type`, so a price smuggled
into a request event is a silent leak that no policy will catch.

### Immutability

`activity` grants no UPDATE or DELETE to any role, and its RLS policies permit neither. Triggers
are `security definer` so they can always insert. Corrections are new events, never edits. This is
precisely what makes the duration metrics trustworthy a year from now.

### What it buys us (enabled now, built later)

Every metric in the brief falls out of this table plus one view: request→quotation time, design
duration, production duration, time waiting on customer, time waiting on payment, employee
workload, product demand, customer frequency, partner activity, bottlenecks.

A view `v_request_stage_durations` using
`lead(occurred_at) over (partition by request_id order by occurred_at)` over
`event_type = 'request.status_changed'` yields per-stage dwell time directly.
**We build that one view in V1 and zero dashboards.**

---

## D. PostgreSQL Schema

Conventions: `uuid` primary keys (`gen_random_uuid()`), `timestamptz` everywhere (UTC stored,
Asia/Qatar rendered), `created_at` / `updated_at` on mutable tables with a shared `touch_updated_at`
trigger, money as `numeric(12,2)`, currency fixed to QAR in V1.

### Enums

```sql
create type employee_role   as enum ('OWNER','SUPERVISOR','DESIGNER','PRODUCTION');
create type request_source  as enum ('SUPERVISOR','DESIGNER','WEBSITE','OTHER');
create type request_status  as enum ('NEW','QUOTATION','DESIGN','CUSTOMER_APPROVAL',
                                     'PRODUCTION','DELIVERY','COMPLETED','CANCELLED');
create type waiting_reason  as enum ('CUSTOMER','PAYMENT','PARTNER','INTERNAL');
create type item_status     as enum ('PENDING','APPROVED','REJECTED','CANCELLED');
create type fulfillment_mode as enum ('UNDECIDED','INTERNAL','EXTERNAL');
create type quotation_status as enum ('DRAFT','PRESENTED','APPROVED','REJECTED','SUPERSEDED');
create type task_type       as enum ('DESIGN','PREPRESS','PRODUCTION','EXTERNAL','DELIVERY','OTHER');
create type task_status     as enum ('TODO','IN_PROGRESS','BLOCKED','DONE','CANCELLED');
create type payment_method  as enum ('CASH','ONLINE','BANK_TRANSFER','CHEQUE');
create type payment_kind    as enum ('DOWN_PAYMENT','PARTIAL','FINAL');
create type actor_kind      as enum ('EMPLOYEE','SYSTEM','CUSTOMER');
```

Postgres enums are used for closed sets (cheap to read, map 1:1 to Dart enums, `alter type ... add
value` when needed) and plain `text` for the open set (`activity.event_type`).

### Tables

```sql
-- staff / app users -------------------------------------------------------
create table employees (
  id          uuid primary key references auth.users(id) on delete restrict,
  full_name   text not null,
  email       text not null unique,
  phone       text,
  role        employee_role not null,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- customers ---------------------------------------------------------------
create table customers (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  phone       text,
  company     text,
  email       text,
  notes       text,
  is_archived boolean not null default false,
  created_by  uuid references employees(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index customers_phone_idx on customers (phone);
create index customers_name_trgm_idx on customers using gin (name gin_trgm_ops);
create index customers_company_trgm_idx on customers using gin (company gin_trgm_ops);
```

`phone` is indexed but **not** unique: shared numbers and missing numbers are both real. Duplicate
detection is a soft warning in the UI ("3 customers share this number — use one of these?").

```sql
-- product catalog ---------------------------------------------------------
create table products (
  id           uuid primary key default gen_random_uuid(),
  name         text not null unique,
  category     text,
  default_unit text,                      -- 'pcs', 'roll', 'sqm'
  is_active    boolean not null default true,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);

-- partners ----------------------------------------------------------------
create table partners (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  contact_name text,
  phone        text,
  email        text,
  services     text,                      -- free text in V1, not a taxonomy
  notes        text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- requests ----------------------------------------------------------------
create table requests (
  id             uuid primary key default gen_random_uuid(),
  number         int not null generated by default as identity,  -- human ref: #1042
  customer_id    uuid not null references customers(id) on delete restrict,
  supervisor_id  uuid references employees(id),
  source         request_source not null default 'SUPERVISOR',
  status         request_status not null default 'NEW',
  waiting_on     waiting_reason,
  title          text,
  notes          text,
  needed_by      date,
  created_by     uuid references employees(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  completed_at   timestamptz,
  cancelled_at   timestamptz,
  cancel_reason  text,
  constraint requests_number_uniq unique (number),
  constraint requests_cancel_reason_ck
    check (status <> 'CANCELLED' or cancel_reason is not null),
  constraint requests_completed_at_ck
    check ((status = 'COMPLETED') = (completed_at is not null))
);
create index requests_status_idx      on requests (status);
create index requests_supervisor_idx  on requests (supervisor_id, status);
create index requests_customer_idx    on requests (customer_id, created_at desc);
create index requests_created_idx     on requests (created_at desc);
create index requests_open_idx        on requests (status, needed_by)
  where status not in ('COMPLETED','CANCELLED');   -- the work board
create index requests_waiting_idx     on requests (waiting_on)
  where waiting_on is not null;                    -- the blocked list

-- request items -----------------------------------------------------------
create table request_items (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references requests(id) on delete cascade,
  product_id  uuid references products(id) on delete set null,
  name        text not null,               -- snapshot; free-form when product_id is null
  quantity    numeric(12,2) not null check (quantity > 0),
  unit        text,
  specs       text,                        -- size, colours, material, finishing
  notes       text,
  fulfillment fulfillment_mode not null default 'UNDECIDED',
  status      item_status not null default 'PENDING',
  position    int not null default 0,
  created_by  uuid references employees(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index request_items_request_idx on request_items (request_id, position);
create index request_items_product_idx on request_items (product_id);  -- product demand

-- quotations --------------------------------------------------------------
create table quotations (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references requests(id) on delete cascade,
  version     int not null,
  status      quotation_status not null default 'DRAFT',
  currency    char(3) not null default 'QAR',
  subtotal    numeric(12,2) not null default 0,   -- trigger-maintained from lines
  discount    numeric(12,2) not null default 0 check (discount >= 0),
  total       numeric(12,2) not null default 0,   -- trigger-maintained
  valid_until  date,
  notes        text,
  presented_at timestamptz,   -- when it was told to the customer, by any channel
  decided_at   timestamptz,
  created_by  uuid references employees(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint quotations_version_uniq unique (request_id, version)
);
create index quotations_request_idx on quotations (request_id, version desc);
create index quotations_status_idx  on quotations (status);

create table quotation_lines (
  id              uuid primary key default gen_random_uuid(),
  quotation_id    uuid not null references quotations(id) on delete cascade,
  request_item_id uuid not null references request_items(id) on delete restrict,
  description     text,
  quantity        numeric(12,2) not null check (quantity > 0),
  unit_price      numeric(12,2) not null check (unit_price >= 0),
  line_total      numeric(12,2) generated always as (quantity * unit_price) stored,
  constraint quotation_lines_item_uniq unique (quotation_id, request_item_id)
);
create index quotation_lines_item_idx on quotation_lines (request_item_id);
```

Totals are stored, not computed on read: a quotation is a historical offer and must not change
when a price or quantity changes later. They are maintained by a trigger on `quotation_lines`, so
no client ever computes money.

```sql
-- tasks: an employee OR a partner does a unit of work ---------------------
create table tasks (
  id              uuid primary key default gen_random_uuid(),
  request_id      uuid not null references requests(id) on delete cascade,
  request_item_id uuid references request_items(id) on delete set null,  -- null = whole request
  type            task_type not null,
  title           text not null,
  description     text,
  assignee_id     uuid references employees(id),
  partner_id      uuid references partners(id),
  status          task_status not null default 'TODO',
  due_at          timestamptz,
  started_at      timestamptz,
  completed_at    timestamptz,
  notes           text,
  created_by      uuid references employees(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint tasks_single_executor_ck
    check (not (assignee_id is not null and partner_id is not null))
);
create index tasks_assignee_idx on tasks (assignee_id, status)
  where status in ('TODO','IN_PROGRESS','BLOCKED');   -- "my work" screen
create index tasks_request_idx  on tasks (request_id);
create index tasks_partner_idx  on tasks (partner_id, created_at desc);
create index tasks_due_idx      on tasks (due_at) where status <> 'DONE';

-- what an external task cost us -------------------------------------------
-- A separate table purely so money is invisible to DESIGNER and PRODUCTION.
-- Postgres RLS filters rows, not columns, and in Supabase every signed-in user
-- shares one `authenticated` role, so a restricted column on a widely-readable
-- table cannot be hidden. A one-row-per-task side table can be.
create table task_costs (
  task_id    uuid primary key references tasks(id) on delete cascade,
  amount     numeric(12,2) not null check (amount >= 0),
  currency   char(3) not null default 'QAR',
  notes      text,
  recorded_by uuid references employees(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- payments ----------------------------------------------------------------
create table payments (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references requests(id) on delete restrict,
  amount      numeric(12,2) not null check (amount > 0),
  currency    char(3) not null default 'QAR',
  method      payment_method not null,
  kind        payment_kind not null,
  paid_at     timestamptz not null default now(),
  reference   text,
  notes       text,
  recorded_by uuid references employees(id),
  created_at  timestamptz not null default now()
);
create index payments_request_idx on payments (request_id);
create index payments_paid_at_idx on payments (paid_at desc);

-- activity: append-only ---------------------------------------------------
create table activities (
  id          bigint primary key generated always as identity,
  occurred_at timestamptz not null default now(),
  actor_kind  actor_kind not null default 'EMPLOYEE',
  actor_id    uuid references employees(id),
  entity_type text not null,
  entity_id   uuid not null,
  request_id  uuid references requests(id) on delete cascade,
  event_type  text not null,
  from_value  text,
  to_value    text,
  metadata    jsonb not null default '{}'::jsonb
);
create index activities_request_idx on activities (request_id, occurred_at desc);
create index activities_entity_idx  on activities (entity_type, entity_id, occurred_at desc);
create index activities_event_idx   on activities (event_type, occurred_at desc);
create index activities_actor_idx   on activities (actor_id, occurred_at desc);
```

`payments.request_id` is `on delete restrict` while most children cascade — money is never
silently removed. In practice requests are cancelled, not deleted; there is no delete path in the
UI at all.

### Views (V1 ships these three, and no dashboards)

> **Every view is created `with (security_invoker = on)`.** By default a Postgres view executes
> with the privileges of its *owner*, silently bypassing the RLS of its base tables — a designer
> querying a money-bearing view would read straight through the policy that was supposed to stop
> them. This flag is load-bearing, not a style preference.

```sql
-- money position per request.  Visible to OWNER / SUPERVISOR only, by virtue of
-- security_invoker + the RLS on quotations and payments.
create view v_request_financials with (security_invoker = on) as
select r.id as request_id,
       coalesce(q.approved_total, 0)                            as approved_total,
       coalesce(p.paid_total, 0)                                as paid_total,
       coalesce(q.approved_total, 0) - coalesce(p.paid_total, 0) as balance,
       coalesce(q.approved_count, 0)                            as approved_quotation_count
from requests r
left join lateral (
  select sum(total) as approved_total, count(*) as approved_count
  from quotations where request_id = r.id and status = 'APPROVED'
) q on true
left join lateral (
  select sum(amount) as paid_total from payments where request_id = r.id
) p on true;
```

Summing *all* approved quotations is correct only because of the one-approved-quotation-per-item
invariant (enforced by `trg_quotations_no_overlap`). Without it, two approved quotations covering
the same item would double-count. `approved_quotation_count = 0` means there is nothing to
compare payments against — the UI must show "paid QAR X, no approved quotation" rather than a
negative balance, which is the normal state for a down payment taken before pricing.

```sql
-- the shared request row: no money in it, so every role can read it
create view v_request_summary with (security_invoker = on) as
select r.id, r.number, r.status, r.waiting_on, r.source, r.needed_by,
       r.created_at, r.updated_at, r.completed_at, r.cancelled_at,
       r.customer_id, c.name as customer_name, c.phone as customer_phone,
       r.supervisor_id, e.full_name as supervisor_name,
       (select count(*) from request_items i where i.request_id = r.id) as item_count,
       (select count(*) from tasks t
         where t.request_id = r.id and t.status <> 'DONE')              as open_task_count
from requests r
join customers c on c.id = r.customer_id
left join employees e on e.id = r.supervisor_id;

-- the analytics seed: time spent in each stage
create view v_request_stage_durations with (security_invoker = on) as
select request_id,
       to_value as stage,
       occurred_at as entered_at,
       lead(occurred_at) over (partition by request_id order by occurred_at) as left_at,
       lead(occurred_at) over (partition by request_id order by occurred_at) - occurred_at
         as duration
from activities
where event_type = 'request.status_changed';
```

Screens that need both join `v_request_summary` to `v_request_financials` client-side. Keeping
money in its own view means no screen can leak it by accident — a designer's query simply returns
the summary, and there is no column to forget to strip.

### Triggers / functions (the only server-side logic in V1)

| Function | Purpose |
|---|---|
| `touch_updated_at()` | shared `BEFORE UPDATE` on all mutable tables |
| `log_activity(...)` | `security definer` insert helper used by every trigger |
| `trg_requests_audit()` | logs created / status_changed / waiting_* / supervisor_changed / cancelled / completed / reopened; maintains `completed_at`, `cancelled_at` |
| `trg_request_items_audit()` | logs item added / removed / decision_changed |
| `trg_quotations_audit()` | logs created / presented / approved / rejected / superseded; stamps `presented_at`, `decided_at`; on approval marks its lines' items `APPROVED` |
| `trg_quotations_no_overlap()` | on approval, refuses if any line's item is already on another APPROVED quotation — the invariant the request total depends on |
| `trg_quotation_lines_totals()` | recomputes `subtotal` / `total` on the parent quotation |
| `trg_tasks_audit()` | logs created / assigned / status_changed / completed; stamps `started_at`, `completed_at` |
| `trg_payments_audit()` | logs `payment.recorded`, amount and method in `metadata` |
| `trg_requests_restrict_columns()` | DESIGNER / PRODUCTION may change only `status` and `waiting_on`; anything else raises |
| `trg_tasks_restrict_columns()` | a non-supervisor may change only `status`, `notes`, `started_at`, `completed_at`, and only on their own task |
| `trg_employees_restrict_role()` | only an OWNER may change `employees.role` or `is_active` |
| `current_employee()` / `current_role_name()` | `security definer` + `stable` helpers over `auth.uid()`; used by every policy |
| `create_public_request(...)` | `security definer` RPC, the website's only write path |

Everything else — sequencing, validation of user intent, what to show — stays in Flutter.

---

## E. Supabase Architecture

### Auth

- Email + password. **Public signup disabled.** The owner creates staff accounts from the
  Supabase dashboard in V1 (six people; a user-management screen is not worth building yet).
- `employees.id` **is** `auth.users.id`. One join fewer everywhere, and RLS reduces to
  `auth.uid()` comparisons.
- A trigger on `auth.users` insert creates a matching `employees` row (defaulting to
  `role = 'SUPERVISOR'`, `is_active = false`) so a user can never exist without a profile; the
  owner activates and sets the role.
- Desktop stores the session in the OS credential store (`flutter_secure_storage`); long refresh
  windows so staff are not re-authenticating daily.

### Row Level Security

Enabled on every table. The shape reflects a six-person company where operational visibility is
the *point* — so operational reads are wide, money reads are closed, and writes are narrow.

**Money is visible to OWNER and SUPERVISOR only.** That is a hard boundary, and it is drawn at
the table level rather than the column level for a reason given below.

```
READ
  every active employee   employees, customers, products, partners,
                          requests, request_items, tasks, activities*
  OWNER + SUPERVISOR only quotations, quotation_lines, payments, task_costs
                          (and therefore v_request_financials)

  * activities is filtered, not open — see "the timeline leaks money" below.

WRITE
  customers        OWNER, SUPERVISOR, DESIGNER: insert.  OWNER, SUPERVISOR: update.
  products         OWNER: all.  SUPERVISOR: insert.
  partners         OWNER, SUPERVISOR, PRODUCTION: insert/update.
  requests         OWNER, SUPERVISOR: insert + unrestricted update.
                   DESIGNER: insert (a request they took themselves, source = 'DESIGNER').
                   DESIGNER, PRODUCTION: update limited to `status` + `waiting_on`,
                     so production can move a job to DELIVERY without touching the rest.
  request_items    OWNER, SUPERVISOR: all.  DESIGNER: insert.
  quotations       OWNER, SUPERVISOR: all.  Lines editable only while the parent is DRAFT.
  quotation_lines  OWNER, SUPERVISOR: all.
  payments         OWNER, SUPERVISOR: insert.  update/delete: nobody.
  task_costs       OWNER, SUPERVISOR: insert/update.
  tasks            OWNER, SUPERVISOR: insert, update, assign.
                   DESIGNER, PRODUCTION: insert a task for themselves on any request;
                     update their own row, limited to status/notes/timestamps.
  employees        all: select.  OWNER: update.  `role` and `is_active`: OWNER only.
  activities       insert: security-definer triggers only.
                   update/delete: no policy, no grant — ever.
```

**Designers can create requests.** The brief lists `DESIGNER` as a request source, so the
permission model has to match: a designer who takes a walk-in creates the request and its items.
They just never see a price.

**Tasks are self-serviceable.** Work is often handed over verbally, so requiring a supervisor to
pre-create every task would mean tasks silently stop being created. A designer or production
person can open a request and add their own task. Same schema, one extra policy.

#### Three ways money leaks, and how each is closed

1. **A restricted column on a widely-read table cannot be hidden.** RLS filters *rows*. Column
   privileges do exist, but in Supabase every signed-in user shares the single `authenticated`
   Postgres role, so a `GRANT SELECT (cols)` cannot tell an OWNER from a DESIGNER. Hence
   `task.external_cost` became the `task_costs` table: a row-level boundary, which RLS can
   actually enforce.

2. **Views bypass base-table RLS.** Covered in §D: every view carries
   `with (security_invoker = on)`, and money lives in its own view rather than the shared one.

3. **The activity timeline carries amounts.** `payment.recorded` puts the amount in `metadata`;
   quotation events carry totals. An open `activities` read policy would hand designers the money
   through the back door. The policy filters by entity:

   ```sql
   create policy activities_read on activities for select to authenticated
   using (
     current_role_name() in ('OWNER','SUPERVISOR')
     or entity_type not in ('quotation','payment','task_cost')
   );
   ```

   Designers and production get a complete operational timeline with the money events absent —
   not redacted rows, simply not present. Corollary rule for trigger authors: **never put an
   amount into a `request.*` event**, because those are readable by everyone.

#### Implementation notes

- The same rule applies to write paths: column-level write restrictions are enforced by the
  `trg_*_restrict_columns()` guards in §D, **not** by `GRANT UPDATE (col, ...)`, which cannot
  discriminate between app roles under a shared database role.
- Role checks go through `current_role_name()`, marked `security definer` + `stable`, to avoid
  RLS recursion when a policy on `employees` has to read `employees`.
- `is_active = false` fails every policy — that is the off-switch when someone leaves.
- Policies live in one migration file so the whole rule set reads in a single screen.
- Worth a test: the V1 test suite should include one case per role that asserts a designer's
  session gets zero rows from `quotations`, `payments`, `task_costs`, `v_request_financials`, and
  from money-bearing `activities`. Five assertions, and they will outlive every UI decision here.

### The website's write path

The React site does **not** get table-level insert rights. It calls one RPC:

```
create_public_request(customer_name, phone, email, company, message, items jsonb)
  → security definer, executable by role `anon`
  → finds-or-creates a customer, inserts a request with source = 'WEBSITE',
    supervisor_id = null, inserts items, logs activity with actor_kind = 'CUSTOMER'
  → returns the request number only
```

One narrow, auditable surface instead of anon-writable tables. Abuse protection (a honeypot field
plus a per-IP rate limit in an edge function, or Turnstile) is a small follow-up — noted, not built
on day one, and the RPC boundary is what makes adding it a one-file change.

### Storage

Not used in V1. The boundary is pre-agreed so it does not become a refactor: a private bucket
`request-files`, paths `requests/{request_id}/{uuid}-{filename}`, and a future `request_files`
table holding the metadata with RLS mirroring `requests`. Design assets stay on designers' PCs
until someone asks for this.

### Realtime

Enabled on exactly three tables: `requests`, `tasks`, `activities`.

- desktop work board and request detail subscribe to their filtered slice
- owner mobile subscribes to `requests` for the live overview
- everything else (customers, products, partners, quotations) is fetched on demand

Realtime on quotations and payments adds load without changing anyone's behaviour — the person
writing them is looking at the screen already.

### Where logic lives

| In PostgreSQL | In Flutter |
|---|---|
| activity logging (all state-change events) | screen flow, wizards, what the user sees next |
| quotation totals and line math | input validation and formatting |
| lifecycle timestamps (`completed_at`, `started_at`, `presented_at`) | which actions are *offered* (role-aware UI) |
| item approval cascade + the no-overlap invariant | search, filtering, sorting of loaded lists |
| request numbering | optimistic UI and error recovery |
| authorization, including the money boundary (RLS is the real line) | drafts held in memory before submit |
| the public request RPC | date/currency rendering in Asia/Qatar, QAR |
| — | Excel report generation (§F) |

Rule of thumb: **anything that must be true regardless of which client wrote it lives in Postgres.**
Role-aware UI in Flutter is a convenience; RLS is the enforcement.

### Environments and migrations

- Supabase CLI, plain `.sql` files in `supabase/migrations/`, numbered and forward-only.
- `supabase/seed.sql`: the six employees, the starting product catalog, a few partners.
- Two projects: `inmore-dev` and `inmore-prod`. Local `supabase start` for day-to-day work.
- No ORM, no schema-generation tool. The SQL file is the source of truth.

---

## F. Flutter Architecture

### Repository layout

```
inmore-ops/
  docs/
    blueprint.md                  <- this file
  supabase/
    migrations/                   001_schema.sql, 002_rls.sql, 003_triggers.sql, ...
    seed.sql
    config.toml
  packages/
    inmore_core/                  shared: models, enums, repositories, providers
      lib/
        src/
          models/                 freezed data classes, one per table
          enums/                  Dart enums whose wire names match the PG enums
          data/                   one repository per aggregate
          providers/              Riverpod providers (client, repos, common queries)
          export/                 Excel report builders (see below)
          util/                   formatting (QAR, Asia/Qatar dates), Result/failure
        inmore_core.dart
  apps/
    ops_desktop/                  Flutter Desktop (Windows) — the main V1 app
      lib/
        features/
          auth/  customers/  requests/  quotations/  tasks/  payments/  partners/
            (each: screens/, widgets/, controllers/)
        shell/                    nav rail, command palette, keyboard shortcuts
        app.dart  main.dart  router.dart
    owner_mobile/                 Flutter Mobile — observability only
      lib/
        features/ overview/  requests/  people/  money/
        app.dart  main.dart  router.dart
```

Three Flutter targets, one shared package. Path dependencies, no Melos — with one developer the
melos config costs more than the `flutter pub get` it saves. Add it if a fourth target appears.

### Choices

| Concern | Choice | Why |
|---|---|---|
| State | **Riverpod** | async-first, testable, no BuildContext gymnastics; fits a data-fetching app |
| Routing | **go_router** | deep links for owner mobile, typed enough, minimal |
| Models | **freezed + json_serializable** | ~15 entities of hand-written `fromJson` is where the bugs live; one `build_runner` is a fair price |
| Backend client | **supabase_flutter** directly inside repositories | no wrapper layer; the SDK *is* the data layer |
| Tables/grids | **DataTable2** on desktop | good enough for the volumes involved |
| Excel export | **`excel` package**, generated client-side | see below |
| Local DB | **none** | see below |
| DI | Riverpod providers | no `get_it` on top |

### What is explicitly NOT in the architecture

- **No abstract repository interfaces.** One implementation exists. An interface with one
  implementor is indirection, not abstraction. Repositories are concrete classes; tests use a real
  local Supabase instance, which catches more than a mock would.
- **No use-case / interactor layer.** Controllers call repositories.
- **No offline sync, no SQLite, no local cache.** Everyone is in one office on one network. An
  offline sync engine is the single most expensive thing that could be added here, and nothing in
  the brief requires it. If a supervisor later needs to write requests from a customer's site,
  revisit — and then scope it to *that one flow*, not the whole app. *(Still true for
  writes. The owner's read-only phone now keeps an encrypted read cache — decision 16a.)*
- **No custom design system.** Material 3, one seeded colour scheme, a handful of shared widgets
  (`StatusChip`, `MoneyText`, `RequestCard`, `ActivityTile`) in `inmore_core`. *(Superseded by
  decision 22: a small shared theme and widget set in `packages/inmore_ui`.)*
- **No code generation beyond freezed/json_serializable.**

### Excel reports (promoted into V1)

Because the quotation is verbal and leaves no document, **the supervisor's internal report is the
artifact that actually carries the numbers**. If the system cannot produce it, supervisors go on
building it by hand and the database becomes a second-hand copy of a spreadsheet — which is
exactly the failure mode V1 exists to prevent. So export is not a nicety here; it is the thing
that makes the system the primary record.

Today's report is three columns: **customer name, item, price**. That is one row *per item*, not
per request — and that detail decides the whole export design. Supervisors already think in a
flat item list, and a flat item list is also what Excel can pivot: product demand, revenue by
customer, items per supervisor all fall out of it with no extra work. A row-per-request sheet
with an "items summary" text column would look tidier and be useless for every one of those.

So V1 exports **one workbook, two sheets**, gated to OWNER / SUPERVISOR:

**Sheet 1 — `Items`** (one row per `request_item`; the current sheet, widened)

| Request # | Date | Customer | Company | Phone | Item | Qty | Unit | Spec | Unit Price | Line Total | Item Status | Request Status | Waiting On | Supervisor | Needed By | Completed |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|

The original three columns are still the first ones you read. Everything added is a column the
database already fills reliably as a by-product of normal use — nothing here asks a supervisor
to type something extra.

**Sheet 2 — `Requests`** (one row per request; where the money totals live)

| Request # | Date | Customer | Supervisor | Status | Waiting On | Items | Approved Total | Paid | Balance | Needed By | Completed |
|---|---|---|---|---|---|---|---|---|---|---|---|

Request-level money is deliberately **not** repeated onto the item rows. Repeating a request
total across three item rows means anyone who selects the column and reads the sum gets triple
the real figure — a quiet, confident wrong number, which is worse than no number. Line totals
sum correctly on sheet 1; request totals sum correctly on sheet 2.

**Request report** — a third output, the single-job sheet: one request laid out with its items,
totals, payments, and the dated activity trail. This is what gets printed or sent when someone
asks "what happened with this job".

Choices:

- **`.xlsx`, not `.csv`.** CSV mangles Arabic without a BOM, silently eats the leading zero off
  Qatari phone numbers, and loses number formatting. `.xlsx` opens clean in the tool the reader
  already uses.
- **Real types, not strings.** Dates written as Excel dates (so they sort and filter), money as
  numbers with a 2-decimal QAR format (so they sum), phone as text (so `0` survives). Header row
  frozen, autofilter on. This is most of what makes an export feel like a report rather than a
  dump.
- **Generated client-side**, in `inmore_core/export/`, from the same models the screens use — no
  server-side reporting service, no second source of truth for the numbers.
- **Filters match the screen**: date range, supervisor, status, customer. Whatever list the
  supervisor is looking at is what exports.

**Where "more enhanced" stops.** Every column above is populated automatically. The moment a
column needs someone to type something they do not type today, it belongs in a later version —
an empty column teaches people to distrust the sheet, and a distrusted sheet gets replaced by a
private one, which is the exact failure this export exists to prevent. No charts, no pivot tables,
no formatting beyond the above. PDF generation stays deferred.

### Desktop application behaviour

It must feel like an installed tool, not a website:

- window state persisted, native title bar, no browser-style navigation
- keyboard-first: `Ctrl+K` command palette, `Ctrl+N` new request, `/` to focus search,
  `Esc` to close panels, `Enter` to save
- a persistent left nav (Work board · Requests · Customers · Products · Partners) and a fast
  global search across customers, requests, phone numbers
- the default screen is the **work board**: open requests grouped by status, with the blocked ones
  surfaced at the top. A supervisor should see what needs attention without clicking.
- role-shaped landing: supervisors land on the board, designers and production land on **My Work**
  (their open tasks).

### Owner mobile behaviour

Read-only in V1 (no write path at all — this keeps it a two-week app):

1. **Overview** — active requests by stage, what came in this week, what completed, blocked count
2. **Attention** — blocked requests, past `needed_by`, requests with no supervisor, stale tasks
3. **Request detail** — items, supervisor, tasks, money position, and the activity timeline
4. **Money** — outstanding balance total, payments this week/month
5. **People** — open task counts per employee

No charts in V1. Counts and lists. Charts arrive when the data behind them has been trusted for a
quarter.

---

## G. The V1 Vertical Slice

### The slice

**One supervisor can take a real customer call and record the entire thing, end to end, and
anyone else can see what happened.**

```
sign in  →  find or create customer  →  create request  →  add 1..n items
         →  assign supervisor  →  create tasks with executors  →  create a quotation
         →  mark it sent, then approved  →  move the request through statuses
         →  record a payment  →  read the activity timeline
```

Definition of done: an Inmore supervisor uses it for one real customer, unaided, and the resulting
activity log correctly answers "what happened to request #1042 and when".

### Build order

| # | Step | Contents | Ends when |
|---|---|---|---|
| 0 | **Foundation** | repo, two Supabase projects, `001_schema` + `002_rls` + `003_triggers`, seed, `inmore_core` skeleton, desktop shell with login | a real employee signs in and sees an empty board |
| 1 | **Customers** | list, trigram search, create, edit, duplicate-phone warning | a supervisor finds a customer in under 3 seconds |
| 2 | **Requests + items** | create request with N items (catalog picker *and* free-form), request list, request detail | request #1001 exists with three items |
| 3 | **Assignment + tasks** | supervisor on the request, create/assign tasks, `My Work` screen, task status updates | a designer sees their work and marks it in progress |
| 4 | **Quotations** | create from items with prices, trigger-maintained totals, send/approve/reject, revision as a new version | a request shows an approved total in QAR |
| 5 | **Status + timeline** | status and `waiting_on` controls, activity timeline on request detail, work board grouping | the timeline reads as a truthful story |
| 6 | **Payments** | record payment, balance on request and list | "this customer has paid QAR X of Y" is on screen |
| 7 | **Excel reports** | request report + period report, gated to OWNER/SUPERVISOR | a supervisor exports the month and stops maintaining their own sheet |

Steps 0–7 are the slice. Step 7 is not optional trim: without it the supervisor's real reporting
artifact still lives outside the system, and the data inside it goes stale within weeks.

Then, in order of value: partners as task executors → owner mobile → website RPC.

The money boundary (OWNER + SUPERVISOR) is built in from step 0, not retrofitted — it is three
RLS policies and one activity filter on day one, versus an audit of every screen later.

Each step is one migration (if needed) plus one feature folder, and is usable on its own.

---

## Decision Register

### DECIDED

1. `request` is the central entity; no separate order entity.
2. Stage (`status`) and blocking (`waiting_on`) are two orthogonal columns — not one flat enum.
3. Transitions are unconstrained in V1; every one is logged.
4. Responsibility (`request.supervisor_id`) is separate from execution (`task.assignee_id`).
5. A partner is a task executor; there is no separate partner-job table in V1.
6. Quotations are header + lines, versioned, scoped to the request, never edited after being
   presented. `PRESENTED` means told to the customer by any channel; quotations are verbal at
   Inmore and the system records the fact, not a document.
7. Quotation totals are trigger-computed and stored; no client computes money. An item may be
   covered by at most one APPROVED quotation at a time — trigger-enforced, and the reason the
   request total is a plain sum.
8. `request_item.product_id` is nullable and `name` is always a snapshot; the catalog is a
   vocabulary, not a constraint.
9. Activity is append-only, written by database triggers, and carries a denormalized `request_id`.
10. `activity.event_type` is text with an `entity.verb` convention; other closed sets are PG enums.
11. Supabase only — no NestJS, no custom API layer, no edge functions in V1 beyond the public
    request RPC.
12. RLS: all active employees read all *operational* data; writes are role-scoped; activity is
    never mutable.
12a. **Money is readable by OWNER and SUPERVISOR only.** Enforced at the table level —
    `quotations`, `quotation_lines`, `payments`, `task_costs` — because column-level privileges
    cannot discriminate between app roles under Supabase's shared `authenticated` database role.
    `task.external_cost` therefore becomes the `task_costs` table, every view is
    `security_invoker = on`, and the `activities` read policy filters money-bearing entity types.
12b. Designers may create requests and items (the brief lists them as a request source), and any
    employee may create a task for themselves on a request. Neither can see a price.
13. The website writes through one `security definer` RPC, never through tables.
14. Flutter Desktop (Windows) + Flutter Mobile + one shared `inmore_core` package; path deps, no
    Melos.
15. Riverpod, go_router, `supabase_flutter` in concrete repositories. No abstract interfaces, no
    use-case layer, no `get_it`.
15a. **Reversed: no code generation.** This decision originally said freezed + json_serializable.
    In practice `build_runner` hangs on the development machine — twice, reproducibly, at the
    same point, idle at 0% CPU with no output. Models are hand-written plain immutable classes
    with a `fromJson`. More lines, but obvious ones, checked by `flutter analyze` immediately,
    and nothing to regenerate on a new machine. What we gave up is `copyWith` and value
    equality; nothing currently needs either. The cost landed elsewhere and was caught: see
    decision 21.
16. No offline support, no SQLite, no local cache.
16a. **Revised: a read cache on the owner's phone, live updates everywhere.** Two changes, one
    principle kept. (1) Both apps now subscribe to realtime on `requests`, `tasks` and
    `activities` (`realtimeSyncProvider`) and invalidate exactly the providers a change touches —
    the subscription §E always described but no client had wired up. (2) The owner's phone keeps
    its last overview, money and people snapshots on disk, encrypted (flutter_secure_storage),
    keyed by user, wiped on sign-out, shown instantly on launch and replaced when the network
    answers. That is cheap only because the owner's app never writes: there is nothing to sync
    back and no conflict to resolve. The desktop stays online-only for writes; an offline write
    queue would let the activity log disagree with what happened, and the log is the point.
    Every data provider also now watches `currentUserIdProvider`, so a different person signing
    in on the same PC never sees the previous person's cached rows — money included.
17. Files/storage are out of V1; the bucket and path convention are agreed so adding them is
    additive.
17a. **Excel export is in V1** (slice step 7): `.xlsx`, generated client-side, gated to
    OWNER/SUPERVISOR. It replaces the supervisor's hand-built sheet, which is the only place
    Inmore's numbers are currently written down. One workbook with an `Items` sheet (row per
    item, matching today's customer/item/price shape) and a `Requests` sheet (row per request,
    where the totals live — never repeated onto item rows), plus a single-job request report.
    Every exported column is auto-populated; nothing asks for new data entry. PDF stays deferred.
18. Owner mobile is read-only in V1, lists and counts, no charts.
19. Currency is QAR only; money is `numeric(12,2)`; no tax fields.
20. No deletes in the UI — requests are cancelled, customers archived.
21. **Hand-written models require an integration test.** Mapping `snake_case` columns by hand is
    exactly the kind of thing the analyzer cannot check: a wrong column name reads null, and a
    null field looks identical to an empty one on screen. `packages/inmore_core/test/` runs the
    real repositories against the local database. It immediately caught that postgrest-dart's
    `.order()` defaults to **descending**, which had silently reversed the product catalog, the
    staff list, request items and both Excel sheets.
22. **A small shared UI package, `packages/inmore_ui`.** Reverses "no custom design system" (§F)
    in part: not a design system, but one theme, one set of colour tokens and about a dozen
    shared widgets, so the owner's phone and the supervisor's desktop read as one product.
    Neutral ink and paper carry the interface; the logo's CMYK inks are spent only on meaning
    (stages, warnings) and brand moments (the stripe, the loading bar). Font is Rubik, bundled —
    one family for Latin and Arabic. Light, dark and follow-system, chosen per device.
23. **Arabic and English, per person** (replaces proposed default 7). Flutter's own `gen-l10n`
    — not build_runner, see 15a — from `packages/inmore_ui/lib/l10n/*.arb`, output committed.
    Full right-to-left layout. Digits stay Western in both languages; the currency mark is
    `QAR` / `ر.ق`. Enum `label`s stay English because the **Excel export is always English**,
    so a workbook reads the same on every desk; screens use the translated `tr(l10n)`.
    Activity sentences moved from `inmore_core` to `inmore_ui` so they can be translated, and
    are still shared by both apps. Text people type (names, specs) is laid out in its own
    direction, so an Arabic customer name in the English UI is not broken.

### PROPOSED (sensible defaults; say the word and they change)

1. `task_type` values `DESIGN | PREPRESS | PRODUCTION | EXTERNAL | DELIVERY | OTHER` — a guess at
   how Inmore actually splits work; worth 10 minutes with a supervisor before migration 001.
2. `payment_kind` as `DOWN_PAYMENT | PARTIAL | FINAL`, with partial-vs-full *derived* from
   payments summed against the approved total rather than typed by the user.
3. `payment_method` extended beyond CASH/ONLINE with `BANK_TRANSFER` and `CHEQUE`, since both are
   common in Qatar and adding them now is free.
4. Request numbering as a single global sequence starting at 1001 (not per-year) — `#1042` reads
   as a name, and per-year resets create collisions in conversation.
5. Staff accounts created from the Supabase dashboard in V1; a user-management screen is later.
6. Desktop targets Windows only for V1.
7. UI in English only; all data fields are UTF-8 and store Arabic fine (customer names, specs,
   product names). *Superseded by decision 23 — Arabic and English.*
8. `needed_by` as a plain date on the request, with per-item deadlines deferred.

### DEFERRED (explicitly not V1)

File and asset management · WhatsApp integration of any kind · quotation/invoice **PDF**
generation (Excel covers the real need) · delivery notes and invoices · inventory and stock ·
purchase orders and partner costing beyond `task_costs` · analytics dashboards and charts ·
notifications and email · a customer portal · granular permissions · offline mode · per-item
delivery tracking · multi-currency · tax/VAT fields · audit corrections and undo · a
user-management UI · macOS/Linux desktop builds · request templates and recurring orders ·
automated status transitions.

---

## Resolved Since The First Draft

**Who sees money → OWNER and SUPERVISOR only.** Applied throughout: §D (`task_costs`, view
split, `security_invoker`), §E (table-level policies, the activity filter, trigger guards instead
of column grants), and the export gate in §F. This is decision 12a.

**Is the quotation a document → no, it is verbal.** So `SENT` became `PRESENTED`, PDF generation
left the roadmap, and Excel export came into V1 — because the supervisor's internal report is
where Inmore's numbers actually live today, and that is what the system has to take over.

**Task handover (old Q3) → decided, not asked again.** Work is handed over verbally, so any
employee can create a task for themselves on a request; supervisors can also create and assign.
Requiring supervisor pre-creation would just mean tasks stop being recorded.

**Supervisor ownership (old Q4) → decided, not asked again.** One `supervisor_id` column,
reassignment allowed and logged. Overlapping responsibilities, single owner at any moment. If two
supervisors genuinely co-own a request at the same time, that becomes a join table later; the
activity log will show it if it happens.

---

## Open Questions

None blocking. The export question is closed: today's report is customer / item / price, one row
per item, and §F widens exactly that shape rather than replacing it.

Two things I will assume unless corrected, both cheap to change:

- Payments are recorded by supervisors and the owner. If a receptionist or an accountant takes
  cash, they need an account and a role, and `PRODUCTION` is not it.
- A down payment can be recorded before any quotation is approved (the balance simply reads as
  "paid QAR X, no approved quotation"). I have assumed this happens and designed for it.

---

*Nothing here is built. On approval, step 0 of the build order is the first commit.*
