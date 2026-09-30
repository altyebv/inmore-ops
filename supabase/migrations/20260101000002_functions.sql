-- =============================================================================
-- 002 — Functions and triggers
--
-- All state-change events are logged here, in the database, not by the client.
-- Flutter talks to Postgres directly, so a client-written log would have holes
-- (a crash, a second client, a manual SQL fix) and every duration metric built
-- on it later would be wrong.  See docs/blueprint.md §C.
--
-- NOTE ON ORDERING: the blueprint listed RLS as 002 and triggers as 003.  They
-- are swapped here because the RLS policies call current_role_name(), which is
-- defined in this file.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- current_employee_id(), current_role_name(), can_see_money() and
-- is_supervisor_or_owner() are defined in 001 — the views there depend on them.

-- -----------------------------------------------------------------------------
-- Activity logging
--
-- Amounts belong ONLY in quotation.*, payment.* and task_cost.* events.
-- request.* and task.* events are readable by every employee (§E), so a price
-- smuggled into one is a silent leak no policy will catch.
-- -----------------------------------------------------------------------------
create or replace function log_activity(
  p_entity_type text,
  p_entity_id   uuid,
  p_request_id  uuid,
  p_event_type  text,
  p_from        text    default null,
  p_to          text    default null,
  p_metadata    jsonb   default '{}'::jsonb
) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := (select id from employees where id = auth.uid());
begin
  insert into activities (actor_kind, actor_id, entity_type, entity_id,
                          request_id, event_type, from_value, to_value, metadata)
  values ((case when v_actor is null then 'SYSTEM' else 'EMPLOYEE' end)::actor_kind,
          v_actor, p_entity_type, p_entity_id, p_request_id,
          p_event_type, p_from, p_to, coalesce(p_metadata, '{}'::jsonb));
end;
$$;

-- -----------------------------------------------------------------------------
-- auth.users -> employees
-- A user can never exist without a profile.  Created inactive; the owner
-- activates the account and sets the real role.
-- -----------------------------------------------------------------------------
create or replace function handle_new_auth_user() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.employees (id, full_name, email, role, is_active)
  values (new.id,
          coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''),
                   split_part(new.email, '@', 1)),
          new.email,
          'SUPERVISOR',
          false)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_auth_user();

-- =============================================================================
-- requests
-- =============================================================================

create or replace function requests_set_timestamps() returns trigger
language plpgsql as $$
begin
  -- keep the completed_at / cancelled_at check constraints satisfied
  new.completed_at := case when new.status = 'COMPLETED'
                           then coalesce(new.completed_at, now()) end;
  new.cancelled_at := case when new.status = 'CANCELLED'
                           then coalesce(new.cancelled_at, now()) end;
  return new;
end;
$$;

create or replace function requests_audit() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    perform log_activity('request', new.id, new.id, 'request.created',
                         null, new.status::text,
                         jsonb_build_object('customer_id', new.customer_id,
                                            'source', new.source,
                                            'number', new.number));
    return null;
  end if;

  if new.status is distinct from old.status then
    perform log_activity('request', new.id, new.id, 'request.status_changed',
                         old.status::text, new.status::text);

    if new.status = 'COMPLETED' then
      perform log_activity('request', new.id, new.id, 'request.completed',
                           old.status::text, null);
    elsif new.status = 'CANCELLED' then
      perform log_activity('request', new.id, new.id, 'request.cancelled',
                           old.status::text, null,
                           jsonb_build_object('reason', new.cancel_reason));
    elsif old.status in ('COMPLETED','CANCELLED') then
      perform log_activity('request', new.id, new.id, 'request.reopened',
                           old.status::text, new.status::text);
    end if;
  end if;

  if new.waiting_on is distinct from old.waiting_on then
    if new.waiting_on is null then
      perform log_activity('request', new.id, new.id, 'request.waiting_cleared',
                           old.waiting_on::text, null);
    else
      perform log_activity('request', new.id, new.id, 'request.waiting_set',
                           old.waiting_on::text, new.waiting_on::text);
    end if;
  end if;

  if new.supervisor_id is distinct from old.supervisor_id then
    perform log_activity('request', new.id, new.id, 'request.supervisor_changed',
                         old.supervisor_id::text, new.supervisor_id::text);
  end if;

  return null;
