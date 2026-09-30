-- =============================================================================
-- 001 — Schema: extensions, enums, tables, indexes, views
-- Inmore Operations System V1.  See docs/blueprint.md §D.
-- =============================================================================

create extension if not exists pg_trgm;

-- -----------------------------------------------------------------------------
-- Enums  (closed sets only; activity.event_type stays free text)
-- -----------------------------------------------------------------------------
create type employee_role    as enum ('OWNER','SUPERVISOR','DESIGNER','PRODUCTION');
create type request_source   as enum ('SUPERVISOR','DESIGNER','WEBSITE','OTHER');
create type request_status   as enum ('NEW','QUOTATION','DESIGN','CUSTOMER_APPROVAL',
                                      'PRODUCTION','DELIVERY','COMPLETED','CANCELLED');
create type waiting_reason   as enum ('CUSTOMER','PAYMENT','PARTNER','INTERNAL');
create type item_status      as enum ('PENDING','APPROVED','REJECTED','CANCELLED');
create type fulfillment_mode as enum ('UNDECIDED','INTERNAL','EXTERNAL');
create type quotation_status as enum ('DRAFT','PRESENTED','APPROVED','REJECTED','SUPERSEDED');
create type task_type        as enum ('DESIGN','PREPRESS','PRODUCTION','EXTERNAL','DELIVERY','OTHER');
create type task_status      as enum ('TODO','IN_PROGRESS','BLOCKED','DONE','CANCELLED');
create type payment_method   as enum ('CASH','ONLINE','BANK_TRANSFER','CHEQUE');
create type payment_kind     as enum ('DOWN_PAYMENT','PARTIAL','FINAL');
create type actor_kind       as enum ('EMPLOYEE','SYSTEM','CUSTOMER');

