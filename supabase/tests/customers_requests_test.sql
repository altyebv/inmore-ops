-- =============================================================================
-- Customer search and request creation test  (slice steps 1 and 2)
--
--   docker exec -i supabase_db_inmore-ops psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 -q < supabase/tests/customers_requests_test.sql
--
-- Runs inside transactions that are rolled back.
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

-- -----------------------------------------------------------------------------
-- Phone normalization: the three spellings of one Qatari number must collapse.
-- -----------------------------------------------------------------------------
do $$
begin
  raise notice 'Phone normalization:';
  perform _assert(normalize_phone('+974 5555 1234') = '55551234', '+974 5555 1234');
  perform _assert(normalize_phone('97455551234')    = '55551234', '97455551234');
  perform _assert(normalize_phone('5555-1234')      = '55551234', '5555-1234');
  perform _assert(normalize_phone('  55551234 ')    = '55551234', 'padded digits');
  perform _assert(normalize_phone(null) is null,                  'null stays null');
  perform _assert(normalize_phone('')   is null,                  'empty stays null');
  perform _assert(normalize_phone('n/a') is null,                 'no digits is null');
  -- A non-Qatari number keeps its digits rather than being guessed at.
  perform _assert(normalize_phone('+44 20 7946 0000') = '442079460000', 'foreign number kept');
end;
$$;

-- -----------------------------------------------------------------------------
-- Search and duplicate detection
-- -----------------------------------------------------------------------------
begin;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_a uuid; v_b uuid; v_c uuid;
begin
  raise notice 'Customer search:';

  insert into customers (name, phone, company)
  values ('Khalid Al-Mansour', '+974 5555 1234', 'Mansour Trading') returning id into v_a;
  insert into customers (name, phone, company)
  values ('Mariam Hassan', '55551234', 'Hassan Cafe') returning id into v_b;
  insert into customers (name, phone, company)
  values ('Al Waab Restaurant', '+974 6600 9988', null) returning id into v_c;

  perform _assert((select phone_normalized from customers where id = v_a) = '55551234',
                  'phone_normalized is generated');

  -- Assertions are scoped to the rows this test created, never to a global
  -- count. A test that asserts "search finds exactly one Khalid" passes on an
  -- empty database and fails the moment the business has two — which is a
  -- failing test reporting healthy code, the worst kind.
  perform _assert(exists(select 1 from search_customers('Khalid') where id = v_a),
                  'search by first name');
  perform _assert(exists(select 1 from search_customers('mansour') where id = v_a),
                  'search is case-insensitive');
  perform _assert(exists(select 1 from search_customers('Hassan Cafe') where id = v_b),
                  'search matches on company as well as name');
  perform _assert(exists(select 1 from search_customers('Al Waab') where id = v_c),
                  'search by full name');

  -- the point of normalizing: any spelling of the number finds both records
  perform _assert((select count(*) from search_customers('+974 5555 1234')
                    where id in (v_a, v_b)) = 2,
                  'search by international phone format');
  perform _assert((select count(*) from search_customers('5555-1234')
                    where id in (v_a, v_b)) = 2,
                  'search by punctuated phone format');

  perform _assert((select count(*) from search_customers(null)) >= 3,
                  'empty query lists customers');

  perform _assert((select count(*) from customers_sharing_phone('97455551234')
                    where id in (v_a, v_b)) = 2,
                  'duplicate warning finds both spellings');
  perform _assert(not exists(select 1 from customers_sharing_phone('97455551234', v_a)
                              where id = v_a),
                  'the record being edited excludes itself');
  perform _assert((select count(*) from customers_sharing_phone('+974 6600 9988')
                    where id = v_c) = 1,
                  'a unique number has no duplicates');

  update customers set is_archived = true where id = v_c;
  perform _assert(not exists(select 1 from search_customers('Al Waab') where id = v_c),
                  'archived customers drop out of search');
end;
$$;
rollback;

-- -----------------------------------------------------------------------------
-- create_request: atomic, role-aware, and it logs
-- -----------------------------------------------------------------------------
begin;
insert into customers (name, phone) values ('Request Test Co.', '+974 7777 0000');

-- as Ahmed, a SUPERVISOR
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_customer uuid := (select id from customers where name = 'Request Test Co.');
  v_request  requests;
  v_cups     uuid := (select id from products where name = 'Paper Cups');
