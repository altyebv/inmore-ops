-- =============================================================================
-- Workflow gaps test  (migration 012)
--
--   docker exec -i supabase_db_inmore-ops psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 -q < supabase/tests/workflow_test.sql
--
-- Closing a request closes its open work; a priced product is cancelled, not
-- deleted; a draft quotation can be corrected, and only a draft.
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
insert into customers (name, phone) values ('Workflow Test Co.', '+974 8888 1212');

create temporary table _fx (k text primary key, v uuid) on commit drop;
grant select, insert on _fx to authenticated;

-- -----------------------------------------------------------------------------
-- As SUPERVISOR: set up a request with work and a draft price
-- -----------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_request requests;
  v_cups    uuid;
  v_bags    uuid;
  v_menu    uuid;
  v_quote   quotations;
begin
  raise notice 'Draft quotations:';

  select * into v_request from create_request(
    p_customer_id := (select id from customers where name = 'Workflow Test Co.'),
    p_title       := 'Workflow',
    p_items       := jsonb_build_array(
      jsonb_build_object('name', 'Paper Cups', 'quantity', 1000),
      jsonb_build_object('name', 'Paper Bags', 'quantity', 500),
      jsonb_build_object('name', 'Menu boards', 'quantity', 4)
    )
  );
  insert into _fx values ('request', v_request.id);
  select id into v_cups from request_items where request_id = v_request.id and position = 1;
  select id into v_bags from request_items where request_id = v_request.id and position = 2;
  select id into v_menu from request_items where request_id = v_request.id and position = 3;
  insert into _fx values ('cups', v_cups), ('bags', v_bags), ('menu', v_menu);

  v_quote := create_quotation(v_request.id, jsonb_build_array(
    jsonb_build_object('request_item_id', v_cups, 'unit_price', 1.00)));
  insert into _fx values ('quote', v_quote.id);
  perform _assert(v_quote.total = 1000, 'draft priced at 1,000');

  -- a typo, fixed before anyone heard it: new price, a second line, a discount
  v_quote := edit_draft_quotation(v_quote.id, jsonb_build_array(
    jsonb_build_object('request_item_id', v_cups, 'unit_price', 0.80),
    jsonb_build_object('request_item_id', v_bags, 'unit_price', 2.00)), 100);
  perform _assert(v_quote.version = 1, 'editing a draft keeps its version');
  perform _assert(v_quote.subtotal = 1800, 'subtotal recomputed from the new lines');
  perform _assert(v_quote.total = 1700, 'discount applied to the new subtotal');
  perform _assert((select count(*) from quotation_lines where quotation_id = v_quote.id) = 2,
                  'old lines replaced, not added to');

  update quotations set status = 'PRESENTED' where id = v_quote.id;
  begin
    perform edit_draft_quotation(v_quote.id, jsonb_build_array(
      jsonb_build_object('request_item_id', v_cups, 'unit_price', 0.50)), 0);
    perform _assert(false, 'a presented quotation cannot be edited');
  exception when raise_exception then
    perform _assert(true, 'a presented quotation cannot be edited');
  end;

  raise notice 'Removing products:';

  perform _assert(remove_request_item(v_menu) = 'DELETED',
                  'a product never priced is deleted');
  perform _assert(not exists (select 1 from request_items where id = v_menu),
                  '... and is gone');
  perform _assert(remove_request_item(v_bags) = 'CANCELLED',
                  'a priced product is cancelled instead');
  perform _assert((select status from request_items where id = v_bags) = 'CANCELLED',
                  '... and stays, marked cancelled');
  perform _assert((select count(*) from quotation_lines where request_item_id = v_bags) = 1,
                  '... so the quotation still says what it priced');
  perform _assert(exists (select 1 from activities
                           where entity_id = v_bags and event_type = 'item.decision_changed'),
                  '... and the cancellation is in the history');

  -- work on the request, for the next section
  insert into tasks (request_id, type, title, assignee_id)
  values (v_request.id, 'DESIGN', 'Cup artwork', '44444444-4444-4444-4444-444444444444');
  insert into tasks (request_id, type, title, assignee_id, status)
  values (v_request.id, 'PRODUCTION', 'Print', '66666666-6666-6666-6666-666666666666', 'DONE');
end;
$$;

-- -----------------------------------------------------------------------------
-- As DESIGNER: may not remove a product
-- -----------------------------------------------------------------------------
reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
begin
  raise notice 'As DESIGNER:';
  begin
    perform remove_request_item((select v from _fx where k = 'cups'));
    perform _assert(false, 'a designer cannot remove a product');
  exception when insufficient_privilege then
    perform _assert(true, 'a designer cannot remove a product');
  end;
end;
$$;

-- -----------------------------------------------------------------------------
-- As SUPERVISOR: completing the request closes the open work, not the done work
-- -----------------------------------------------------------------------------
reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_request uuid := (select v from _fx where k = 'request');
begin
  raise notice 'Closing a request:';

  update requests set status = 'COMPLETED' where id = v_request;

  perform _assert((select count(*) from tasks
                    where request_id = v_request
                      and status in ('TODO','IN_PROGRESS','BLOCKED')) = 0,
                  'no open work is left on a completed request');
  perform _assert((select status from tasks
                    where request_id = v_request and title = 'Cup artwork') = 'CANCELLED',
                  'someone else''s unfinished task is cancelled');
  perform _assert((select status from tasks
                    where request_id = v_request and title = 'Print') = 'DONE',
                  'finished work stays finished');
  perform _assert(exists (select 1 from activities
                           where request_id = v_request
                             and event_type = 'task.status_changed'
                             and to_value = 'CANCELLED'),
                  'the closure is in the history');
  perform _assert(coalesce(current_setting('inmore.closing_request', true), 'off') = 'off',
                  'the exemption is switched off again');
  perform _assert((select open_task_count from v_request_summary where id = v_request) = 0,
                  'cancelled work does not count as open');
  perform _assert((select notes is null and cancel_reason is null
                     from v_request_summary where id = v_request),
                  'the summary carries notes and the cancel reason');

  -- reopening is an ordinary status change, and logged as one
  update requests set status = 'DELIVERY' where id = v_request;
  perform _assert(exists (select 1 from activities
                           where request_id = v_request and event_type = 'request.reopened'),
                  'reopening is in the history');
end;
$$;

rollback;

drop function _assert(boolean, text);

\echo ''
\echo 'Workflow gaps: all assertions passed.'
