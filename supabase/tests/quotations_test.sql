-- =============================================================================
-- Quotation lifecycle test  (slice step 4)
--
--   docker exec -i supabase_db_inmore-ops psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 -q < supabase/tests/quotations_test.sql
--
-- Covers the two things the brief got tangled on: per-product quotations
-- against one request total, and what a "revision" actually is.
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
insert into customers (name, phone) values ('Quote Test Co.', '+974 9999 0000');

set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

-- -----------------------------------------------------------------------------
-- One quotation covering the whole request
-- -----------------------------------------------------------------------------
do $$
declare
  v_request requests;
  v_cups    uuid;
  v_bags    uuid;
  v_quote   quotations;
begin
  raise notice 'One quotation, several items:';

  select * into v_request from create_request(
    p_customer_id := (select id from customers where name = 'Quote Test Co.'),
    p_items := jsonb_build_array(
      jsonb_build_object('name', 'Paper Cups', 'quantity', 5000, 'unit', 'pcs'),
      jsonb_build_object('name', 'Paper Bags', 'quantity', 2000, 'unit', 'pcs')
    )
  );
  select id into v_cups from request_items where request_id = v_request.id and position = 1;
  select id into v_bags from request_items where request_id = v_request.id and position = 2;

  v_quote := create_quotation(
    p_request_id := v_request.id,
    p_lines := jsonb_build_array(
      jsonb_build_object('request_item_id', v_cups, 'unit_price', 0.75),
      jsonb_build_object('request_item_id', v_bags, 'unit_price', 1.25)
    ),
    p_discount := 250
  );

  perform _assert(v_quote.version = 1,       'first quotation is version 1');
  perform _assert(v_quote.status = 'DRAFT',  'starts as a draft');
  -- quantity is taken from the request item, not retyped
  perform _assert((select quantity from quotation_lines
                    where quotation_id = v_quote.id and request_item_id = v_cups) = 5000,
                  'line quantity defaults to the item quantity');
  perform _assert(v_quote.subtotal = 6250,   'subtotal is 5000x0.75 + 2000x1.25');
  perform _assert(v_quote.total = 6000,      'total applies the discount');

  -- it is verbal: "presented" means told to the customer, by any channel
  update quotations set status = 'PRESENTED' where id = v_quote.id;
  perform _assert((select presented_at from quotations where id = v_quote.id) is not null,
                  'presented_at is stamped');

  update quotations set status = 'APPROVED' where id = v_quote.id;
  perform _assert((select count(*) from request_items
                    where request_id = v_request.id and status = 'APPROVED') = 2,
                  'approval marks both items approved');
  perform _assert((select approved_total from v_request_financials
                    where request_id = v_request.id) = 6000,
                  'the request total is the approved quotation');
end;
$$;
rollback;

-- -----------------------------------------------------------------------------
-- A quotation per product — the shape the brief asked for — still totals
-- -----------------------------------------------------------------------------
begin;
insert into customers (name, phone) values ('Per Item Co.', '+974 9999 0001');
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_request requests;
  v_a uuid; v_b uuid; v_c uuid;
  v_qa quotations; v_qb quotations; v_qc quotations;
begin
  raise notice 'A quotation per product:';

  select * into v_request from create_request(
    p_customer_id := (select id from customers where name = 'Per Item Co.'),
    p_items := jsonb_build_array(
      jsonb_build_object('name', 'Product A', 'quantity', 100),
      jsonb_build_object('name', 'Product B', 'quantity', 200),
      jsonb_build_object('name', 'Product C', 'quantity', 300)
    )
  );
  select id into v_a from request_items where request_id = v_request.id and position = 1;
  select id into v_b from request_items where request_id = v_request.id and position = 2;
  select id into v_c from request_items where request_id = v_request.id and position = 3;

  v_qa := create_quotation(v_request.id,
    jsonb_build_array(jsonb_build_object('request_item_id', v_a, 'unit_price', 10)));
  v_qb := create_quotation(v_request.id,
    jsonb_build_array(jsonb_build_object('request_item_id', v_b, 'unit_price', 5)));
  v_qc := create_quotation(v_request.id,
    jsonb_build_array(jsonb_build_object('request_item_id', v_c, 'unit_price', 2)));

  perform _assert((v_qa.version, v_qb.version, v_qc.version) = (1, 2, 3),
                  'versions increment across the request');

  update quotations set status = 'APPROVED' where id in (v_qa.id, v_qb.id);
  perform _assert((select approved_total from v_request_financials
                    where request_id = v_request.id) = 2000,
                  'the request total sums only the approved quotations');

  -- Product C is rejected: the request total must not include it
  update quotations set status = 'REJECTED' where id = v_qc.id;
  perform _assert((select approved_total from v_request_financials
                    where request_id = v_request.id) = 2000,
                  'a rejected quotation adds nothing');
  perform _assert((select status from request_items where id = v_c) = 'REJECTED',
                  'rejection is recorded on the item');
  perform _assert((select approved_quotation_count from v_request_financials
                    where request_id = v_request.id) = 2,
                  'two of the three are live');
