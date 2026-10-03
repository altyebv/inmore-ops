-- =============================================================================
-- Back office test  (migration 013)
--
--   docker exec -i supabase_db_inmore-ops psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 -q < supabase/tests/back_office_test.sql
--
-- Staff: supervisors manage everyone but the owner, nobody changes their own
-- access. Inventory: the quantity is the ledger, it can't go below zero,
-- production records in/out but not counts, cost is money. Expenses: money,
-- corrected by editing or voiding with a reason, every step logged.
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

-- Act as a seed account for the rest of the transaction.
create or replace function _as(p_id uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text,
                    true);
$$;

begin;
set local role authenticated;

do $$
declare
  c_owner    constant uuid := '11111111-1111-1111-1111-111111111111';
  c_ahmed    constant uuid := '22222222-2222-2222-2222-222222222222';  -- supervisor
  c_fatima   constant uuid := '33333333-3333-3333-3333-333333333333';  -- supervisor
  c_sara     constant uuid := '44444444-4444-4444-4444-444444444444';  -- designer
  c_layla    constant uuid := '55555555-5555-5555-5555-555555555555';  -- designer
  c_mohammed constant uuid := '66666666-6666-6666-6666-666666666666';  -- production
  v_n        int;
  v_item     uuid;
  v_expense  uuid;
  v_raised   boolean;
