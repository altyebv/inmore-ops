-- =============================================================================
-- Demo data — optional, never part of a real project's history.
--
-- `supabase db reset` does not run this; it is not in seed.sql on purpose,
-- because an empty database is the honest starting point and tests should not
-- depend on fixtures they did not create.
--
-- Run it when you want screens with something in them:
--
--   docker exec -i supabase_db_inmore-ops psql -U postgres -d postgres -q \
--     < supabase/demo_data.sql
--
-- On the hosted project, only with the test accounts from test_accounts.sql,
-- and wipe it with go_live_wipe.sql before real use:
--
--   npx supabase db query --linked -f supabase/demo_data.sql
--
-- People are found by the part of their email before the @, so the same file
-- works on the local seed (sara@inmore.local) and on hosted test accounts
-- (sara@inmore.test).  Anyone missing is covered by someone who exists —
-- Layla by Sara, everyone else by Ahmed, Ahmed by owner@ or any active owner —
-- so a single account is enough.
--
-- Runs as Ahmed so the history reads like a person did the work, rather than
-- every entry being attributed to the system.
-- =============================================================================

begin;

do $$
declare
  v_owner    uuid := coalesce((select id from employees
                       where is_active and email like 'owner@%' limit 1),
                     (select id from employees
                       where is_active and role = 'OWNER' order by created_at limit 1));
  v_ahmed    uuid := coalesce((select id from employees
                       where is_active and email like 'ahmed@%' limit 1), v_owner);
  v_sara     uuid := coalesce((select id from employees
                       where is_active and email like 'sara@%' limit 1), v_ahmed);
  v_layla    uuid := coalesce((select id from employees
                       where is_active and email like 'layla@%' limit 1), v_sara);
  v_mohammed uuid := coalesce((select id from employees
                       where is_active and email like 'mohammed@%' limit 1), v_ahmed);
  v_fatima   uuid := coalesce((select id from employees
                       where is_active and email like 'fatima@%' limit 1), v_ahmed);
begin
  if v_ahmed is null then
    raise exception 'No active owner@ or ahmed@ employee. Create the accounts first (test_accounts.sql).';
  end if;
  if exists (select 1 from customers where name = 'Khalid Al-Mansour') then
    raise exception 'Demo data is already loaded.';
  end if;

  perform set_config('demo.sara',     v_sara::text,     true);
  perform set_config('demo.layla',    v_layla::text,    true);
  perform set_config('demo.mohammed', v_mohammed::text, true);
  perform set_config('demo.fatima',   v_fatima::text,   true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_ahmed, 'role', 'authenticated')::text, true);
end;
$$;

set local role authenticated;

do $$
declare
  v_sara     uuid := current_setting('demo.sara')::uuid;
  v_layla    uuid := current_setting('demo.layla')::uuid;
  v_mohammed uuid := current_setting('demo.mohammed')::uuid;
  v_fatima   uuid := current_setting('demo.fatima')::uuid;
  v_partner  uuid;
  v_cust     uuid;
  v_req      requests;
  v_item     uuid;
  v_item2    uuid;
  v_quote    quotations;
