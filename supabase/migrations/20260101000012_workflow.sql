-- =============================================================================
-- Workflow gaps found walking a request end to end before go-live.
--
-- 1. Closing a request closes its open work.
-- 2. remove_request_item(): a priced product is cancelled, not deleted.
-- 3. edit_draft_quotation(): a draft can be corrected before anyone hears it.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Closing a request closes its open work
--
-- A request completed or cancelled with tasks still open left them in someone's
-- My Work for good, and in the owner's late counts. They are cancelled along
-- with it — not marked done, because nobody said they were — and each one is
-- logged as an ordinary task.status_changed event by trg_tasks_audit.
--
-- The person closing the request usually doesn't own those tasks, so this runs
-- as definer, and raises a transaction-local flag that tasks_restrict_columns
-- reads as "the database is doing this, not a user editing someone's task".
-- -----------------------------------------------------------------------------
create or replace function requests_close_open_tasks() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.status in ('COMPLETED','CANCELLED')
     and old.status not in ('COMPLETED','CANCELLED') then
    perform set_config('inmore.closing_request', 'on', true);
    update tasks
       set status = 'CANCELLED'
     where request_id = new.id
       and status in ('TODO','IN_PROGRESS','BLOCKED');
    perform set_config('inmore.closing_request', 'off', true);
  end if;
  return null;
end;
$$;

-- Fires after trg_requests_audit (triggers run in name order), so the history
-- reads "Request completed", then the work it closed.
create trigger trg_requests_close_open_tasks
  after update of status on requests
  for each row execute function requests_close_open_tasks();

-- Same rules as before (002), plus the closing-request exemption above.
create or replace function tasks_restrict_columns() returns trigger
language plpgsql as $$
begin
  -- auth.uid() is null for the service role, seeds and psql: those are admin
  -- paths and are not subject to the in-app role guards.
  if auth.uid() is not null
     and not is_supervisor_or_owner()
     and coalesce(current_setting('inmore.closing_request', true), 'off') <> 'on'
  then
    if old.assignee_id is distinct from current_employee_id() then
      raise exception 'You may only update a task assigned to you.'
        using errcode = 'insufficient_privilege';
    end if;
    if (new.request_id, new.request_item_id, new.type, new.title, new.description,
        new.assignee_id, new.partner_id, new.due_at)
    is distinct from
       (old.request_id, old.request_item_id, old.type, old.title, old.description,
        old.assignee_id, old.partner_id, old.due_at)
    then
      raise exception
        'Your role may change only the status, notes and timing of your own task.'
        using errcode = 'insufficient_privilege';
    end if;
  end if;
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 2. remove_request_item
--
-- quotation_lines.request_item_id is `on delete restrict`, rightly: a quotation
-- the customer heard must keep saying what it priced. So deleting a priced
-- product failed outright. A product that appears on any quotation is now
-- marked CANCELLED instead (logged as item.decision_changed); one that was
-- never priced is deleted as before (logged as item.removed).
--
-- Security invoker: RLS decides who may do either, and a refusal is raised
-- rather than passing silently as zero rows.
-- -----------------------------------------------------------------------------
create or replace function remove_request_item(p_item_id uuid) returns text
language plpgsql as $$
declare
  v_rows int;
begin
  if not exists (select 1 from request_items where id = p_item_id) then
    raise exception 'That product no longer exists.' using errcode = 'P0002';
  end if;

  if exists (select 1 from quotation_lines where request_item_id = p_item_id) then
    update request_items set status = 'CANCELLED' where id = p_item_id;
    get diagnostics v_rows = row_count;
    if v_rows = 0 then
      raise exception 'Your role may not remove products.'
        using errcode = 'insufficient_privilege';
    end if;
    return 'CANCELLED';
  end if;

  delete from request_items where id = p_item_id;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    raise exception 'Your role may not remove products.'
      using errcode = 'insufficient_privilege';
  end if;
  return 'DELETED';
end;
$$;

grant execute on function remove_request_item(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. edit_draft_quotation
--
-- revise_quotation refuses a draft ("edit its lines instead"), and RLS already
-- lets a draft's lines change — but replacing them from the client is several
-- statements, and a failure halfway leaves a half-priced draft. This does it
-- in one: same line rules as create_quotation, then the discount.
--
-- Nothing is logged: a draft has not been told to anyone, so changing it is
-- not part of the negotiation's history. PRESENTED is where history starts.
-- -----------------------------------------------------------------------------
create or replace function edit_draft_quotation(
  p_quotation_id uuid,
  p_lines        jsonb,
  p_discount     numeric default 0
) returns quotations
language plpgsql as $$
declare
  v_quote quotations;
  v_line  jsonb;
  v_item  request_items;
begin
  if not can_see_money() then
    raise exception 'Only a supervisor or the owner may price work.'
      using errcode = 'insufficient_privilege';
  end if;

  select * into v_quote from quotations where id = p_quotation_id;
  if v_quote.id is null then
    raise exception 'Quotation not found.' using errcode = 'P0002';
  end if;
  if v_quote.status <> 'DRAFT' then
    raise exception
      'Only a draft can be edited. Once told to the customer, revise it instead.';
  end if;
  if jsonb_array_length(coalesce(p_lines, '[]'::jsonb)) = 0 then
    raise exception 'A quotation needs at least one line.';
  end if;

  delete from quotation_lines where quotation_id = v_quote.id;

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    select * into v_item
      from request_items
     where id = (v_line ->> 'request_item_id')::uuid;

    if v_item.id is null then
      raise exception 'Unknown request item on a quotation line.';
    end if;
    if v_item.request_id <> v_quote.request_id then
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

  -- After the lines: quotations_apply_discount recomputes the total from the
  -- new subtotal.
  update quotations set discount = coalesce(p_discount, 0) where id = v_quote.id;

  select * into v_quote from quotations where id = v_quote.id;
  return v_quote;
end;
$$;

grant execute on function edit_draft_quotation(uuid, jsonb, numeric)
  to authenticated;

-- -----------------------------------------------------------------------------
-- 4. v_request_summary: notes and cancel reason, and a true open-task count
--
-- The notes taken when a request is created ("what the customer actually
-- said") were stored but never reached a screen, and the reason a request was
-- cancelled was only readable in the history. Both are appended (a replaced
-- view may only add columns at the end).
--
-- open_task_count counted everything not DONE, so cancelled work — which
-- closing a request now produces — counted as open.
-- -----------------------------------------------------------------------------
create or replace view v_request_summary with (security_invoker = on) as
select r.id, r.number, r.status, r.waiting_on, r.source, r.title, r.needed_by,
       r.created_at, r.updated_at, r.completed_at, r.cancelled_at,
       r.customer_id, c.name as customer_name, c.phone as customer_phone,
       c.company as customer_company,
       r.supervisor_id, e.full_name as supervisor_name,
       (select count(*) from request_items i where i.request_id = r.id)  as item_count,
       (select count(*) from tasks t
         where t.request_id = r.id
           and t.status in ('TODO','IN_PROGRESS','BLOCKED'))             as open_task_count,
       r.notes,
       r.cancel_reason
from requests r
join customers c on c.id = r.customer_id
left join employees e on e.id = r.supervisor_id;
