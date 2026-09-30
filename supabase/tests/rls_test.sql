-- =============================================================================
-- RLS, invariants and write-guard test.
--
-- Deliberately plain SQL rather than pgTAP so it runs anywhere psql runs.
--
--   npx supabase db reset
--   docker exec -i supabase_db_inmore-ops psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 -q < supabase/tests/rls_test.sql
--
-- Everything happens inside one transaction that is rolled back, so it is safe
-- to run against a database with real data in it.
--
-- NOTE: the assertions below insert real money rows first.  An earlier version
-- of this file checked that a designer reads zero quotations against an empty
-- table, which passes whether or not RLS works at all.  A test that cannot
-- fail is worse than no test.
-- =============================================================================

\set ON_ERROR_STOP on

create or replace function _assert(p_condition boolean, p_what text)
returns void language plpgsql as $$
begin
  if p_condition then
    raise notice '  ok    %', p_what;
  else
    raise exception 'FAILED: %', p_what;
  end if;
end;
$$;

begin;

-- -----------------------------------------------------------------------------
-- Fixture, as postgres: one request, two items, a quotation, a payment and an
-- external task with a cost.
-- -----------------------------------------------------------------------------
create temporary table _fx (k text primary key, v uuid) on commit drop;
-- readable after `set local role authenticated` below
grant select on _fx to authenticated;

do $$
declare
  v_customer uuid; v_request uuid; v_item_a uuid; v_item_b uuid;
  v_quote uuid; v_task uuid;
  v_supervisor uuid := '22222222-2222-2222-2222-222222222222';
begin
  insert into customers (name, phone, company)
  values ('Test Customer', '+974 3000 0000', 'Test Co.')
  returning id into v_customer;

  insert into requests (customer_id, supervisor_id, status, title)
  values (v_customer, v_supervisor, 'QUOTATION', 'Boundary test request')
  returning id into v_request;

  insert into request_items (request_id, name, quantity, unit, position)
  values (v_request, 'Paper Cups', 5000, 'pcs', 1)
  returning id into v_item_a;

  insert into request_items (request_id, name, quantity, unit, position)
  values (v_request, 'Paper Bags', 2000, 'pcs', 2)
  returning id into v_item_b;

  insert into quotations (request_id, version, discount, created_by)
  values (v_request, 1, 250, v_supervisor)
  returning id into v_quote;

  insert into quotation_lines (quotation_id, request_item_id, quantity, unit_price)
  values (v_quote, v_item_a, 5000, 0.75),
         (v_quote, v_item_b, 2000, 1.25);

  insert into tasks (request_id, type, title, partner_id)
  values (v_request, 'EXTERNAL', 'Outsourced printing',
          (select id from partners limit 1))
  returning id into v_task;

  insert into task_costs (task_id, amount) values (v_task, 900);

  insert into _fx values
    ('customer', v_customer), ('request', v_request),
    ('item_a', v_item_a), ('item_b', v_item_b),
    ('quote', v_quote), ('task', v_task);
end;
$$;

-- -----------------------------------------------------------------------------
-- Server-side money maths and the approval invariant
-- -----------------------------------------------------------------------------
do $$
declare
  v_request uuid := (select v from _fx where k = 'request');
  v_quote   uuid := (select v from _fx where k = 'quote');
  v_item_a  uuid := (select v from _fx where k = 'item_a');
  v_q2      uuid;
  v_raised  boolean := false;