begin
  -- The local seed has this partner; a hosted project starts with none.
  select id into v_partner from partners where name = 'Al Waab Signage';
  if v_partner is null then
    insert into partners (name, contact_name, phone, services)
    values ('Al Waab Signage', 'Yousef', '+974 4400 0003', 'Signage, vehicle wraps')
    returning id into v_partner;
  end if;

  ---------------------------------------------------------------- 1. in production, paid in part
  insert into customers (name, phone, company)
  values ('Khalid Al-Mansour', '+974 5544 1122', 'Mansour Cafe')
  returning id into v_cust;

  select * into v_req from create_request(
    p_customer_id := v_cust,
    p_title := 'Cafe opening pack',
    p_needed_by := (current_date + 6),
    p_items := jsonb_build_array(
      jsonb_build_object('name','Paper Cups','quantity',5000,'unit','pcs',
                         'specs','8oz, 2-colour'),
      jsonb_build_object('name','Paper Bags','quantity',2000,'unit','pcs')));
  select id into v_item  from request_items where request_id = v_req.id and position = 1;
  select id into v_item2 from request_items where request_id = v_req.id and position = 2;

  v_quote := create_quotation(v_req.id, jsonb_build_array(
    jsonb_build_object('request_item_id', v_item,  'unit_price', 0.75),
    jsonb_build_object('request_item_id', v_item2, 'unit_price', 1.25)), 250);
  update quotations set status = 'PRESENTED' where id = v_quote.id;
  update quotations set status = 'APPROVED'  where id = v_quote.id;

  insert into payments (request_id, amount, method, kind)
  values (v_req.id, 2500, 'CASH', 'DOWN_PAYMENT');

  insert into tasks (request_id, request_item_id, type, title, assignee_id, status)
  values (v_req.id, v_item, 'DESIGN', 'Cup artwork', v_sara, 'DONE');
  insert into tasks (request_id, type, title, assignee_id, status)
  values (v_req.id, 'PRODUCTION', 'Print run', v_mohammed, 'IN_PROGRESS');
  update requests set status = 'PRODUCTION' where id = v_req.id;

  ---------------------------------------------------------------- 2. blocked on the customer
  insert into customers (name, phone, company)
  values ('Mariam Hassan', '+974 3322 8899', 'Hassan Bakery')
  returning id into v_cust;

  select * into v_req from create_request(
    p_customer_id := v_cust,
    p_title := 'Ramadan packaging',
    p_needed_by := (current_date + 20),
    p_items := jsonb_build_array(
      jsonb_build_object('name','Food Boxes','quantity',3000,'unit','pcs')));
  select id into v_item from request_items where request_id = v_req.id;

  v_quote := create_quotation(v_req.id, jsonb_build_array(
    jsonb_build_object('request_item_id', v_item, 'unit_price', 2.10)));
  update quotations set status = 'PRESENTED' where id = v_quote.id;

  update requests set status = 'CUSTOMER_APPROVAL' where id = v_req.id;
  update requests set waiting_on = 'CUSTOMER'       where id = v_req.id;

  insert into tasks (request_id, type, title, assignee_id, status)
  values (v_req.id, 'DESIGN', 'Box artwork, 3 options', v_layla, 'DONE');

  ---------------------------------------------------------------- 3. overdue, waiting on a partner
  insert into customers (name, phone, company)
  values ('Al Waab Restaurant', '+974 7788 4455', 'Al Waab Group')
  returning id into v_cust;

  select * into v_req from create_request(
    p_customer_id := v_cust,
    p_title := 'Branch signage',
    p_needed_by := (current_date - 3),
    p_supervisor_id := v_fatima,
    p_items := jsonb_build_array(
      jsonb_build_object('name','Signage','quantity',4,'unit','pcs',
                         'specs','Illuminated, 2m x 0.6m')));
  select id into v_item from request_items where request_id = v_req.id;

  v_quote := create_quotation(v_req.id, jsonb_build_array(
    jsonb_build_object('request_item_id', v_item, 'unit_price', 1500)));
  update quotations set status = 'PRESENTED' where id = v_quote.id;
  update quotations set status = 'APPROVED'  where id = v_quote.id;

  insert into tasks (request_id, type, title, partner_id, status, started_at)
  values (v_req.id, 'EXTERNAL', 'Fabrication',
          v_partner,
          'IN_PROGRESS', now() - interval '9 days');
  update requests set status = 'PRODUCTION', waiting_on = 'PARTNER'
   where id = v_req.id;

  ---------------------------------------------------------------- 4. blocked on payment
  insert into customers (name, phone, company)
  values ('Noor Trading', '+974 6611 2200', 'Noor Trading WLL')
  returning id into v_cust;

  select * into v_req from create_request(
    p_customer_id := v_cust,
    p_title := 'Corporate stationery',
    p_needed_by := (current_date + 12),
    p_items := jsonb_build_array(
      jsonb_build_object('name','Business Cards','quantity',2000,'unit','pcs'),
      jsonb_build_object('name','Brochures','quantity',500,'unit','pcs')));
  select id into v_item  from request_items where request_id = v_req.id and position = 1;
  select id into v_item2 from request_items where request_id = v_req.id and position = 2;

  v_quote := create_quotation(v_req.id, jsonb_build_array(
    jsonb_build_object('request_item_id', v_item,  'unit_price', 0.45),
    jsonb_build_object('request_item_id', v_item2, 'unit_price', 6.00)));
  update quotations set status = 'PRESENTED' where id = v_quote.id;
  update quotations set status = 'APPROVED'  where id = v_quote.id;
  update requests set status = 'DESIGN', waiting_on = 'PAYMENT'
   where id = v_req.id;

  insert into tasks (request_id, type, title, assignee_id, status)
  values (v_req.id, 'DESIGN', 'Layout', v_sara, 'BLOCKED');

  ---------------------------------------------------------------- 5. fresh, nobody on it yet
  insert into customers (name, phone)
  values ('Yousef Ibrahim', '+974 5500 7788')
  returning id into v_cust;

  insert into requests (customer_id, source, status, title, notes)
  values (v_cust, 'WEBSITE', 'NEW', 'Enquiry from the website',
          'Wants 1000 printed boxes, asked for a price');
  insert into request_items (request_id, name, quantity, unit)
  select id, 'Custom Packaging', 1000, 'pcs' from requests
   where customer_id = v_cust;

  ---------------------------------------------------------------- 6. finished and paid
  insert into customers (name, phone, company)
  values ('Souq Gifts', '+974 4433 9911', 'Souq Gifts Est.')
  returning id into v_cust;

  select * into v_req from create_request(
    p_customer_id := v_cust,
    p_title := 'Gift stickers',
    p_items := jsonb_build_array(
      jsonb_build_object('name','Stickers','quantity',5000,'unit','pcs')));
  select id into v_item from request_items where request_id = v_req.id;

  v_quote := create_quotation(v_req.id, jsonb_build_array(
    jsonb_build_object('request_item_id', v_item, 'unit_price', 0.30)));
  update quotations set status = 'PRESENTED' where id = v_quote.id;
  update quotations set status = 'APPROVED'  where id = v_quote.id;
  insert into payments (request_id, amount, method, kind)
  values (v_req.id, 1500, 'ONLINE', 'FINAL');
  insert into tasks (request_id, type, title, assignee_id, status)
  values (v_req.id, 'DESIGN', 'Sticker sheet', v_layla, 'DONE');
  update requests set status = 'DELIVERY'  where id = v_req.id;
  update requests set status = 'COMPLETED' where id = v_req.id;
end;
$$;

commit;

select 'Demo data loaded: 6 requests across the pipeline.' as result;
