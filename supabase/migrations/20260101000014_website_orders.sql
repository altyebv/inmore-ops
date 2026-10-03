-- =============================================================================
-- 014 — Website orders
--
-- The website is about to call create_public_request for real, so the RPC
-- stops trusting its input:
--
-- 1. product_web_skus: the website's product ids mapped onto the catalog, so a
--    website item lands on a catalog product and counts in product demand.
-- 2. create_public_request: same signature, same grant.  It now validates and
--    caps what an anonymous caller sends, resolves `sku` to a catalog product,
--    and keeps the name a visitor typed when the phone already belongs to a
--    customer.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Website SKUs
--
-- A table rather than a column on products: the website sells sizes and
-- variants ("paper-cup-8oz", later "paper-cup-12oz") that are one product
-- here.  Many SKUs, one product.
--
-- A vocabulary, like the catalog itself: an unmapped SKU is not an error, the
-- item just arrives free-form under the name the website sent.
-- -----------------------------------------------------------------------------
create table product_web_skus (
  sku        text primary key,
  product_id uuid not null references products(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index product_web_skus_product_idx on product_web_skus (product_id);

alter table product_web_skus enable row level security;

-- Supabase grants new tables to anon and authenticated by default.
revoke all on product_web_skus from anon, authenticated;
grant select, insert, update, delete on product_web_skus to authenticated;

create policy product_web_skus_select on product_web_skus for select to authenticated
  using (current_employee_id() is not null);

create policy product_web_skus_insert on product_web_skus for insert to authenticated
  with check (is_supervisor_or_owner());

create policy product_web_skus_update on product_web_skus for update to authenticated
  using (is_supervisor_or_owner())
  with check (is_supervisor_or_owner());

create policy product_web_skus_delete on product_web_skus for delete to authenticated
  using (is_supervisor_or_owner());

-- The products the website has today.  Joined on name so a project whose
-- catalog was edited by hand skips what it no longer has.
insert into product_web_skus (sku, product_id)
select m.sku, p.id
  from (values
    ('paper-cup-8oz',      'Paper Cups'),
    ('shopping-bag-paper', 'Paper Bags'),
    ('takeaway-package',   'Paper Bags'),
    ('gift-box-rigid',     'Custom Packaging')
  ) as m (sku, product_name)
  join products p on p.name = m.product_name
on conflict (sku) do nothing;

-- -----------------------------------------------------------------------------
-- 2. The website's only write path
--
-- Each item is {sku?, name?, quantity?, unit?, specs?}.
--
-- An existing customer is matched by phone and never changed from here: the
-- caller is anonymous, so anything it could overwrite, anyone could.  What the
-- visitor typed about themselves goes into the request's notes instead, where a
-- supervisor reads it and decides.
-- -----------------------------------------------------------------------------
create or replace function create_public_request(
  p_customer_name text,
  p_phone         text,
  p_email         text default null,
  p_company       text default null,
  p_message       text default null,
  p_items         jsonb default '[]'::jsonb
) returns int
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_name        text := left(trim(coalesce(p_customer_name, '')), 120);
  v_phone       text := left(trim(coalesce(p_phone, '')), 30);
  v_email       text := nullif(left(trim(coalesce(p_email, '')), 200), '');
  v_company     text := nullif(left(trim(coalesce(p_company, '')), 120), '');
  v_notes       text := nullif(left(trim(coalesce(p_message, '')), 2000), '');
  v_items       jsonb := coalesce(p_items, '[]'::jsonb);
  v_customer    customers;
  v_request_id  uuid;
  v_number      int;
  v_item        jsonb;
  v_position    int := 0;
  v_product     products;
  v_item_name   text;
  v_quantity    text;
begin
  if v_name = '' then
    raise exception 'A name is required.';
  end if;
  if length(coalesce(normalize_phone(v_phone), '')) not between 8 and 15 then
    raise exception 'A valid phone number is required.';
  end if;
  if jsonb_typeof(v_items) <> 'array' then
    raise exception 'Items must be a list.';
  end if;
  if jsonb_array_length(v_items) > 20 then
    raise exception 'An order can hold at most 20 items.';
  end if;

  select * into v_customer
    from customers
   where phone_normalized = normalize_phone(v_phone)
   order by created_at
   limit 1;

  if v_customer.id is null then
    insert into customers (name, phone, email, company)
    values (v_name, v_phone, v_email, v_company)
    returning * into v_customer;
  elsif lower(v_customer.name) <> lower(v_name)
     or (v_email   is not null and v_email   is distinct from v_customer.email)
     or (v_company is not null and v_company is distinct from v_customer.company) then
    v_notes := concat_ws(E'\n\n', v_notes,
      'Sent from the website as: ' || concat_ws(', ', v_name, v_company, v_email));
  end if;

  insert into requests (customer_id, source, status, notes)
  values (v_customer.id, 'WEBSITE', 'NEW', v_notes)
  returning id, number into v_request_id, v_number;

  for v_item in select * from jsonb_array_elements(v_items)
  loop
    v_position := v_position + 1;

    v_product := null;
    select p.* into v_product
      from product_web_skus s
      join products p on p.id = s.product_id
     where s.sku = nullif(trim(v_item ->> 'sku'), '');

    -- name is a snapshot, as in create_request: what the website called it
    -- wins, the catalog name is the fallback.
    v_item_name := coalesce(nullif(left(trim(v_item ->> 'name'), 120), ''),
                            v_product.name, 'Unspecified');

    -- Checked as text first: a cast that fails would surface a raw Postgres
    -- error to a visitor.
    v_quantity := coalesce(nullif(trim(v_item ->> 'quantity'), ''), '1');
    if v_quantity !~ '^[0-9]{1,9}(\.[0-9]{1,2})?$' or v_quantity::numeric <= 0 then
      raise exception 'Item %: the quantity must be a number above zero.', v_position;
    end if;

    insert into request_items (request_id, product_id, name, quantity, unit,
                               specs, position)
    values (v_request_id,
            v_product.id,
            v_item_name,
            v_quantity::numeric,
            coalesce(nullif(left(trim(v_item ->> 'unit'), 20), ''),
                     v_product.default_unit),
            nullif(left(trim(v_item ->> 'specs'), 2000), ''),
            v_position);
  end loop;

  -- the website is the customer speaking, not an employee
  update activities set actor_kind = 'CUSTOMER' where request_id = v_request_id;

  return v_number;
end;
$$;
