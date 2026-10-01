-- =============================================================================
-- Task assignment and execution test  (slice step 3)
--
--   docker exec -i supabase_db_inmore-ops psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 -q < supabase/tests/tasks_test.sql
--
-- The point of these assertions is the distinction the whole model rests on:
-- the supervisor OWNS the request, other people EXECUTE parts of it, and a
-- partner is just another executor.
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
insert into customers (name, phone) values ('Task Test Co.', '+974 8888 0000');

create temporary table _fx (k text primary key, v uuid) on commit drop;
grant select, insert on _fx to authenticated;

-- -----------------------------------------------------------------------------
-- A supervisor takes the request and farms the work out
-- -----------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_request  requests;
  v_design   uuid;
  v_print    uuid;
  v_external uuid;
  v_sara     uuid := '44444444-4444-4444-4444-444444444444';
  v_mohammed uuid := '66666666-6666-6666-6666-666666666666';
begin
  raise notice 'Responsibility vs execution:';

  select * into v_request from create_request(
    p_customer_id := (select id from customers where name = 'Task Test Co.'),
    p_title       := 'Cafe launch',
    p_items       := jsonb_build_array(
      jsonb_build_object('name', 'Paper Cups', 'quantity', 5000),
      jsonb_build_object('name', 'Signage',    'quantity', 2)
    )
  );
  insert into _fx values ('request', v_request.id);

  insert into tasks (request_id, request_item_id, type, title, assignee_id)
  values (v_request.id,
          (select id from request_items where request_id = v_request.id and position = 1),
          'DESIGN', 'Cup artwork', v_sara)
  returning id into v_design;
  insert into _fx values ('design', v_design);

  insert into tasks (request_id, type, title, assignee_id)
  values (v_request.id, 'PRODUCTION', 'Print run', v_mohammed)
  returning id into v_print;

  -- a partner is an executor, not a parallel universe
  insert into tasks (request_id, type, title, partner_id)
  values (v_request.id, 'EXTERNAL', 'Outsourced signage',
          (select id from partners where name = 'Al Waab Signage'))
  returning id into v_external;
  insert into _fx values ('external', v_external);

  perform _assert(v_request.supervisor_id = '22222222-2222-2222-2222-222222222222',
                  'the supervisor owns the request');
  perform _assert((select count(*) from tasks where request_id = v_request.id) = 3,
                  'three people work on one request');
  perform _assert((select count(distinct assignee_id) from tasks
                    where request_id = v_request.id and assignee_id is not null) = 2,
                  'two different employees execute');
  perform _assert((select partner_id from tasks where id = v_external) is not null,
                  'a partner executes the third');

  -- an executor is an employee or a partner, never both
  declare v_blocked boolean := false;
  begin
    begin
      update tasks set partner_id = (select id from partners limit 1)
       where id = v_design;
    exception when check_violation then v_blocked := true;
    end;
    perform _assert(v_blocked, 'a task cannot have both an employee and a partner');
  end;

  perform _assert((select count(*) from activities
                    where request_id = v_request.id and event_type = 'task.assigned') = 2,
                  'employee assignment is logged');
  perform _assert((select count(*) from activities
                    where request_id = v_request.id
                      and event_type = 'task.partner_assigned') = 1,
                  'partner assignment is logged');
end;
$$;

-- -----------------------------------------------------------------------------
-- The designer works her own task
-- -----------------------------------------------------------------------------
reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
declare
  v_design  uuid := (select v from _fx where k = 'design');
  v_request uuid := (select v from _fx where k = 'request');
  v_blocked boolean;
