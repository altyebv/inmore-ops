-- =============================================================================
-- Go-live wipe — run ONCE on the hosted project, before real work starts.
--
-- Removes everything people did while trying the system out: customers,
-- requests, quotations, payments, tasks, partners, the whole activity log, and
-- the @inmore.test accounts.  Keeps the product catalog and real staff.
--
-- The activity log is append-only for the apps (no UPDATE/DELETE grant for
-- anyone) and every future metric is computed from it, so test events left
-- in it would be counted forever.  This is the only time it is ever cleared;
-- after go-live, corrections are new events, never deletions.
--
--   npx supabase db query --linked -f supabase/go_live_wipe.sql
--
-- Real staff who signed in to try things keep their accounts.  Partners and
-- products they added are cleared/kept respectively — re-enter real partners
-- afterwards.
-- =============================================================================

begin;

truncate activities, payments, task_costs, tasks, quotation_lines, quotations,
         request_items, requests, customers, partners,
         stock_movements, inventory_item_costs, inventory_items, expenses
  restart identity;

delete from employees  where email like '%@inmore.test';
delete from auth.users where email like '%@inmore.test';

commit;

select (select count(*) from requests)   as requests,
       (select count(*) from activities) as activities,
       (select count(*) from products)   as products,
       (select count(*) from employees)  as employees;