begin
  raise notice 'Quotation totals and invariants:';

  -- 5000 * 0.75 = 3750, 2000 * 1.25 = 2500, subtotal 6250, less 250 discount
  perform _assert((select subtotal from quotations where id = v_quote) = 6250,
                  'subtotal is computed from the lines');
  perform _assert((select total from quotations where id = v_quote) = 6000,
                  'total applies the discount');

  perform _assert((select count(*) from request_items
                    where request_id = v_request and status = 'PENDING') = 2,
                  'items start PENDING');

  update quotations set status = 'APPROVED' where id = v_quote;

  perform _assert((select count(*) from request_items
                    where request_id = v_request and status = 'APPROVED') = 2,
                  'approving a quotation approves its items');
  perform _assert((select decided_at from quotations where id = v_quote) is not null,
                  'decided_at is stamped on approval');

  -- A second approved quotation over the same item must be refused, or the
  -- request total would double-count it.
  insert into quotations (request_id, version) values (v_request, 2)
  returning id into v_q2;
  insert into quotation_lines (quotation_id, request_item_id, quantity, unit_price)
  values (v_q2, v_item_a, 5000, 0.80);

  begin
    update quotations set status = 'APPROVED' where id = v_q2;
  exception when check_violation then
    v_raised := true;
  end;
  perform _assert(v_raised,
                  'a second approved quotation over the same item is refused');

  insert into payments (request_id, amount, method, kind)
  values (v_request, 2000, 'CASH', 'DOWN_PAYMENT');
end;
$$;

-- -----------------------------------------------------------------------------
-- As Sara (DESIGNER): the money must be invisible by every route
-- -----------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
declare
  v_request uuid := (select v from _fx where k = 'request');
begin
  raise notice 'As DESIGNER (sara@inmore.local), with money in the database:';

  perform _assert(current_role_name() = 'DESIGNER', 'role resolves to DESIGNER');
  perform _assert(not can_see_money(),              'can_see_money() is false');

  perform _assert((select count(*) from quotations)      = 0, 'quotations hidden');
  perform _assert((select count(*) from quotation_lines) = 0, 'quotation_lines hidden');
  perform _assert((select count(*) from payments)        = 0, 'payments hidden');
  perform _assert((select count(*) from task_costs)      = 0, 'task_costs hidden');

  -- Without security_invoker this view would read straight past all of the above
  perform _assert((select count(*) from v_request_financials) = 0,
                  'v_request_financials hidden');

  -- The back door: amounts ride in activity metadata
  perform _assert((select count(*) from activities
                    where entity_type in ('quotation','payment','task_cost')) = 0,
                  'money activity events hidden');

  -- ...while the operational record still works
  perform _assert((select count(*) from requests where id = v_request) = 1,
                  'the request itself is readable');
  perform _assert((select count(*) from v_request_summary where id = v_request) = 1,
                  'v_request_summary is readable');
  perform _assert((select count(*) from activities
                    where request_id = v_request and entity_type = 'request') > 0,
                  'request activity events are readable');
  perform _assert((select count(*) from request_items
                    where request_id = v_request) = 2,
                  'items are readable');
end;
$$;

-- -----------------------------------------------------------------------------
-- As Ahmed (SUPERVISOR): the same data must be fully visible and correct
-- -----------------------------------------------------------------------------
reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_request uuid := (select v from _fx where k = 'request');
  v_fin     record;
begin
  raise notice 'As SUPERVISOR (ahmed@inmore.local):';

  perform _assert(current_role_name() = 'SUPERVISOR', 'role resolves to SUPERVISOR');
  perform _assert(can_see_money(),                    'can_see_money() is true');

  perform _assert((select count(*) from quotations
                    where request_id = v_request) = 2, 'quotations visible');
  perform _assert((select count(*) from payments
                    where request_id = v_request) = 1, 'payments visible');
  perform _assert((select count(*) from task_costs) = 1, 'task_costs visible');
  perform _assert((select count(*) from activities
                    where entity_type in ('quotation','payment','task_cost')) > 0,
                  'money activity events visible');

  select * into v_fin from v_request_financials where request_id = v_request;
  perform _assert(v_fin.approved_total = 6000, 'approved_total is 6000');
  perform _assert(v_fin.paid_total     = 2000, 'paid_total is 2000');
  perform _assert(v_fin.balance        = 4000, 'balance is 4000');
  perform _assert(v_fin.approved_quotation_count = 1,
                  'only the approved quotation counts');