end;
$$;

-- DESIGNER / PRODUCTION may move a job along but may not edit it.
-- Enforced here, NOT with GRANT UPDATE (col,...): in Supabase every signed-in
-- user shares the single `authenticated` role, so column privileges cannot tell
-- an OWNER from a DESIGNER.
create or replace function requests_restrict_columns() returns trigger
language plpgsql as $$
begin
  -- null auth.uid() means service role / seed / psql: an admin path, not a user.
  if auth.uid() is not null and current_role_name() in ('DESIGNER','PRODUCTION') then
    if (new.customer_id,  new.supervisor_id, new.source,    new.title,
        new.notes,        new.needed_by,     new.cancel_reason, new.number)
    is distinct from
       (old.customer_id,  old.supervisor_id, old.source,    old.title,
        old.notes,        old.needed_by,     old.cancel_reason, old.number)
    then
      raise exception
        'Your role may change only the status and waiting state of a request.'
        using errcode = 'insufficient_privilege';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_requests_timestamps
  before insert or update on requests
  for each row execute function requests_set_timestamps();

create trigger trg_requests_restrict_columns
  before update on requests
  for each row execute function requests_restrict_columns();

create trigger trg_requests_touch
  before update on requests
  for each row execute function touch_updated_at();

create trigger trg_requests_audit
  after insert or update on requests
  for each row execute function requests_audit();

-- =============================================================================
-- request_items
-- =============================================================================

create or replace function request_items_audit() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    perform log_activity('request_item', new.id, new.request_id, 'item.added',
                         null, new.name,
                         jsonb_build_object('quantity', new.quantity,
                                            'unit', new.unit,
                                            'product_id', new.product_id));
  elsif tg_op = 'DELETE' then
    perform log_activity('request_item', old.id, old.request_id, 'item.removed',
                         old.name, null);
    return old;
  elsif new.status is distinct from old.status then
    perform log_activity('request_item', new.id, new.request_id,
                         'item.decision_changed',
                         old.status::text, new.status::text,
                         jsonb_build_object('item', new.name));
  end if;
  return null;
end;
$$;

create trigger trg_request_items_touch
  before update on request_items
  for each row execute function touch_updated_at();

create trigger trg_request_items_audit
  after insert or update or delete on request_items
  for each row execute function request_items_audit();

-- =============================================================================
-- quotations
-- =============================================================================

-- Totals are computed and stored server-side: a quotation is a historical offer
-- and must not shift when a price or quantity changes later.  No client ever
-- computes money.
create or replace function quotation_recalc_totals(p_quotation_id uuid) returns void
language plpgsql as $$
begin
  update quotations q
     set subtotal = coalesce(l.sum_total, 0),
         total    = greatest(coalesce(l.sum_total, 0) - q.discount, 0)
    from (select coalesce(sum(line_total), 0) as sum_total
            from quotation_lines where quotation_id = p_quotation_id) l
   where q.id = p_quotation_id;
end;
$$;

create or replace function quotation_lines_totals() returns trigger
language plpgsql as $$
begin
  perform quotation_recalc_totals(coalesce(new.quotation_id, old.quotation_id));
  return null;
end;
$$;

create or replace function quotations_apply_discount() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.discount is distinct from old.discount then
    new.total := greatest(new.subtotal - new.discount, 0);
  end if;
  return new;
end;
$$;

-- The invariant the request total depends on: an item may be covered by at most
-- one APPROVED quotation at a time.  Without it, two approved quotations over
-- the same item double-count in v_request_financials.
create or replace function quotations_no_overlap() returns trigger
language plpgsql as $$
declare
  v_conflict text;
