-- =============================================================================
-- Export read model test  (slice step 7)
--
--   docker exec -i supabase_db_inmore-ops psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 -q < supabase/tests/export_test.sql
--
-- The assertion that matters most is the last one in the first block: summing
-- the Items sheet must give the same number as summing the Requests sheet.
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
insert into customers (name, phone, company)
values ('Export Co.', '+974 4444 0000', 'Export Trading');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_request requests;
  v_a uuid; v_b uuid; v_c uuid;
  v_quote quotations;
  v_items_sum numeric;
  v_requests_sum numeric;
begin
  raise notice 'Export sheets:';

  select * into v_request from create_request(
    p_customer_id := (select id from customers where name = 'Export Co.'),
    p_items := jsonb_build_array(
      jsonb_build_object('name', 'Paper Cups', 'quantity', 5000, 'unit', 'pcs',
                         'specs', '8oz, 2-colour'),
      jsonb_build_object('name', 'Paper Bags', 'quantity', 2000, 'unit', 'pcs'),
      jsonb_build_object('name', 'Stickers',   'quantity', 500,  'unit', 'pcs')
    )
  );
  select id into v_a from request_items where request_id = v_request.id and position = 1;
  select id into v_b from request_items where request_id = v_request.id and position = 2;
  select id into v_c from request_items where request_id = v_request.id and position = 3;

  -- one row per item, priced or not
  perform _assert((select count(*) from v_export_items
                    where request_id = v_request.id) = 3,
                  'Items sheet has one row per item');
  perform _assert((select unit_price from v_export_items
                    where request_item_id = v_a) is null,
                  'unpriced items show null, not zero');
  perform _assert((select company from v_export_items
                    where request_item_id = v_a) = 'Export Trading',
                  'the customer company is on every item row');
  perform _assert((select spec from v_export_items
                    where request_item_id = v_a) = '8oz, 2-colour',
                  'the spec travels to the sheet');

  -- price two of the three and approve
  v_quote := create_quotation(v_request.id, jsonb_build_array(
    jsonb_build_object('request_item_id', v_a, 'unit_price', 0.75),
    jsonb_build_object('request_item_id', v_b, 'unit_price', 1.25)
  ));
  update quotations set status = 'APPROVED' where id = v_quote.id;

  perform _assert((select line_total from v_export_items where request_item_id = v_a) = 3750,
                  'line total is on the item row');
  perform _assert((select line_total from v_export_items where request_item_id = v_c) is null,
                  'the unquoted item stays null');
  perform _assert((select item_status from v_export_items where request_item_id = v_c)
                  = 'PENDING',
                  'its decision is still pending');

  insert into payments (request_id, amount, method, kind)
  values (v_request.id, 2000, 'CASH', 'DOWN_PAYMENT');

  -- Requests sheet
  perform _assert((select count(*) from v_export_requests
                    where request_id = v_request.id) = 1,
                  'Requests sheet has one row per request');
  perform _assert((select items from v_export_requests
                    where request_id = v_request.id) = 3,
                  'it counts the items');
  perform _assert((select approved_total from v_export_requests
                    where request_id = v_request.id) = 6250,
                  'approved total is 3750 + 2500');
  perform _assert((select balance from v_export_requests
                    where request_id = v_request.id) = 4250,
                  'balance is 6250 - 2000');

  -- THE assertion: the two sheets must agree, or the report is worthless.
  select coalesce(sum(line_total), 0) into v_items_sum
    from v_export_items where request_id = v_request.id;
  select coalesce(sum(approved_total), 0) into v_requests_sum
    from v_export_requests where request_id = v_request.id;
  perform _assert(v_items_sum = v_requests_sum,
                  'summing the Items sheet equals summing the Requests sheet');

  -- and the trap that shape avoids
  perform _assert(
    (select count(*) from information_schema.columns
      where table_name = 'v_export_items'
        and column_name in ('approved_total','paid','balance')) = 0,
    'request-level money is NOT repeated onto item rows');
end;
$$;
rollback;

-- -----------------------------------------------------------------------------
-- The export is money, so it is owner/supervisor only
-- -----------------------------------------------------------------------------
begin;
insert into customers (name, phone) values ('Export Guard Co.', '+974 4444 0001');
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
do $$
begin
  perform create_request(
    p_customer_id := (select id from customers where name = 'Export Guard Co.'),
    p_title       := 'Guard',
    p_items       := jsonb_build_array(
                       jsonb_build_object('name', 'Thing', 'quantity', 1))
  );
end;
$$;

reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
begin
  raise notice 'As DESIGNER:';
  perform _assert((select count(*) from v_export_items) = 0,
                  'the Items sheet is empty');
  perform _assert((select count(*) from v_export_requests) = 0,
                  'the Requests sheet is empty');
end;
$$;
rollback;

drop function _assert(boolean, text);

\echo ''
\echo 'Export read models: all assertions passed.'
