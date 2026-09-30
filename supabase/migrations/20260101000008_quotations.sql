-- =============================================================================
-- 008 — Quotation creation and revision  (slice step 4)
--
-- Inmore's quotations are verbal: nothing is emailed, nothing is signed. What
-- the system records is the operational fact - what was priced, what was told
-- to the customer, and what they said back.
--
-- A revision is never an edit. It is a new version, and the old one becomes
-- SUPERSEDED, so "the price changed twice before they agreed" stays answerable.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- create_quotation
--
-- Lines are [{request_item_id, unit_price, quantity?, description?}].
-- quantity defaults to the quantity already on the request item, because
-- retyping it is how the two drift apart.
-- -----------------------------------------------------------------------------
create or replace function create_quotation(
  p_request_id  uuid,
  p_lines       jsonb,
  p_discount    numeric default 0,
  p_valid_until date default null,
  p_notes       text default null
) returns quotations
language plpgsql as $$
declare
  v_me    uuid := current_employee_id();
  v_quote quotations;
  v_line  jsonb;
  v_item  request_items;
begin
  if not can_see_money() then
    raise exception 'Only a supervisor or the owner may price work.'
      using errcode = 'insufficient_privilege';
  end if;
  if jsonb_array_length(coalesce(p_lines, '[]'::jsonb)) = 0 then
    raise exception 'A quotation needs at least one line.';
  end if;

  insert into quotations (request_id, version, discount, valid_until, notes, created_by)
  values (
    p_request_id,
    coalesce((select max(version) from quotations where request_id = p_request_id), 0) + 1,
    coalesce(p_discount, 0),
    p_valid_until,
    nullif(trim(coalesce(p_notes, '')), ''),
    v_me
  )
  returning * into v_quote;

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    select * into v_item
      from request_items
     where id = (v_line ->> 'request_item_id')::uuid;

    if v_item.id is null then
      raise exception 'Unknown request item on a quotation line.';
    end if;
    -- The unique constraint stops the same item appearing twice on one
    -- quotation; nothing else stops it belonging to a different request.
    if v_item.request_id <> p_request_id then
      raise exception 'Item "%" belongs to a different request.', v_item.name;
    end if;

    insert into quotation_lines (quotation_id, request_item_id, description,
                                 quantity, unit_price)
    values (
      v_quote.id,
      v_item.id,
      nullif(trim(coalesce(v_line ->> 'description', '')), ''),
      coalesce(nullif(v_line ->> 'quantity', '')::numeric, v_item.quantity),
      (v_line ->> 'unit_price')::numeric
    );
  end loop;

  -- re-read: subtotal and total are computed by trigger as the lines land
  select * into v_quote from quotations where id = v_quote.id;
  return v_quote;
end;
$$;

-- -----------------------------------------------------------------------------
-- revise_quotation
--
-- Supersedes the current version and issues the next one. Passing p_lines null
-- copies the existing lines, which is what you want when only the discount or
-- the validity changes.
-- -----------------------------------------------------------------------------
create or replace function revise_quotation(
  p_quotation_id uuid,
  p_lines        jsonb default null,
  p_discount     numeric default null,
  p_valid_until  date default null,
  p_notes        text default null
) returns quotations
language plpgsql as $$
declare
  v_old   quotations;
  v_new   quotations;
  v_lines jsonb;
begin
  if not can_see_money() then
    raise exception 'Only a supervisor or the owner may price work.'
      using errcode = 'insufficient_privilege';
  end if;

  select * into v_old from quotations where id = p_quotation_id;
  if v_old.id is null then
    raise exception 'Quotation not found.';
  end if;
  if v_old.status = 'DRAFT' then
    raise exception
      'This quotation is still a draft - edit its lines instead of revising it.';
  end if;
  if v_old.status = 'SUPERSEDED' then
    raise exception 'That version has already been superseded.';
  end if;

  v_lines := coalesce(
    p_lines,
    (select jsonb_agg(jsonb_build_object(
              'request_item_id', ql.request_item_id,
              'quantity',        ql.quantity,
              'unit_price',      ql.unit_price,
              'description',     ql.description))
       from quotation_lines ql
      where ql.quotation_id = v_old.id)
  );

  -- Order matters: supersede first, so the no-overlap check does not see the
  -- old approved version as a conflict when the new one is approved.
  update quotations set status = 'SUPERSEDED' where id = v_old.id;

  v_new := create_quotation(
    p_request_id  := v_old.request_id,
    p_lines       := v_lines,
    p_discount    := coalesce(p_discount, v_old.discount),
    p_valid_until := coalesce(p_valid_until, v_old.valid_until),
    p_notes       := coalesce(p_notes, v_old.notes)
  );

  return v_new;
end;
$$;

grant execute on function create_quotation(uuid, jsonb, numeric, date, text)
  to authenticated;
grant execute on function revise_quotation(uuid, jsonb, numeric, date, text)
  to authenticated;