end;
$$;

rollback;

-- =============================================================================
-- Write guards.  Column-level write rules are enforced by trigger, not by
-- GRANT UPDATE (col,...), which cannot discriminate between app roles under
-- Supabase's shared `authenticated` database role.
-- =============================================================================
begin;
insert into customers (name, phone) values ('Guard Test Customer', '+974 3000 0001');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
declare
  v_request uuid;
  v_blocked boolean;
begin
  raise notice 'Write guards, as DESIGNER:';

  -- The brief lists DESIGNER as a request source, so this must work.
  insert into requests (customer_id, source, status)
  values ((select id from customers where name = 'Guard Test Customer'),
          'DESIGNER', 'NEW')
  returning id into v_request;
  perform _assert(v_request is not null, 'may create a request');

  update requests set status = 'DESIGN' where id = v_request;
  perform _assert((select status from requests where id = v_request) = 'DESIGN',
                  'may move the status along');

  v_blocked := false;
  begin
    update requests set title = 'hijacked' where id = v_request;
  exception when insufficient_privilege then v_blocked := true;
  end;
  perform _assert(v_blocked, 'may NOT edit anything else on the request');

  v_blocked := false;
  begin
    insert into payments (request_id, amount, method, kind)
    values (v_request, 10, 'CASH', 'PARTIAL');
  exception when insufficient_privilege then v_blocked := true;
  end;
  perform _assert(v_blocked, 'may NOT record a payment');

  -- Work is handed over verbally, so self-assignment has to work.
  insert into tasks (request_id, type, title, assignee_id)
  values (v_request, 'DESIGN', 'My own task',
          '44444444-4444-4444-4444-444444444444');
  perform _assert(true, 'may create a task for themselves');

  v_blocked := false;
  begin
    insert into tasks (request_id, type, title, assignee_id)
    values (v_request, 'DESIGN', 'Task for someone else',
            '66666666-6666-6666-6666-666666666666');
  exception when insufficient_privilege then v_blocked := true;
  end;
  perform _assert(v_blocked, 'may NOT assign work to someone else');
end;
$$;
rollback;

-- =============================================================================
-- The website's only write path: one security-definer RPC, no table grants.
-- =============================================================================
begin;
set local role anon;
select create_public_request(
  'Web Visitor', '+974 5555 1234', 'web@example.com', 'Web Co.',
  'Need 1000 boxes',
  '[{"name":"Custom Boxes","quantity":1000,"unit":"pcs"}]'::jsonb
) as request_number \gset

reset role;
do $$
declare
  v_request uuid := (select id from requests where source = 'WEBSITE'
                      order by created_at desc limit 1);
begin
  raise notice 'Public website RPC:';

  perform _assert(v_request is not null, 'anon may create a request via the RPC');
  perform _assert((select count(*) from request_items where request_id = v_request) = 1,
                  'items arrive with it');
  perform _assert((select count(*) from customers where phone = '+974 5555 1234') = 1,
                  'the customer is created');
  perform _assert((select bool_and(actor_kind = 'CUSTOMER') from activities
                    where request_id = v_request),
                  'activity is attributed to the CUSTOMER, not an employee');
  perform _assert((select supervisor_id from requests where id = v_request) is null,
                  'no supervisor is assumed - a human picks it up');
end;
$$;

-- anon must not be able to reach the tables directly
set local role anon;
do $$
declare
  v_blocked boolean := false;
begin
  begin
    perform count(*) from requests;
  exception when insufficient_privilege then v_blocked := true;
  end;
  perform _assert(v_blocked, 'anon may NOT read the requests table directly');
end;
$$;
rollback;

drop function _assert(boolean, text);

\echo ''
\echo 'RLS, invariants, write guards and the public RPC: all assertions passed.'
