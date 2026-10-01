-- =============================================================================
-- Lifecycle and payments test  (slice steps 5 and 6)
--
--   docker exec -i supabase_db_inmore-ops psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 -q < supabase/tests/lifecycle_payments_test.sql
--
-- The assertions worth reading are the ones about `waiting_on`: the reason a
-- request is stuck is kept separately from where it is, so blocking a job in
-- PRODUCTION does not lose the fact that it was in production.
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
insert into customers (name, phone) values ('Lifecycle Co.', '+974 1111 0000');
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

-- -----------------------------------------------------------------------------
-- Stage and blocking are orthogonal
-- -----------------------------------------------------------------------------
do $$
declare
  v_request requests;
  v_id      uuid;
begin
  raise notice 'Stage vs waiting:';

  select * into v_request from create_request(
    p_customer_id := (select id from customers where name = 'Lifecycle Co.'),
    p_items := jsonb_build_array(jsonb_build_object('name', 'Boxes', 'quantity', 500)));
  v_id := v_request.id;

  update requests set status = 'PRODUCTION' where id = v_id;
  update requests set waiting_on = 'PAYMENT'  where id = v_id;

  -- This is the whole point of the two-column design.
  perform _assert((select status from requests where id = v_id) = 'PRODUCTION',
                  'blocking on payment does not lose the stage');
  perform _assert((select waiting_on from requests where id = v_id) = 'PAYMENT',
                  'the reason is recorded separately');

  perform _assert((select count(*) from activities
                    where request_id = v_id and event_type = 'request.waiting_set') = 1,
                  'the block is logged');

  update requests set waiting_on = null where id = v_id;
  perform _assert((select count(*) from activities
                    where request_id = v_id and event_type = 'request.waiting_cleared') = 1,
                  'unblocking is logged');
  perform _assert((select status from requests where id = v_id) = 'PRODUCTION',
                  'unblocking returns to the stage it never left');
end;
$$;

-- -----------------------------------------------------------------------------
-- Terminal states, and coming back out of them
-- -----------------------------------------------------------------------------
do $$
declare
  v_id uuid := (select id from requests
                 where customer_id = (select id from customers where name = 'Lifecycle Co.')
                 limit 1);
  v_raised boolean := false;
begin
  raise notice 'Terminal states:';

  update requests set status = 'COMPLETED' where id = v_id;
  perform _assert((select completed_at from requests where id = v_id) is not null,
                  'completed_at is stamped');

  update requests set status = 'PRODUCTION' where id = v_id;
  perform _assert((select completed_at from requests where id = v_id) is null,
                  'reopening clears completed_at');
  perform _assert((select count(*) from activities
                    where request_id = v_id and event_type = 'request.reopened') = 1,
                  'reopening is logged, not hidden');

  -- cancelling without a reason is refused
  begin
    update requests set status = 'CANCELLED' where id = v_id;
  exception when check_violation then v_raised := true;
  end;
  perform _assert(v_raised, 'cancelling requires a reason');

  update requests set status = 'CANCELLED', cancel_reason = 'Customer went elsewhere'
   where id = v_id;
  perform _assert((select cancelled_at from requests where id = v_id) is not null,
                  'cancelled_at is stamped');
  perform _assert((select metadata ->> 'reason' from activities
                    where request_id = v_id and event_type = 'request.cancelled')
                  = 'Customer went elsewhere',
                  'the reason is in the log');
end;
$$;
rollback;

-- -----------------------------------------------------------------------------
-- Stage durations: the analytics seed
-- -----------------------------------------------------------------------------
begin;
insert into customers (name, phone) values ('Duration Co.', '+974 1111 0001');
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

create temporary table _dur (k text primary key, v uuid) on commit drop;
grant select, insert on _dur to authenticated;

do $$
declare
  v_request requests;
begin
  select * into v_request from create_request(
    p_customer_id := (select id from customers where name = 'Duration Co.'),
    p_items := jsonb_build_array(jsonb_build_object('name', 'Flyers', 'quantity', 1000)));
  insert into _dur values ('request', v_request.id);

  update requests set status = 'QUOTATION'  where id = v_request.id;
  update requests set status = 'DESIGN'     where id = v_request.id;
  update requests set status = 'PRODUCTION' where id = v_request.id;
end;
$$;

-- Backdating has to happen as postgres: `authenticated` has no UPDATE grant on
-- activities at all, which is the append-only guarantee working. Any fixture
-- that needs to rewrite history is, by definition, an admin path.
reset role;
update activities set occurred_at = now() - interval '10 days'
 where request_id = (select v from _dur where k = 'request') and to_value = 'QUOTATION';
update activities set occurred_at = now() - interval '7 days'
 where request_id = (select v from _dur where k = 'request') and to_value = 'DESIGN';
update activities set occurred_at = now() - interval '2 days'
 where request_id = (select v from _dur where k = 'request') and to_value = 'PRODUCTION';

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_request requests;
begin
  raise notice 'Stage durations:';
  select * into v_request from requests where id = (select v from _dur where k = 'request');

  perform _assert((select count(*) from v_request_stage_durations
                    where request_id = v_request.id) = 3,
                  'one row per stage entered');
  perform _assert((select duration from v_request_stage_durations
                    where request_id = v_request.id and stage = 'QUOTATION')
                  = interval '3 days',
                  'time in QUOTATION is 3 days');
  perform _assert((select duration from v_request_stage_durations
                    where request_id = v_request.id and stage = 'DESIGN')
                  = interval '5 days',
                  'design took 5 days');
  perform _assert((select left_at from v_request_stage_durations
                    where request_id = v_request.id and stage = 'PRODUCTION') is null,
                  'the current stage has no end yet');