-- -----------------------------------------------------------------------------
-- employees — staff and app users; id IS the auth.users id
-- -----------------------------------------------------------------------------
create table employees (
  id         uuid primary key references auth.users(id) on delete restrict,
  full_name  text not null,
  email      text not null unique,
  phone      text,
  role       employee_role not null default 'SUPERVISOR',
  is_active  boolean not null default false,   -- owner activates; see 002
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table employees is
  'Staff. Row is created automatically on auth signup, inactive, for the owner to activate.';

-- -----------------------------------------------------------------------------
-- Role helpers.
-- These live in 001 rather than 002 because the views at the bottom of this file
-- depend on them.  security definer + stable: policies on `employees` have to
-- read `employees`, which would recurse through RLS without it.
-- -----------------------------------------------------------------------------
create or replace function current_employee_id() returns uuid
language sql stable security definer set search_path = public, pg_temp as $$
  select id from employees where id = auth.uid() and is_active;
$$;

create or replace function current_role_name() returns employee_role
language sql stable security definer set search_path = public, pg_temp as $$
  select role from employees where id = auth.uid() and is_active;
$$;

-- The money boundary, in one place.  See docs/blueprint.md §E.
create or replace function can_see_money() returns boolean
language sql stable as $$
  select current_role_name() in ('OWNER','SUPERVISOR');
$$;

create or replace function is_supervisor_or_owner() returns boolean
language sql stable as $$
  select current_role_name() in ('OWNER','SUPERVISOR');
$$;

-- -----------------------------------------------------------------------------
-- customers
-- -----------------------------------------------------------------------------
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
-- phone is indexed but NOT unique: shared and missing numbers are both real.
-- Duplicate detection is a soft warning in the UI.
create index customers_phone_idx        on customers (phone);
create index customers_name_trgm_idx    on customers using gin (name gin_trgm_ops);
create index customers_company_trgm_idx on customers using gin (company gin_trgm_ops);
create index customers_active_idx       on customers (created_at desc) where not is_archived;

-- -----------------------------------------------------------------------------
-- products — a vocabulary, not a constraint
-- -----------------------------------------------------------------------------
create table products (
  id           uuid primary key default gen_random_uuid(),
  name         text not null unique,
  category     text,
  default_unit text,
  is_active    boolean not null default true,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);
create index products_active_idx on products (sort_order, name) where is_active;

-- -----------------------------------------------------------------------------
-- partners — external suppliers / printers
-- -----------------------------------------------------------------------------
create table partners (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  contact_name text,
  phone        text,
  email        text,
  services     text,
  notes        text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index partners_active_idx on partners (name) where is_active;

-- -----------------------------------------------------------------------------
-- requests — the spine.  status = pipeline stage, waiting_on = why it is stuck.
-- -----------------------------------------------------------------------------
create table requests (
  id            uuid primary key default gen_random_uuid(),
  number        int not null generated by default as identity (start with 1001),
  customer_id   uuid not null references customers(id) on delete restrict,
  supervisor_id uuid references employees(id),
  source        request_source not null default 'SUPERVISOR',
  status        request_status not null default 'NEW',
  waiting_on    waiting_reason,
  title         text,
  notes         text,
  needed_by     date,
  created_by    uuid references employees(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  completed_at  timestamptz,
  cancelled_at  timestamptz,
  cancel_reason text,
  constraint requests_number_uniq unique (number),
  constraint requests_cancel_reason_ck
    check (status <> 'CANCELLED' or cancel_reason is not null),
  constraint requests_completed_at_ck
    check ((status = 'COMPLETED') = (completed_at is not null)),
  constraint requests_cancelled_at_ck
    check ((status = 'CANCELLED') = (cancelled_at is not null))
);
create index requests_status_idx     on requests (status);
create index requests_supervisor_idx on requests (supervisor_id, status);
create index requests_customer_idx   on requests (customer_id, created_at desc);
create index requests_created_idx    on requests (created_at desc);
create index requests_open_idx       on requests (status, needed_by)
  where status not in ('COMPLETED','CANCELLED');          -- the work board
create index requests_waiting_idx    on requests (waiting_on)
  where waiting_on is not null;                           -- the blocked list

-- -----------------------------------------------------------------------------
-- request_items — catalog-linked OR free-form; name is always a snapshot
-- -----------------------------------------------------------------------------
create table request_items (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references requests(id) on delete cascade,
  product_id  uuid references products(id) on delete set null,
  name        text not null,
  quantity    numeric(12,2) not null check (quantity > 0),
  unit        text,
  specs       text,
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

-- -----------------------------------------------------------------------------
-- quotations — header + lines, versioned.  PRESENTED = told to the customer by
-- any channel; Inmore's quotations are verbal and leave no document.
-- -----------------------------------------------------------------------------
create table quotations (
  id           uuid primary key default gen_random_uuid(),
  request_id   uuid not null references requests(id) on delete cascade,
  version      int not null,
  status       quotation_status not null default 'DRAFT',
  currency     char(3) not null default 'QAR',
  subtotal     numeric(12,2) not null default 0,   -- trigger-maintained
  discount     numeric(12,2) not null default 0 check (discount >= 0),
  total        numeric(12,2) not null default 0,   -- trigger-maintained
  valid_until  date,
  notes        text,
  presented_at timestamptz,
  decided_at   timestamptz,
  created_by   uuid references employees(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
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
create index quotation_lines_item_idx  on quotation_lines (request_item_id);
create index quotation_lines_quote_idx on quotation_lines (quotation_id);

-- -----------------------------------------------------------------------------
-- tasks — an employee OR a partner does a unit of work
-- -----------------------------------------------------------------------------
create table tasks (
  id              uuid primary key default gen_random_uuid(),
  request_id      uuid not null references requests(id) on delete cascade,
  request_item_id uuid references request_items(id) on delete set null,
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
  where status in ('TODO','IN_PROGRESS','BLOCKED');       -- "My Work"
create index tasks_request_idx  on tasks (request_id);
create index tasks_partner_idx  on tasks (partner_id, created_at desc);
create index tasks_due_idx      on tasks (due_at) where status <> 'DONE';

-- -----------------------------------------------------------------------------
-- task_costs — what an external task cost us.
-- A separate table purely so money is invisible to DESIGNER / PRODUCTION:
-- RLS filters rows, not columns, and in Supabase every signed-in user shares the
-- single `authenticated` role, so a restricted column on a widely-readable table
-- cannot be hidden.  A one-row-per-task side table can be.
-- -----------------------------------------------------------------------------
create table task_costs (
  task_id     uuid primary key references tasks(id) on delete cascade,
  amount      numeric(12,2) not null check (amount >= 0),
  currency    char(3) not null default 'QAR',
  notes       text,
  recorded_by uuid references employees(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- payments — on delete restrict: money is never silently removed
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- activities — append-only.  Written by triggers (002), never by clients.
-- request_id is denormalized so a timeline is one indexed read.
-- -----------------------------------------------------------------------------
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

comment on table activities is
  'Append-only event log. No UPDATE/DELETE grant exists. Amounts may appear only in '
  'quotation.*, payment.* and task_cost.* events - never in request.* or task.*, '
  'which every employee can read.';

-- =============================================================================
-- Views
--
-- Every view is security_invoker so it honours the RLS of its base tables.
-- Without this a view runs with its OWNER's privileges and silently bypasses
-- the money boundary.  This flag is load-bearing, not style.
-- =============================================================================

-- Money position per request.  Readable by OWNER / SUPERVISOR only, by virtue of
-- security_invoker plus the RLS on quotations and payments.
create view v_request_financials with (security_invoker = on) as
select r.id                                                     as request_id,
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
) p on true
-- Explicit, on top of security_invoker.  Without it a DESIGNER would read this
-- view and get every request with zeroed money columns (the lateral subqueries
-- return nothing under RLS) - no leak, but a confident wrong number. Zero rows
-- is the honest answer.
where can_see_money();

comment on view v_request_financials is
  'Summing all APPROVED quotations is correct only because of the one-approved-'
  'quotation-per-item invariant (trg_quotations_no_overlap). approved_quotation_count = 0 '
  'means there is nothing to compare payments against - show "paid X, no approved '
  'quotation", not a negative balance.';

-- The shared request row: no money in it, so every role can read it.
create view v_request_summary with (security_invoker = on) as
select r.id, r.number, r.status, r.waiting_on, r.source, r.title, r.needed_by,
       r.created_at, r.updated_at, r.completed_at, r.cancelled_at,
       r.customer_id, c.name as customer_name, c.phone as customer_phone,
       c.company as customer_company,
       r.supervisor_id, e.full_name as supervisor_name,
       (select count(*) from request_items i where i.request_id = r.id)  as item_count,
       (select count(*) from tasks t
         where t.request_id = r.id and t.status <> 'DONE')               as open_task_count
from requests r
join customers c on c.id = r.customer_id
left join employees e on e.id = r.supervisor_id;

-- The analytics seed: time spent in each stage.  No dashboards in V1 - this view
-- exists so the data is queryable the day someone wants one.
create view v_request_stage_durations with (security_invoker = on) as
select request_id,
       to_value    as stage,
       occurred_at as entered_at,
       lead(occurred_at) over w as left_at,
       lead(occurred_at) over w - occurred_at as duration
from activities
where event_type = 'request.status_changed'
window w as (partition by request_id order by occurred_at);