begin
  -- ---------------------------------------------------------------------------
  raise notice 'Staff management:';
  perform _as(c_ahmed);

  update employees set role = 'PRODUCTION' where id = c_layla;
  perform _assert((select role from employees where id = c_layla) = 'PRODUCTION',
                  'a supervisor changes a designer''s role');
  perform _assert(exists (select 1 from activities
                           where entity_id = c_layla and event_type = 'employee.role_changed'
                             and actor_id = c_ahmed and to_value = 'PRODUCTION'),
                  'the change is in the history, with who did it');

  update employees set is_active = false where id = c_layla;
  perform _assert(not (select is_active from employees where id = c_layla),
                  'a supervisor removes someone''s access');
  perform _assert(exists (select 1 from activities
                           where entity_id = c_layla and event_type = 'employee.deactivated'),
                  'removing access is logged');
  update employees set is_active = true, role = 'DESIGNER' where id = c_layla;

  update employees set is_active = false where id = c_owner;
  get diagnostics v_n = row_count;
  perform _assert(v_n = 0, 'a supervisor can''t touch the owner''s account');

  begin
    update employees set role = 'OWNER' where id = c_fatima;
    v_raised := false;
  exception when insufficient_privilege then v_raised := true;
  end;
  perform _assert(v_raised, 'a supervisor can''t make anyone an owner');

  begin
    update employees set is_active = false where id = c_ahmed;
    v_raised := false;
  exception when insufficient_privilege then v_raised := true;
  end;
  perform _assert(v_raised, 'nobody switches off their own account');

  begin
    update employees set email = 'other@inmore.local' where id = c_sara;
    v_raised := false;
  exception when insufficient_privilege then v_raised := true;
  end;
  perform _assert(v_raised, 'an email (the sign-in name) can''t be changed here');

  update employees set full_name = 'Sara H.' where id = c_sara;
  perform _assert((select full_name from employees where id = c_sara) = 'Sara H.',
                  'a supervisor can correct a name');

  perform _as(c_sara);
  update employees set role = 'SUPERVISOR' where id = c_layla;
  get diagnostics v_n = row_count;
  perform _assert(v_n = 0, 'a designer can''t change someone else''s account');
  begin
    update employees set role = 'SUPERVISOR' where id = c_sara;
    v_raised := false;
  exception when insufficient_privilege then v_raised := true;
  end;
  perform _assert(v_raised, 'a designer can''t promote themselves');

  perform _as(c_owner);
  update employees set role = 'DESIGNER' where id = c_fatima;
  perform _assert((select role from employees where id = c_fatima) = 'DESIGNER',
                  'the owner can change a supervisor''s role');
  update employees set role = 'SUPERVISOR' where id = c_fatima;

  -- ---------------------------------------------------------------------------
  raise notice 'Business details:';
  perform _as(c_sara);
  perform _assert((select name from business_profile) = 'Inmore', 'everyone can read the letterhead');
  update business_profile set phone = '+974 0000 0000';
  get diagnostics v_n = row_count;
  perform _assert(v_n = 0, 'a designer can''t change it');
  perform _as(c_ahmed);
  update business_profile set phone = '+974 4444 1234';
  perform _assert((select phone from business_profile) = '+974 4444 1234',
                  'a supervisor can');

  -- ---------------------------------------------------------------------------
  raise notice 'Inventory:';
  perform _as(c_sara);
  begin
    insert into inventory_items (name, unit) values ('Designer stock', 'pcs');
    v_raised := false;
  exception when insufficient_privilege then v_raised := true;
  end;
  perform _assert(v_raised, 'a designer can''t add stock items');

  perform _as(c_ahmed);
  insert into inventory_items (name, unit, reorder_level)
  values ('Kraft paper roll', 'rolls', 5) returning id into v_item;
  perform _assert((select created_by from inventory_items where id = v_item) = c_ahmed,
                  'who added it is stamped');
  perform _assert((select on_hand from v_inventory where id = v_item) = 0,
                  'a new item starts at zero');

  perform _as(c_mohammed);
  insert into stock_movements (item_id, kind, quantity) values (v_item, 'IN', 10);
  insert into stock_movements (item_id, kind, quantity, note) values (v_item, 'OUT', -3, 'cups job');
  perform _assert((select on_hand from v_inventory where id = v_item) = 7,
                  'production records in and out; on hand is the sum');
  perform _assert((select recorded_by from stock_movements where item_id = v_item and kind = 'OUT')
                  = c_mohammed, 'who took it out is stamped');

  begin
    insert into stock_movements (item_id, kind, quantity) values (v_item, 'OUT', -8);
    v_raised := false;
  exception when check_violation then v_raised := true;
  end;
  perform _assert(v_raised, 'stock can''t go below zero');

  begin
    insert into stock_movements (item_id, kind, quantity) values (v_item, 'IN', -2);
    v_raised := false;
  exception when check_violation then v_raised := true;
  end;
  perform _assert(v_raised, 'a receipt can''t be negative');

  begin
    insert into stock_movements (item_id, kind, quantity) values (v_item, 'ADJUST', -2);
    v_raised := false;
  exception when insufficient_privilege then v_raised := true;
  end;
  perform _assert(v_raised, 'production can''t record a stock count');

  begin
    update stock_movements set quantity = 100 where item_id = v_item;
    v_raised := false;
  exception when insufficient_privilege then v_raised := true;
  end;
  perform _assert(v_raised, 'a movement can''t be edited');

  perform _as(c_ahmed);
  insert into stock_movements (item_id, kind, quantity, note) values (v_item, 'ADJUST', -2, 'counted 5');
  perform _assert((select on_hand from v_inventory where id = v_item) = 5,
                  'a supervisor''s stock count corrects the figure');
  perform _assert((select is_low from v_inventory where id = v_item),
                  'at its reorder level, it shows as low');

  insert into inventory_item_costs (item_id, unit_cost) values (v_item, 42.50);
  perform _assert((select unit_cost from inventory_item_costs where item_id = v_item) = 42.50,
                  'a supervisor sets the unit cost');

  perform _as(c_sara);
  perform _assert((select count(*) from v_inventory where id = v_item) = 1,
                  'a designer sees the item');
  perform _assert((select count(*) from inventory_item_costs) = 0,
                  'but not what it costs');

  -- ---------------------------------------------------------------------------
  raise notice 'Expenses:';
  perform _as(c_ahmed);
  insert into expenses (spent_on, category, amount, method, is_monthly, paid_to)
  values (current_date, 'Rent', 12000, 'BANK_TRANSFER', true, 'Landlord')
  returning id into v_expense;
  perform _assert((select recorded_by from expenses where id = v_expense) = c_ahmed,
                  'who recorded it is stamped');

  update expenses set amount = 11500 where id = v_expense;
  perform _assert(exists (select 1 from activities
                           where entity_id = v_expense and event_type = 'expense.updated'
                             and from_value = '12000.00' and to_value = '11500.00'),
                  'a correction is logged with the old and new amount');

  begin
    update expenses set voided_at = now() where id = v_expense;
    v_raised := false;
  exception when check_violation then v_raised := true;
  end;
  perform _assert(v_raised, 'voiding needs a reason');

  update expenses set voided_at = now(), void_reason = 'entered twice' where id = v_expense;
  perform _assert((select voided_by from expenses where id = v_expense) = c_ahmed,
                  'who voided it is stamped');
  begin
    update expenses set amount = 1 where id = v_expense;
    v_raised := false;
  exception when check_violation then v_raised := true;
  end;
  perform _assert(v_raised, 'a voided expense can''t be changed');

  begin
    delete from expenses where id = v_expense;
    v_raised := false;
  exception when insufficient_privilege then v_raised := true;
  end;
  perform _assert(v_raised, 'an expense can''t be deleted');

  perform _as(c_sara);
  perform _assert((select count(*) from expenses) = 0, 'a designer sees no expenses');
  perform _assert((select count(*) from activities where entity_type = 'expense') = 0,
                  'nor their history');
  perform _assert((select count(*) from v_report_payments) = 0,
                  'nor the payments report');
  begin
    insert into expenses (category, amount) values ('Sneaky', 1);
    v_raised := false;
  exception when insufficient_privilege then v_raised := true;
  end;
  perform _assert(v_raised, 'and can''t record one');

  perform _as(c_mohammed);
  perform _assert((select count(*) from expenses) = 0, 'production sees no expenses either');

  perform _as(c_owner);
  perform _assert((select count(*) from activities where entity_type = 'expense') >= 3,
                  'the owner sees every expense event');
end;
$$;

rollback;