begin
  if new.status = 'APPROVED' and old.status is distinct from 'APPROVED' then
    select string_agg(distinct ri.name, ', ')
      into v_conflict
      from quotation_lines ql
      join request_items ri on ri.id = ql.request_item_id
     where ql.quotation_id = new.id
       and exists (select 1
                     from quotation_lines ql2
                     join quotations q2 on q2.id = ql2.quotation_id
                    where ql2.request_item_id = ql.request_item_id
                      and q2.id <> new.id
                      and q2.status = 'APPROVED');
    if v_conflict is not null then
      raise exception
        'Cannot approve: % already covered by another approved quotation. Supersede or reject that one first.',
        v_conflict using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;

create or replace function quotations_set_timestamps() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if new.status = 'PRESENTED' then
      new.presented_at := coalesce(new.presented_at, now());
    elsif new.status in ('APPROVED','REJECTED') then
      new.decided_at := coalesce(new.decided_at, now());
    end if;
  end if;
  return new;
end;
$$;

create or replace function quotations_audit() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    perform log_activity('quotation', new.id, new.request_id, 'quotation.created',
                         null, new.version::text);
    return null;
  end if;

  if new.status is distinct from old.status then
    perform log_activity('quotation', new.id, new.request_id,
                         'quotation.' || lower(new.status::text),
                         old.status::text, new.status::text,
                         jsonb_build_object('version', new.version,
                                            'total', new.total,
                                            'currency', new.currency));

    -- approving a quotation records the customer's decision on its items
    if new.status = 'APPROVED' then
      update request_items ri
         set status = 'APPROVED'
        from quotation_lines ql
       where ql.quotation_id = new.id
         and ri.id = ql.request_item_id
         and ri.status <> 'APPROVED';
    elsif new.status = 'REJECTED' then
      update request_items ri
         set status = 'REJECTED'
        from quotation_lines ql
       where ql.quotation_id = new.id
         and ri.id = ql.request_item_id
         and ri.status = 'PENDING';
    end if;
  end if;
  return null;
end;
$$;

create trigger trg_quotations_no_overlap
  before update on quotations
  for each row execute function quotations_no_overlap();

create trigger trg_quotations_timestamps
  before update on quotations
  for each row execute function quotations_set_timestamps();

create trigger trg_quotations_discount
  before update on quotations
  for each row execute function quotations_apply_discount();

create trigger trg_quotations_touch
  before update on quotations
  for each row execute function touch_updated_at();

create trigger trg_quotations_audit
  after insert or update on quotations
  for each row execute function quotations_audit();

create trigger trg_quotation_lines_totals
  after insert or update or delete on quotation_lines
  for each row execute function quotation_lines_totals();

-- =============================================================================
-- tasks
-- =============================================================================

create or replace function tasks_set_timestamps() returns trigger
language plpgsql as $$
begin
  if new.status = 'IN_PROGRESS' then
    new.started_at := coalesce(new.started_at, now());
  end if;
  new.completed_at := case when new.status = 'DONE'
                           then coalesce(new.completed_at, now()) end;
  return new;
end;
$$;

create or replace function tasks_audit() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    perform log_activity('task', new.id, new.request_id, 'task.created',
                         null, new.title,
                         jsonb_build_object('type', new.type));
    if new.assignee_id is not null then
      perform log_activity('task', new.id, new.request_id, 'task.assigned',
                           null, new.assignee_id::text);
    elsif new.partner_id is not null then
      perform log_activity('task', new.id, new.request_id, 'task.partner_assigned',
                           null, new.partner_id::text);
    end if;
    return null;
  end if;

  if new.assignee_id is distinct from old.assignee_id then
    perform log_activity('task', new.id, new.request_id, 'task.assigned',
                         old.assignee_id::text, new.assignee_id::text);
  end if;
  if new.partner_id is distinct from old.partner_id then
    perform log_activity('task', new.id, new.request_id, 'task.partner_assigned',
                         old.partner_id::text, new.partner_id::text);
  end if;
  if new.status is distinct from old.status then
    perform log_activity('task', new.id, new.request_id, 'task.status_changed',
                         old.status::text, new.status::text);
    if new.status = 'DONE' then
      perform log_activity('task', new.id, new.request_id, 'task.completed',
                           old.status::text, null);
    end if;
  end if;
  return null;