end;
$$;
rollback;

-- -----------------------------------------------------------------------------
-- Payments and the balance
-- -----------------------------------------------------------------------------
begin;
insert into customers (name, phone) values ('Payment Co.', '+974 1111 0002');
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_request requests;
  v_item    uuid;
  v_quote   quotations;
  v_fin     record;
begin
  raise notice 'Payments:';

  select * into v_request from create_request(
    p_customer_id := (select id from customers where name = 'Payment Co.'),
    p_items := jsonb_build_array(jsonb_build_object('name', 'Signage', 'quantity', 4)));
  select id into v_item from request_items where request_id = v_request.id;

  -- A down payment can arrive before anything is priced. This is normal, and
  -- the UI must say "paid X, nothing approved yet" rather than show a negative
  -- balance.
  insert into payments (request_id, amount, method, kind)
  values (v_request.id, 1000, 'CASH', 'DOWN_PAYMENT');

  select * into v_fin from v_request_financials where request_id = v_request.id;
  perform _assert(v_fin.paid_total = 1000,               'the down payment is recorded');
  perform _assert(v_fin.approved_quotation_count = 0,    'nothing is approved yet');
  perform _assert(v_fin.balance = -1000,
                  'balance is negative until something is approved - the UI must '
                  'check approved_quotation_count');

  v_quote := create_quotation(v_request.id,
    jsonb_build_array(jsonb_build_object('request_item_id', v_item, 'unit_price', 1500)));
  update quotations set status = 'APPROVED' where id = v_quote.id;

  select * into v_fin from v_request_financials where request_id = v_request.id;
  perform _assert(v_fin.approved_total = 6000, 'approved total is 4 x 1500');
  perform _assert(v_fin.balance = 5000,        'balance is 6000 - 1000');

  insert into payments (request_id, amount, method, kind)
  values (v_request.id, 5000, 'BANK_TRANSFER', 'FINAL');

  select * into v_fin from v_request_financials where request_id = v_request.id;
  perform _assert(v_fin.paid_total = 6000, 'both payments sum');
  perform _assert(v_fin.balance = 0,       'the request is settled');

  perform _assert((select count(*) from activities
                    where request_id = v_request.id
                      and event_type = 'payment.recorded') = 2,
                  'both payments are logged');
  -- Order by id, never occurred_at: now() is the TRANSACTION timestamp, so
  -- every event written by one operation shares it. The monotonic id is the
  -- only reliable ordering, and the timeline query must use it.
  perform _assert((select metadata ->> 'method' from activities
                    where request_id = v_request.id
                      and event_type = 'payment.recorded'
                    order by id desc limit 1) = 'BANK_TRANSFER',
                  'the method is in the log');
  perform _assert((select count(distinct occurred_at) from activities
                    where request_id = v_request.id
                      and event_type = 'payment.recorded') = 1,
                  'both payments share occurred_at - id is what orders them');

  -- payments are never edited or removed
  declare v_blocked boolean := false;
  begin
    begin
      update payments set amount = 1 where request_id = v_request.id;
    exception when insufficient_privilege then v_blocked := true;
    end;
    perform _assert(v_blocked, 'a recorded payment cannot be altered');
  end;
end;
$$;
rollback;

-- -----------------------------------------------------------------------------
-- The timeline a designer sees
-- -----------------------------------------------------------------------------
begin;
insert into customers (name, phone) values ('Feed Co.', '+974 1111 0003');
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

create temporary table _fx (k text primary key, v uuid) on commit drop;
grant select, insert on _fx to authenticated;

do $$
declare
  v_request requests;
  v_item    uuid;
  v_quote   quotations;
begin
  select * into v_request from create_request(
    p_customer_id := (select id from customers where name = 'Feed Co.'),
    p_items := jsonb_build_array(jsonb_build_object('name', 'Cards', 'quantity', 200)));
  select id into v_item from request_items where request_id = v_request.id;
  insert into _fx values ('request', v_request.id);

  v_quote := create_quotation(v_request.id,
    jsonb_build_array(jsonb_build_object('request_item_id', v_item, 'unit_price', 2)));
  update quotations set status = 'APPROVED' where id = v_quote.id;
  insert into payments (request_id, amount, method, kind)
  values (v_request.id, 400, 'CASH', 'FINAL');
  update requests set status = 'PRODUCTION' where id = v_request.id;

  raise notice 'Activity feed, as SUPERVISOR:';
  perform _assert((select count(*) from v_activity_feed
                    where request_id = v_request.id
                      and entity_type in ('quotation','payment')) >= 3,
                  'money events are in the feed');
  perform _assert((select actor_name from v_activity_feed
                    where request_id = v_request.id
                      and event_type = 'request.created') = 'Ahmed',
                  'the feed names the actor');
  perform _assert((select request_number from v_activity_feed
                    where request_id = v_request.id limit 1) = v_request.number,
                  'the feed carries the request number');
end;
$$;

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
declare
  v_request uuid := (select v from _fx where k = 'request');
begin
  raise notice 'Activity feed, as DESIGNER:';

  perform _assert((select count(*) from v_activity_feed
                    where request_id = v_request
                      and entity_type in ('quotation','payment')) = 0,
                  'money events are absent, not redacted');
  perform _assert((select count(*) from v_activity_feed
                    where request_id = v_request
                      and event_type = 'request.status_changed') = 1,
                  'the operational story is intact');
  perform _assert((select count(*) from v_activity_feed
                    where request_id = v_request and event_type = 'item.added') = 1,
                  'items are visible');
end;
$$;
rollback;

drop function _assert(boolean, text);

\echo ''
\echo 'Lifecycle, durations, payments and the feed: all assertions passed.'