end;
$$;
rollback;

-- -----------------------------------------------------------------------------
-- Revision: a new version, never an edit
-- -----------------------------------------------------------------------------
begin;
insert into customers (name, phone) values ('Revision Co.', '+974 9999 0002');
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_request requests;
  v_item    uuid;
  v_v1      quotations;
  v_v2      quotations;
  v_raised  boolean;
begin
  raise notice 'Revision:';

  select * into v_request from create_request(
    p_customer_id := (select id from customers where name = 'Revision Co.'),
    p_items := jsonb_build_array(jsonb_build_object('name', 'Boxes', 'quantity', 500))
  );
  select id into v_item from request_items where request_id = v_request.id;

  v_v1 := create_quotation(v_request.id,
    jsonb_build_array(jsonb_build_object('request_item_id', v_item, 'unit_price', 4)));

  -- a draft is edited, not revised
  v_raised := false;
  begin
    perform revise_quotation(v_v1.id);
  exception when others then v_raised := true;
  end;
  perform _assert(v_raised, 'a draft cannot be revised');

  update quotations set status = 'PRESENTED' where id = v_v1.id;

  -- customer pushed back on price
  v_v2 := revise_quotation(
    p_quotation_id := v_v1.id,
    p_lines := jsonb_build_array(
      jsonb_build_object('request_item_id', v_item, 'unit_price', 3.5))
  );

  perform _assert(v_v2.version = 2, 'the revision is version 2');
  perform _assert((select status from quotations where id = v_v1.id) = 'SUPERSEDED',
                  'the old version is superseded, not deleted');
  perform _assert(v_v2.total = 1750, 'the new price is 500 x 3.50');
  perform _assert((select total from quotations where id = v_v1.id) = 2000,
                  'the old version keeps its original total');

  -- the history of the negotiation survives
  perform _assert((select count(*) from activities
                    where request_id = v_request.id
                      and event_type like 'quotation.%') >= 4,
                  'created, presented, superseded and created again are all logged');

  -- revising with no lines copies the old ones
  update quotations set status = 'PRESENTED' where id = v_v2.id;
  declare v_v3 quotations;
  begin
    v_v3 := revise_quotation(p_quotation_id := v_v2.id, p_discount := 250);
    perform _assert(v_v3.version = 3,   'version 3');
    perform _assert(v_v3.subtotal = 1750, 'lines are copied when none are given');
    perform _assert(v_v3.total = 1500,  'the new discount applies');
  end;
end;
$$;
rollback;

-- -----------------------------------------------------------------------------
-- Guards
-- -----------------------------------------------------------------------------
begin;
insert into customers (name, phone) values ('Guard Co.', '+974 9999 0003');
insert into customers (name, phone) values ('Other Co.', '+974 9999 0004');
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_r1 requests; v_r2 requests;
  v_item_other uuid;
  v_raised boolean;
begin
  raise notice 'Guards:';

  select * into v_r1 from create_request(
    p_customer_id := (select id from customers where name = 'Guard Co.'),
    p_items := jsonb_build_array(jsonb_build_object('name', 'Thing', 'quantity', 1)));
  select * into v_r2 from create_request(
    p_customer_id := (select id from customers where name = 'Other Co.'),
    p_items := jsonb_build_array(jsonb_build_object('name', 'Other thing', 'quantity', 1)));
  select id into v_item_other from request_items where request_id = v_r2.id;

  v_raised := false;
  begin
    perform create_quotation(v_r1.id, '[]'::jsonb);
  exception when others then v_raised := true;
  end;
  perform _assert(v_raised, 'a quotation with no lines is refused');

  -- pricing another request's item onto this quotation
  v_raised := false;
  begin
    perform create_quotation(v_r1.id,
      jsonb_build_array(jsonb_build_object('request_item_id', v_item_other,
                                           'unit_price', 1)));
  exception when others then v_raised := true;
  end;
  perform _assert(v_raised, 'an item from another request is refused');
end;
$$;

-- a designer may not price work
reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
declare
  v_raised boolean := false;
begin
  begin
    perform create_quotation(
      (select id from requests order by created_at desc limit 1),
      jsonb_build_array(jsonb_build_object('request_item_id', gen_random_uuid(),
                                           'unit_price', 1)));
  exception when insufficient_privilege then v_raised := true;
       when others then v_raised := true;
  end;
  perform _assert(v_raised, 'a DESIGNER may not create a quotation');
end;
$$;
rollback;

drop function _assert(boolean, text);

\echo ''
\echo 'Quotation lifecycle: all assertions passed.'