end;
$$;

-- Work is handed over verbally, so anyone may create a task for themselves.
-- Updating someone else's task, or editing anything beyond your own progress,
-- is for supervisors and the owner.
create or replace function tasks_restrict_columns() returns trigger
language plpgsql as $$
begin
  -- auth.uid() is null for the service role, seeds and psql: those are admin
  -- paths and are not subject to the in-app role guards.
  if auth.uid() is not null and not is_supervisor_or_owner() then
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

create trigger trg_tasks_restrict_columns
  before update on tasks
  for each row execute function tasks_restrict_columns();

create trigger trg_tasks_timestamps
  before insert or update on tasks
  for each row execute function tasks_set_timestamps();

create trigger trg_tasks_touch
  before update on tasks
  for each row execute function touch_updated_at();

create trigger trg_tasks_audit
  after insert or update on tasks
  for each row execute function tasks_audit();

-- =============================================================================
-- task_costs / payments  (money-bearing events)
-- =============================================================================

create or replace function task_costs_audit() returns trigger
language plpgsql as $$
declare
  v_request_id uuid := (select request_id from tasks where id = new.task_id);
begin
  perform log_activity('task_cost', new.task_id, v_request_id, 'task_cost.recorded',
                       null, null,
                       jsonb_build_object('amount', new.amount,
                                          'currency', new.currency));
  return null;
end;
$$;

create trigger trg_task_costs_touch
  before update on task_costs
  for each row execute function touch_updated_at();

create trigger trg_task_costs_audit
  after insert or update on task_costs
  for each row execute function task_costs_audit();

create or replace function payments_audit() returns trigger
language plpgsql as $$
begin
  perform log_activity('payment', new.id, new.request_id, 'payment.recorded',
                       null, null,
                       jsonb_build_object('amount', new.amount,
                                          'currency', new.currency,
                                          'method', new.method,
                                          'kind', new.kind));
  return null;
end;
$$;

create trigger trg_payments_audit
  after insert on payments
  for each row execute function payments_audit();

-- =============================================================================
-- customers / employees
-- =============================================================================

create or replace function customers_audit() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    perform log_activity('customer', new.id, null, 'customer.created', null, new.name);
  else
    perform log_activity('customer', new.id, null, 'customer.updated', old.name, new.name);
  end if;
  return null;
end;
$$;

create trigger trg_customers_touch
  before update on customers
  for each row execute function touch_updated_at();

create trigger trg_customers_audit
  after insert or update on customers
  for each row execute function customers_audit();

create or replace function employees_restrict_role() returns trigger
language plpgsql as $$
begin
  if (new.role, new.is_active) is distinct from (old.role, old.is_active)
     and auth.uid() is not null
     and current_role_name() is distinct from 'OWNER' then
    raise exception 'Only the owner may change a role or activate an account.'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

create trigger trg_employees_restrict_role
  before update on employees
  for each row execute function employees_restrict_role();

create trigger trg_employees_touch
  before update on employees
  for each row execute function touch_updated_at();

create trigger trg_partners_touch
  before update on partners
  for each row execute function touch_updated_at();

-- =============================================================================
-- The website's only write path
--
-- The React site gets no table privileges.  One narrow, auditable RPC instead.
-- Abuse protection (honeypot + rate limit) is a later one-file change here.
-- =============================================================================
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
  if coalesce(trim(p_phone), '') = '' then
    raise exception 'A phone number is required.';
  end if;

  select id into v_customer_id
    from customers
   where phone = trim(p_phone)
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
            coalesce((v_item ->> 'quantity')::numeric, 1),
            nullif(trim(v_item ->> 'unit'), ''),
            nullif(trim(v_item ->> 'specs'), ''),
            v_position);
  end loop;

  -- the website is the customer speaking, not an employee
  update activities
     set actor_kind = 'CUSTOMER'
   where request_id = v_request_id;

  return v_number;
end;
$$;
