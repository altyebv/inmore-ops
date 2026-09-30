-- =============================================================================
-- 003 — Row Level Security
--
-- Six-person company: operational reads are wide (hiding a colleague's request
-- would defeat the point of V1), money reads are closed, writes are narrow.
--
-- MONEY IS READABLE BY OWNER AND SUPERVISOR ONLY.  Drawn at the table level,
-- not the column level, because in Supabase every signed-in user shares the one
-- `authenticated` Postgres role - column privileges cannot tell an OWNER from a
-- DESIGNER.  See docs/blueprint.md §E.
-- =============================================================================

alter table employees       enable row level security;
alter table customers       enable row level security;
alter table products        enable row level security;
alter table partners        enable row level security;
alter table requests        enable row level security;
alter table request_items   enable row level security;
alter table quotations      enable row level security;
alter table quotation_lines enable row level security;
alter table tasks           enable row level security;
alter table task_costs      enable row level security;
alter table payments        enable row level security;
alter table activities      enable row level security;

-- -----------------------------------------------------------------------------
-- Table privileges.  RLS gates rows; these gate the verbs.
-- Note what is absent: no DELETE anywhere except tasks and quotation lines, and
-- no INSERT/UPDATE/DELETE on activities for anyone, ever.
-- -----------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
grant usage on schema public to anon, authenticated;

grant select                 on employees       to authenticated;
grant update                 on employees       to authenticated;
grant select, insert, update on customers       to authenticated;
grant select, insert, update on products        to authenticated;
grant select, insert, update on partners        to authenticated;
grant select, insert, update on requests        to authenticated;
grant select, insert, update, delete on request_items   to authenticated;
grant select, insert, update on quotations      to authenticated;
grant select, insert, update, delete on quotation_lines to authenticated;
grant select, insert, update, delete on tasks   to authenticated;
grant select, insert, update on task_costs      to authenticated;
grant select, insert         on payments        to authenticated;
grant select                 on activities      to authenticated;

grant select on v_request_summary         to authenticated;
grant select on v_request_financials      to authenticated;
grant select on v_request_stage_durations to authenticated;

grant execute on function create_public_request(text,text,text,text,text,jsonb)
  to anon, authenticated;

-- =============================================================================
-- employees
-- =============================================================================
create policy employees_select on employees for select to authenticated
  using (current_employee_id() is not null);

-- Own profile, or anyone if you are the owner.  Role and is_active are further
-- guarded by trg_employees_restrict_role.
create policy employees_update on employees for update to authenticated
  using (id = auth.uid() or current_role_name() = 'OWNER')
  with check (id = auth.uid() or current_role_name() = 'OWNER');

-- No insert policy: employees rows are created by handle_new_auth_user().

-- =============================================================================
-- customers — designers can create one, because they can create requests
-- =============================================================================
create policy customers_select on customers for select to authenticated
  using (current_employee_id() is not null);

create policy customers_insert on customers for insert to authenticated
  with check (current_role_name() in ('OWNER','SUPERVISOR','DESIGNER'));

create policy customers_update on customers for update to authenticated
  using (is_supervisor_or_owner())
  with check (is_supervisor_or_owner());

-- =============================================================================
-- products / partners
-- =============================================================================
create policy products_select on products for select to authenticated
  using (current_employee_id() is not null);

create policy products_insert on products for insert to authenticated
  with check (is_supervisor_or_owner());

create policy products_update on products for update to authenticated
  using (current_role_name() = 'OWNER')
  with check (current_role_name() = 'OWNER');

create policy partners_select on partners for select to authenticated
  using (current_employee_id() is not null);

create policy partners_insert on partners for insert to authenticated
  with check (current_role_name() in ('OWNER','SUPERVISOR','PRODUCTION'));

create policy partners_update on partners for update to authenticated
  using (current_role_name() in ('OWNER','SUPERVISOR','PRODUCTION'))
  with check (current_role_name() in ('OWNER','SUPERVISOR','PRODUCTION'));

