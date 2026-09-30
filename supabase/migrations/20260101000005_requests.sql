-- =============================================================================
-- 005 — Request creation  (slice step 2)
--
-- A request and its items are created in one call, because two round trips can
-- leave a request with no items behind it if the second one fails - and an
-- empty request is exactly the kind of junk row that makes people stop trusting
-- the system.
--
-- Deliberately NOT security definer: it runs as the caller, so the RLS insert
-- policies still decide who may create a request.
-- =============================================================================

create or replace function create_request(
  p_customer_id   uuid,
  p_title         text default null,
  p_notes         text default null,
  p_needed_by     date default null,
  p_supervisor_id uuid default null,
  p_items         jsonb default '[]'::jsonb
) returns requests
language plpgsql as $$
declare
  v_me      uuid := current_employee_id();
  v_role    employee_role := current_role_name();
  v_request requests;
  v_item    jsonb;
  v_pos     int := 0;
  v_name    text;
begin
  if v_me is null then
    raise exception 'Not signed in.' using errcode = 'insufficient_privilege';
  end if;

  insert into requests (customer_id, supervisor_id, source,
                        title, notes, needed_by, created_by)
  values (
    p_customer_id,
    -- A supervisor creating a request owns it by default. An owner does not:
    -- leaving it null puts the request on the "needs a supervisor" list, which
    -- is the honest state.
    coalesce(p_supervisor_id, case when v_role = 'SUPERVISOR' then v_me end),
    case when v_role = 'DESIGNER' then 'DESIGNER'::request_source
         else 'SUPERVISOR'::request_source end,
    nullif(trim(coalesce(p_title, '')), ''),
    nullif(trim(coalesce(p_notes, '')), ''),
    p_needed_by,
    v_me
  )
  returning * into v_request;

  for v_item in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  loop
    v_pos := v_pos + 1;

    -- name is a snapshot: a catalog product supplies it, but renaming or
    -- retiring that product later must not rewrite this request.
    v_name := nullif(trim(coalesce(v_item ->> 'name', '')), '');
    if v_name is null and nullif(v_item ->> 'product_id', '') is not null then
      select p.name into v_name
        from products p where p.id = (v_item ->> 'product_id')::uuid;
    end if;
    if v_name is null then
      raise exception 'Item % needs a name or a catalog product.', v_pos;
    end if;

    insert into request_items (request_id, product_id, name, quantity, unit,
                               specs, notes, position, created_by)
    values (
      v_request.id,
      nullif(v_item ->> 'product_id', '')::uuid,
      v_name,
      coalesce(nullif(v_item ->> 'quantity', '')::numeric, 1),
      nullif(trim(coalesce(v_item ->> 'unit', '')), ''),
      nullif(trim(coalesce(v_item ->> 'specs', '')), ''),
      nullif(trim(coalesce(v_item ->> 'notes', '')), ''),
      v_pos,
      v_me
    );
  end loop;

  return v_request;
end;
$$;

grant execute on function create_request(uuid, text, text, date, uuid, jsonb)
  to authenticated;

-- -----------------------------------------------------------------------------
-- The website RPC now matches customers on the normalized phone too, so a
-- visitor typing "+974 5555 1234" lands on the record a supervisor created as
-- "55551234" instead of producing a duplicate.
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
  v_customer_id uuid;
  v_request_id  uuid;
  v_number      int;
  v_item        jsonb;
  v_position    int := 0;
begin
  if coalesce(trim(p_customer_name), '') = '' then
    raise exception 'A name is required.';
  end if;
  if normalize_phone(p_phone) is null then
    raise exception 'A phone number is required.';
  end if;

  select id into v_customer_id
    from customers
   where phone_normalized = normalize_phone(p_phone)
   order by created_at
   limit 1;

  if v_customer_id is null then
    insert into customers (name, phone, email, company)
    values (trim(p_customer_name), trim(p_phone), nullif(trim(p_email), ''),
            nullif(trim(p_company), ''))
    returning id into v_customer_id;
  end if;

  insert into requests (customer_id, source, status, notes)
  values (v_customer_id, 'WEBSITE', 'NEW', nullif(trim(p_message), ''))
  returning id, number into v_request_id, v_number;

  for v_item in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  loop
    v_position := v_position + 1;
    insert into request_items (request_id, name, quantity, unit, specs, position)
    values (v_request_id,
            coalesce(nullif(trim(v_item ->> 'name'), ''), 'Unspecified'),
            coalesce(nullif(v_item ->> 'quantity', '')::numeric, 1),
            nullif(trim(v_item ->> 'unit'), ''),
            nullif(trim(v_item ->> 'specs'), ''),
            v_position);
  end loop;

  -- the website is the customer speaking, not an employee
  update activities set actor_kind = 'CUSTOMER' where request_id = v_request_id;

  return v_number;
end;
$$;

grant execute on function create_public_request(text, text, text, text, text, jsonb)
  to anon, authenticated;