begin
  raise notice 'As DESIGNER, working her own task:';

  -- Scoped to this fixture: Sara may legitimately have other work in a
  -- database with real data in it.
  perform _assert(exists(select 1 from v_task_summary
                          where id = v_design
                            and assignee_id = current_employee_id()),
                  'My Work includes her task');
  perform _assert(not exists(select 1 from v_task_summary
                              where request_id = v_request
                                and type = 'PRODUCTION'
                                and assignee_id = current_employee_id()),
                  'My Work excludes production''s task');
  perform _assert((select request_number from v_task_summary where id = v_design) is not null,
                  'the read model carries the request number');
  perform _assert((select customer_name from v_task_summary where id = v_design)
                  = 'Task Test Co.',
                  'the read model carries the customer');
  perform _assert((select item_name from v_task_summary where id = v_design) = 'Paper Cups',
                  'the read model carries the item');

  update tasks set status = 'IN_PROGRESS' where id = v_design;
  perform _assert((select started_at from tasks where id = v_design) is not null,
                  'started_at is stamped automatically');

  update tasks set status = 'DONE' where id = v_design;
  perform _assert((select completed_at from tasks where id = v_design) is not null,
                  'completed_at is stamped automatically');

  -- reopening must clear the completion, or the duration metrics lie
  update tasks set status = 'IN_PROGRESS' where id = v_design;
  perform _assert((select completed_at from tasks where id = v_design) is null,
                  'reopening clears completed_at');

  perform _assert((select count(*) from activities
                    where request_id = v_request and event_type = 'task.status_changed') = 3,
                  'every status change is logged');
  perform _assert((select count(*) from activities
                    where request_id = v_request and event_type = 'task.completed') = 1,
                  'completion is logged');

  -- ...but she may not touch anyone else's, or retitle her own.
  --
  -- NOTE the two different denial mechanisms, because clients must handle both:
  -- an RLS policy filters the row out SILENTLY (0 rows updated, no exception),
  -- while a trigger guard RAISES. A client that treats "no error" as success
  -- would show a fake "saved" here.
  update tasks set status = 'DONE'
   where request_id = v_request and type = 'PRODUCTION';
  perform _assert((select status from tasks
                    where request_id = v_request and type = 'PRODUCTION') = 'TODO',
                  'may NOT update production''s task (RLS filters it silently)');

  v_blocked := false;
  begin
    update tasks set title = 'renamed' where id = v_design;
  exception when insufficient_privilege then v_blocked := true;
  end;
  perform _assert(v_blocked, 'may NOT retitle even her own task');

  -- and the request still belongs to the supervisor
  perform _assert((select supervisor_id from requests where id = v_request)
                  <> current_employee_id(),
                  'executing work does not transfer ownership');
end;
$$;

-- -----------------------------------------------------------------------------
-- Partner duration, which is the whole reason partners are tasks
-- -----------------------------------------------------------------------------
reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
declare
  v_external uuid := (select v from _fx where k = 'external');
begin
  raise notice 'Partner turnaround:';

  update tasks set status = 'IN_PROGRESS', started_at = now() - interval '6 days'
   where id = v_external;
  update tasks set status = 'DONE', completed_at = now() - interval '2 days'
   where id = v_external;

  perform _assert(
    (select completed_at - started_at from tasks where id = v_external)
      between interval '3 days' and interval '5 days',
    'how long the partner took is answerable from the task row');

  perform _assert((select partner_name from v_task_summary where id = v_external)
                  = 'Al Waab Signage',
                  'the read model names the partner');

  -- cost is money, so it lives in its own table
  insert into task_costs (task_id, amount) values (v_external, 1450);
  perform _assert((select amount from task_costs where task_id = v_external) = 1450,
                  'a supervisor may record the external cost');
end;
$$;

-- -----------------------------------------------------------------------------
-- Production must not see that cost
-- -----------------------------------------------------------------------------
reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}';

do $$
declare
  v_external uuid := (select v from _fx where k = 'external');
begin
  raise notice 'As PRODUCTION:';

  perform _assert((select count(*) from task_costs) = 0,
                  'external cost is hidden');
  perform _assert((select count(*) from v_task_summary where id = v_external) = 1,
                  'the task itself is still visible');
  perform _assert((select count(*) from activities
                    where entity_type = 'task_cost') = 0,
                  'the cost event is hidden from the timeline');
end;
$$;

rollback;

drop function _assert(boolean, text);

\echo ''
\echo 'Task assignment and execution: all assertions passed.'
