-- =============================================================================
-- Back office: staff management, business details, inventory, expenses, and a
-- payments read model for reports.
--
-- 1. Supervisors manage staff (not the owner's account).
-- 2. business_profile: the letterhead on printed reports.
-- 3. Inventory: items, a managers-only unit cost, and an insert-only ledger of
--    stock movements that the quantity is computed from.
-- 4. Expenses: the shop's own spending — money, so owner and supervisors only;
--    corrected by editing or voiding, never deleted, and every step logged.
-- 5. v_report_payments: money received, one row per payment.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Staff management
--
-- Until now only the owner could change a role or (de)activate an account.
-- Supervisors now can too, for everyone except the owner — they can't touch
-- an owner's account or make anyone an owner. Nobody changes their own role or
-- switches themselves off: that's how a shop ends up with no one able to sign
-- in. Email is the sign-in name, so it only changes through Auth.
--
-- Creating, deleting and resetting passwords need the Auth admin API, which no
-- client may hold; the staff-admin Edge Function does those, and checks the
-- same rules. Role and activation go through this table with the caller's own
-- identity, so the history records who did it.
-- -----------------------------------------------------------------------------
create or replace function employees_restrict_role() returns trigger
language plpgsql as $$
declare
  v_role employee_role := current_role_name();
begin
  if auth.uid() is null then
    return new;   -- SQL Editor / service role: the admin path
  end if;

  if new.email is distinct from old.email then
    raise exception 'An email address is the sign-in name and can''t be changed here.'
      using errcode = 'insufficient_privilege';
  end if;

  if (new.role, new.is_active) is distinct from (old.role, old.is_active) then
    if v_role is distinct from 'OWNER' and v_role is distinct from 'SUPERVISOR' then
      raise exception 'Only the owner or a supervisor may change a role or access.'
        using errcode = 'insufficient_privilege';
    end if;
    if new.id = auth.uid() then
      raise exception 'You can''t change your own role or access.'
        using errcode = 'insufficient_privilege';
    end if;
    if v_role = 'SUPERVISOR' and (old.role = 'OWNER' or new.role = 'OWNER') then
      raise exception 'Only the owner can manage owner accounts.'
        using errcode = 'insufficient_privilege';
    end if;
  end if;
  return new;
end;
$$;

drop policy employees_update on employees;
create policy employees_update on employees for update to authenticated
  using (id = auth.uid()
         or current_role_name() = 'OWNER'
         or (current_role_name() = 'SUPERVISOR' and role <> 'OWNER'))
  with check (id = auth.uid()
              or current_role_name() = 'OWNER'
              or (current_role_name() = 'SUPERVISOR' and role <> 'OWNER'));

-- Who gave whom access, and when. request_id is null: these are not part of
-- any request's timeline. Not money, so every active employee may read them.
create or replace function employees_audit() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    perform log_activity('employee', new.id, null, 'employee.created',
                         null, new.role::text,
                         jsonb_build_object('name', new.full_name, 'email', new.email));
    return new;
  end if;
  if new.role is distinct from old.role then
    perform log_activity('employee', new.id, null, 'employee.role_changed',
                         old.role::text, new.role::text,
                         jsonb_build_object('name', new.full_name));
  end if;
  if new.is_active is distinct from old.is_active then
    perform log_activity('employee', new.id, null,
                         case when new.is_active then 'employee.activated'
                              else 'employee.deactivated' end,
                         null, null, jsonb_build_object('name', new.full_name));
  end if;
  return new;
end;
$$;

create trigger trg_employees_audit
  after insert or update on employees
  for each row execute function employees_audit();

-- A deleted, never-used account leaves its activity rows behind: entity_id is
-- not a foreign key, and that is the point — the record that it existed stays.

-- -----------------------------------------------------------------------------
-- 2. business_profile — one row, the letterhead on printed reports
-- -----------------------------------------------------------------------------
create table business_profile (
  id         boolean primary key default true check (id),
  name       text not null default 'Inmore',
  tagline    text default 'Branding · Advertising · Packaging',
  phone      text,
  email      text,
  address    text,
  cr_number  text,
  website    text,
  updated_at timestamptz not null default now()
);
insert into business_profile (id) values (true);

create trigger trg_business_profile_touch
  before update on business_profile
  for each row execute function touch_updated_at();

alter table business_profile enable row level security;
revoke all on business_profile from anon, authenticated;
grant select, update on business_profile to authenticated;

create policy business_profile_select on business_profile for select to authenticated
  using (current_employee_id() is not null);
create policy business_profile_update on business_profile for update to authenticated
  using (is_supervisor_or_owner()) with check (is_supervisor_or_owner());

-- -----------------------------------------------------------------------------
-- 3. Inventory
--
-- Not linked to requests yet: stock is recorded by hand as it comes in, goes
-- out, or is counted.
--
-- The quantity on hand is never stored — it is the sum of the movements, so
-- it cannot drift from its own history. A movement is never edited; a mistake
-- is corrected by recording the opposite, like a payment.
--
-- Unit cost is money, so it lives in a side table only money roles can read
-- (RLS filters rows, not columns — the task_costs pattern).
-- -----------------------------------------------------------------------------
create type stock_movement_kind as enum ('IN','OUT','ADJUST');

create table inventory_items (
  id            uuid primary key default gen_random_uuid(),
  name          text not null check (length(trim(name)) > 0),
  code          text,
  category      text,
  unit          text not null default 'pcs',
  reorder_level numeric(12,2) not null default 0 check (reorder_level >= 0),
  location      text,
  notes         text,
  is_active     boolean not null default true,
  created_by    uuid references employees(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create unique index inventory_items_code_key
  on inventory_items (lower(code)) where code is not null;

create trigger trg_inventory_items_touch
  before update on inventory_items
  for each row execute function touch_updated_at();

create table inventory_item_costs (
  item_id    uuid primary key references inventory_items(id) on delete cascade,
  unit_cost  numeric(12,2) not null check (unit_cost >= 0),
  updated_by uuid references employees(id),
  updated_at timestamptz not null default now()
);

create table stock_movements (
  id          bigint primary key generated always as identity,
  item_id     uuid not null references inventory_items(id) on delete restrict,
  kind        stock_movement_kind not null,
  quantity    numeric(12,2) not null check (quantity <> 0),   -- signed change
  note        text,
  moved_at    timestamptz not null default now(),
  recorded_by uuid references employees(id),
  created_at  timestamptz not null default now(),
  constraint stock_movements_sign check (
    (kind = 'IN'  and quantity > 0) or
    (kind = 'OUT' and quantity < 0) or
     kind = 'ADJUST')
);
create index stock_movements_item_idx on stock_movements (item_id, moved_at desc);

-- Stamps who recorded it, and refuses to take stock below zero. The item row
-- is locked first, so two people taking the last box at once can't both win.
create or replace function stock_movements_check() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_on_hand numeric;
begin
  new.recorded_by := coalesce(current_employee_id(), new.recorded_by);
  perform 1 from inventory_items where id = new.item_id for update;
  select coalesce(sum(quantity), 0) into v_on_hand
    from stock_movements where item_id = new.item_id;
  if v_on_hand + new.quantity < 0 then
    raise exception 'Only % in stock. If the count is wrong, record a stock count first.',
      trim(to_char(v_on_hand, 'FM999999990.##'))
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger trg_stock_movements_check
  before insert on stock_movements
  for each row execute function stock_movements_check();

create or replace function inventory_item_costs_stamp() returns trigger
language plpgsql as $$
begin
  new.updated_by := current_employee_id();
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_inventory_item_costs_stamp
  before insert or update on inventory_item_costs
  for each row execute function inventory_item_costs_stamp();

create or replace function inventory_items_stamp() returns trigger
language plpgsql as $$
begin
  new.created_by := coalesce(current_employee_id(), new.created_by);
  return new;
end;
$$;

create trigger trg_inventory_items_stamp
  before insert on inventory_items
  for each row execute function inventory_items_stamp();

create view v_inventory with (security_invoker = on) as
select i.id, i.name, i.code, i.category, i.unit, i.reorder_level, i.location,
       i.notes, i.is_active, i.created_at, i.updated_at,
       coalesce(m.on_hand, 0)                                    as on_hand,
       m.last_moved_at,
       (i.reorder_level > 0 and coalesce(m.on_hand, 0) <= i.reorder_level) as is_low
from inventory_items i
left join (
  select item_id, sum(quantity) as on_hand, max(moved_at) as last_moved_at
    from stock_movements group by item_id
) m on m.item_id = i.id;

comment on view v_inventory is
  'Stock on hand, computed from stock_movements. No money: unit cost is in '
  'inventory_item_costs, readable by owner and supervisors only.';

create view v_stock_movements with (security_invoker = on) as
select m.id, m.item_id, i.name as item_name, i.unit, m.kind, m.quantity, m.note,
       m.moved_at, m.recorded_by, e.full_name as recorded_by_name
from stock_movements m
join inventory_items i on i.id = m.item_id
left join employees e on e.id = m.recorded_by;

alter table inventory_items      enable row level security;
alter table inventory_item_costs enable row level security;
alter table stock_movements      enable row level security;

-- Supabase grants new tables to anon and authenticated by default (003 only
-- revoked what existed then): take it all back and grant exactly what is used.
revoke all on inventory_items, inventory_item_costs, stock_movements,
              v_inventory, v_stock_movements from anon, authenticated;
grant select, insert, update on inventory_items      to authenticated;
grant select, insert, update on inventory_item_costs to authenticated;
grant select, insert         on stock_movements      to authenticated;
grant select on v_inventory, v_stock_movements to authenticated;

create policy inventory_items_select on inventory_items for select to authenticated
  using (current_employee_id() is not null);
create policy inventory_items_insert on inventory_items for insert to authenticated
  with check (is_supervisor_or_owner());
create policy inventory_items_update on inventory_items for update to authenticated
  using (is_supervisor_or_owner()) with check (is_supervisor_or_owner());

create policy inventory_item_costs_all on inventory_item_costs for all to authenticated
  using (can_see_money()) with check (can_see_money());

-- Production records what comes in and goes out; a stock count (which can
-- move the figure either way, with no delivery or job behind it) is for
-- managers. Designers look.
create policy stock_movements_select on stock_movements for select to authenticated
  using (current_employee_id() is not null);
create policy stock_movements_insert on stock_movements for insert to authenticated
  with check (
    current_role_name() in ('OWNER','SUPERVISOR','PRODUCTION')
    and (kind <> 'ADJUST' or is_supervisor_or_owner()));

-- -----------------------------------------------------------------------------
-- 4. Expenses
--
-- What the shop spends: day-to-day (materials, fuel, a courier) and monthly
-- fixed costs (rent, salaries, utilities) — is_monthly marks the second kind,
-- so next month's can be copied forward and the two can be told apart.
--
-- Unlike a payment, an expense is the shop's own book and gets corrected:
-- edit it, or void it with a reason. Never deleted, and every step goes into
-- the activity log as an 'expense' event — which, carrying amounts, is added
-- to the money filter on activities below.
-- -----------------------------------------------------------------------------
create table expenses (
  id          uuid primary key default gen_random_uuid(),
  spent_on    date not null default current_date,
  category    text not null check (length(trim(category)) > 0),
  description text,
  paid_to     text,
  amount      numeric(12,2) not null check (amount > 0),
  currency    char(3) not null default 'QAR',
  method      payment_method not null default 'CASH',
  is_monthly  boolean not null default false,
  reference   text,
  recorded_by uuid references employees(id),
  created_at  timestamptz not null default now(),
  updated_by  uuid references employees(id),
  updated_at  timestamptz not null default now(),
  voided_at   timestamptz,
  voided_by   uuid references employees(id),
  void_reason text,
  constraint expenses_void_reason check (
    voided_at is null or length(trim(coalesce(void_reason, ''))) > 0)
);
create index expenses_spent_on_idx on expenses (spent_on desc);

create or replace function expenses_guard() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    new.recorded_by := coalesce(current_employee_id(), new.recorded_by);
    new.voided_at := null; new.voided_by := null; new.void_reason := null;
    return new;
  end if;
  if old.voided_at is not null then
    raise exception 'A voided expense can''t be changed.'
      using errcode = 'check_violation';
  end if;
  if new.voided_at is not null then
    new.voided_by := current_employee_id();
  end if;
  new.recorded_by := old.recorded_by;
  new.created_at  := old.created_at;
  new.updated_by  := current_employee_id();
  new.updated_at  := now();
  return new;
end;
$$;

create trigger trg_expenses_guard
  before insert or update on expenses
  for each row execute function expenses_guard();

create or replace function expenses_audit() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    perform log_activity('expense', new.id, null, 'expense.recorded', null,
                         new.amount::text,
                         jsonb_build_object('category', new.category,
                                            'spent_on', new.spent_on));
  elsif new.voided_at is not null and old.voided_at is null then
    perform log_activity('expense', new.id, null, 'expense.voided',
                         old.amount::text, null,
                         jsonb_build_object('category', new.category,
                                            'reason', new.void_reason));
  else
    perform log_activity('expense', new.id, null, 'expense.updated',
                         old.amount::text, new.amount::text,
                         jsonb_build_object('category', new.category,
                                            'spent_on', new.spent_on));
  end if;
  return new;
end;
$$;

create trigger trg_expenses_audit
  after insert or update on expenses
  for each row execute function expenses_audit();

alter table expenses enable row level security;
revoke all on expenses from anon, authenticated;
grant select, insert, update on expenses to authenticated;

create policy expenses_select on expenses for select to authenticated
  using (can_see_money());
create policy expenses_insert on expenses for insert to authenticated
  with check (can_see_money());
create policy expenses_update on expenses for update to authenticated
  using (can_see_money()) with check (can_see_money());

-- Expense events carry amounts: they join the money-only entity types.
drop policy activities_select on activities;
create policy activities_select on activities for select to authenticated
  using (
    current_employee_id() is not null
    and (can_see_money()
         or entity_type not in ('quotation','payment','task_cost','expense'))
  );

-- -----------------------------------------------------------------------------
-- 5. v_report_payments — money received, one row per payment
-- -----------------------------------------------------------------------------
create view v_report_payments with (security_invoker = on) as
select p.id, p.paid_at, p.amount, p.method, p.kind, p.reference, p.notes,
       r.number   as request_number,
       r.title    as request_title,
       c.name     as customer,
       c.company  as company,
       s.full_name as supervisor,
       e.full_name as recorded_by,
       r.id       as request_id,
       r.supervisor_id
from payments p
join requests  r on r.id = p.request_id
join customers c on c.id = r.customer_id
left join employees s on s.id = r.supervisor_id
left join employees e on e.id = p.recorded_by
where can_see_money();

revoke all on v_report_payments from anon, authenticated;
grant select on v_report_payments to authenticated;

-- -----------------------------------------------------------------------------
-- Live updates for the new screens
-- -----------------------------------------------------------------------------
alter publication supabase_realtime add table inventory_items;
alter publication supabase_realtime add table stock_movements;
alter publication supabase_realtime add table expenses;
alter publication supabase_realtime add table employees;

-- -----------------------------------------------------------------------------
-- Tidy: views made after 003 kept Supabase's default grants (everything, to
-- anon too). Harmless — they are security_invoker over tables anon can't read
-- — but the rule is that grants say exactly what is used.
-- -----------------------------------------------------------------------------
revoke all on v_activity_feed, v_export_items, v_export_requests, v_task_summary
  from anon, authenticated;
grant select on v_activity_feed, v_export_items, v_export_requests, v_task_summary
  to authenticated;
