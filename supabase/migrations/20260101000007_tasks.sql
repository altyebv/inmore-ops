-- =============================================================================
-- 007 — Task read model  (slice step 3)
--
-- The tasks table, its triggers and its policies already exist. What is missing
-- is a read model: every screen that shows a task also needs the request number,
-- the customer and who is doing it, and none of those live on the row.
--
-- No money in this view, so every role can read it. The external cost of a task
-- lives in task_costs and stays there.
-- =============================================================================

create view v_task_summary with (security_invoker = on) as
select t.id,
       t.request_id,
       r.number          as request_number,
       r.status          as request_status,
       c.name            as customer_name,
       t.request_item_id,
       i.name            as item_name,
       t.type,
       t.title,
       t.description,
       t.status,
       t.assignee_id,
       e.full_name       as assignee_name,
       t.partner_id,
       p.name            as partner_name,
       t.due_at,
       t.started_at,
       t.completed_at,
       t.created_at,
       t.updated_at,
       -- what the board actually sorts and colours by
       (t.due_at is not null
        and t.due_at < now()
        and t.status <> 'DONE')                       as is_overdue,
       (t.assignee_id is null and t.partner_id is null) as is_unassigned
from tasks t
join requests r       on r.id = t.request_id
join customers c      on c.id = r.customer_id
left join request_items i on i.id = t.request_item_id
left join employees e  on e.id = t.assignee_id
left join partners p   on p.id = t.partner_id;

comment on view v_task_summary is
  'Read model for the My Work screen and the task list on a request. '
  'Deliberately money-free so every role can read it.';

grant select on v_task_summary to authenticated;