begin
  raise notice 'create_request, as SUPERVISOR:';

  select * into v_request from create_request(
    p_customer_id := v_customer,
    p_title       := 'Cafe opening pack',
    p_items       := jsonb_build_array(
      jsonb_build_object('product_id', v_cups, 'quantity', 5000, 'unit', 'pcs'),
      jsonb_build_object('name', 'Custom printed boxes', 'quantity', 500,
                         'unit', 'pcs', 'specs', '3-colour, matte')
    )
  );

  perform _assert(v_request.number >= 1001,             'request gets a human number');
  perform _assert(v_request.status = 'NEW',             'starts at NEW');
  perform _assert(v_request.source = 'SUPERVISOR',      'source follows the role');
  perform _assert(v_request.supervisor_id = '22222222-2222-2222-2222-222222222222',
                  'a supervisor owns the request they create');

  perform _assert((select count(*) from request_items where request_id = v_request.id) = 2,
                  'both items are created in the same call');
  perform _assert((select name from request_items
                    where request_id = v_request.id and position = 1) = 'Paper Cups',
                  'the catalog product name is snapshotted onto the item');
  perform _assert((select product_id from request_items
                    where request_id = v_request.id and position = 2) is null,
                  'a free-form item needs no catalog entry');

  -- renaming the catalog entry must not rewrite history
  update products set name = 'Paper Cups (discontinued)' where id = v_cups;
  perform _assert((select name from request_items
                    where request_id = v_request.id and position = 1) = 'Paper Cups',
                  'renaming the product does not change the item');

  perform _assert((select count(*) from activities
                    where request_id = v_request.id
                      and event_type = 'request.created') = 1,
                  'request.created is logged');
  perform _assert((select count(*) from activities
                    where request_id = v_request.id
                      and event_type = 'item.added') = 2,
                  'both items are logged');
  perform _assert((select actor_id from activities
                    where request_id = v_request.id
                      and event_type = 'request.created')
                  = '22222222-2222-2222-2222-222222222222',
                  'the actor is recorded');
end;
$$;

-- as Sara, a DESIGNER
reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
declare
  v_customer uuid := (select id from customers where name = 'Request Test Co.');
  v_request  requests;
  v_raised   boolean := false;
begin
  raise notice 'create_request, as DESIGNER:';

  select * into v_request from create_request(
    p_customer_id := v_customer,
    p_title       := 'Walk-in, designer took it',
    p_items       := jsonb_build_array(jsonb_build_object('name', 'Logo redesign'))
  );

  perform _assert(v_request.source = 'DESIGNER',        'source is DESIGNER');
  perform _assert(v_request.supervisor_id is null,
                  'no supervisor is assumed - it lands on the attention list');
  perform _assert((select quantity from request_items
                    where request_id = v_request.id) = 1,
                  'quantity defaults to 1');

  -- an item with neither a name nor a catalog product is refused
  begin
    perform create_request(
      p_customer_id := v_customer,
      p_items       := jsonb_build_array(jsonb_build_object('quantity', 10))
    );
  exception when others then v_raised := true;
  end;
  perform _assert(v_raised, 'an item with no name and no product is refused');
end;
$$;
rollback;

-- -----------------------------------------------------------------------------
-- The whole point of the request/item split: one request, many products
-- -----------------------------------------------------------------------------
begin;
insert into customers (name, phone) values ('Multi Item Co.', '+974 7777 0001');
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_request requests;
begin
  raise notice 'One request, three products:';

  select * into v_request from create_request(
    p_customer_id := (select id from customers where name = 'Multi Item Co.'),
    p_items := jsonb_build_array(
      jsonb_build_object('name', 'Paper Cups',   'quantity', 5000),
      jsonb_build_object('name', 'Paper Bags',   'quantity', 2000),
      jsonb_build_object('name', 'Stickers',     'quantity', 500)
    )
  );

  perform _assert((select count(*) from request_items where request_id = v_request.id) = 3,
                  'three items stay inside one request');
  perform _assert((select item_count from v_request_summary where id = v_request.id) = 3,
                  'v_request_summary reports the item count');
  perform _assert((select array_agg(position order by position)
                     from request_items where request_id = v_request.id)
                  = array[1,2,3],
                  'item order is preserved');
end;
$$;
rollback;

drop function _assert(boolean, text);

\echo ''
\echo 'Customer search and request creation: all assertions passed.'