-- =============================================================================
-- requests
-- The brief lists DESIGNER as a request source, so designers can create one.
-- DESIGNER / PRODUCTION updates are narrowed to status + waiting_on by
-- trg_requests_restrict_columns, not by column privileges.
-- =============================================================================
create policy requests_select on requests for select to authenticated
  using (current_employee_id() is not null);

create policy requests_insert on requests for insert to authenticated
  with check (current_role_name() in ('OWNER','SUPERVISOR','DESIGNER'));

create policy requests_update on requests for update to authenticated
  using (current_employee_id() is not null)
  with check (current_employee_id() is not null);

-- No delete policy: requests are cancelled, never deleted.

-- =============================================================================
-- request_items
-- =============================================================================
create policy request_items_select on request_items for select to authenticated
  using (current_employee_id() is not null);

create policy request_items_insert on request_items for insert to authenticated
  with check (current_role_name() in ('OWNER','SUPERVISOR','DESIGNER'));

create policy request_items_update on request_items for update to authenticated
  using (is_supervisor_or_owner())
  with check (is_supervisor_or_owner());

create policy request_items_delete on request_items for delete to authenticated
  using (is_supervisor_or_owner());

-- =============================================================================
-- MONEY: quotations, quotation_lines, task_costs, payments
-- OWNER + SUPERVISOR only, for reads as well as writes.
-- =============================================================================
create policy quotations_all on quotations for all to authenticated
  using (can_see_money())
  with check (can_see_money());

-- Lines are editable only while the parent is still a draft: once a quotation
-- has been told to the customer it is history, and a revision is a new version.
create policy quotation_lines_select on quotation_lines for select to authenticated
  using (can_see_money());

create policy quotation_lines_write on quotation_lines for insert to authenticated
  with check (can_see_money()
              and exists (select 1 from quotations q
                           where q.id = quotation_id and q.status = 'DRAFT'));

create policy quotation_lines_update on quotation_lines for update to authenticated
  using (can_see_money()
         and exists (select 1 from quotations q
                      where q.id = quotation_id and q.status = 'DRAFT'))
  with check (can_see_money());

create policy quotation_lines_delete on quotation_lines for delete to authenticated
  using (can_see_money()
         and exists (select 1 from quotations q
                      where q.id = quotation_id and q.status = 'DRAFT'));

create policy task_costs_all on task_costs for all to authenticated
  using (can_see_money())
  with check (can_see_money());

-- Insert only.  There is no update or delete grant on payments at all.
create policy payments_select on payments for select to authenticated
  using (can_see_money());

create policy payments_insert on payments for insert to authenticated
  with check (can_see_money());

-- =============================================================================
-- tasks
-- Anyone may create a task for themselves, because work is handed over
-- verbally and requiring supervisor pre-creation would mean tasks silently
-- stop being recorded.  trg_tasks_restrict_columns guards what they may change.
-- =============================================================================
create policy tasks_select on tasks for select to authenticated
  using (current_employee_id() is not null);

create policy tasks_insert on tasks for insert to authenticated
  with check (
    is_supervisor_or_owner()
    or (current_employee_id() is not null
        and assignee_id = current_employee_id()
        and partner_id is null)
  );

create policy tasks_update on tasks for update to authenticated
  using (is_supervisor_or_owner() or assignee_id = current_employee_id())
  with check (is_supervisor_or_owner() or assignee_id = current_employee_id());

create policy tasks_delete on tasks for delete to authenticated
  using (is_supervisor_or_owner());

-- =============================================================================
-- activities — append-only, and money-filtered on read.
--
-- payment.recorded carries the amount in metadata and quotation events carry
-- totals, so an open read policy would hand designers the money through the
-- back door.  They get a complete operational timeline with the money events
-- absent - not redacted rows, simply not present.
--
-- There is deliberately no INSERT, UPDATE or DELETE policy: rows arrive only
-- through log_activity(), which is security definer.  Corrections are new
-- events, never edits.  This is what makes the duration metrics trustworthy.
-- =============================================================================
create policy activities_select on activities for select to authenticated
  using (
    current_employee_id() is not null
    and (can_see_money()
         or entity_type not in ('quotation','payment','task_cost'))
  );
