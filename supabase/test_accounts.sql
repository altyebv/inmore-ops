-- =============================================================================
-- Test accounts on the hosted project — for looking around before go-live.
--
-- 1. Dashboard → Authentication → Users → Add user → Create new user, with
--    "Auto Confirm User" ticked, for any of:
--
--      owner@inmore.test      OWNER        sees everything, including money
--      ahmed@inmore.test      SUPERVISOR   the demo data is recorded as him
--      sara@inmore.test       DESIGNER     money must be invisible here
--      mohammed@inmore.test   PRODUCTION
--      layla@inmore.test      DESIGNER     optional
--      fatima@inmore.test     SUPERVISOR   optional
--
--    `.test` is a reserved domain, so no real mailbox can receive anything
--    sent to these.  One account is enough; four covers every role.
--
-- 2. Run this file (SQL Editor, or `npx supabase db query --linked -f ...`),
--    then demo_data.sql if you want screens with something in them.
--
-- go_live_wipe.sql removes all of it — accounts included — before real use.
-- =============================================================================

update employees
   set role = case split_part(email, '@', 1)
                when 'owner'    then 'OWNER'
                when 'ahmed'    then 'SUPERVISOR'
                when 'fatima'   then 'SUPERVISOR'
                when 'sara'     then 'DESIGNER'
                when 'layla'    then 'DESIGNER'
                when 'mohammed' then 'PRODUCTION'
              end::employee_role,
       full_name = initcap(split_part(email, '@', 1)) || ' (test)',
       is_active = true
 where email like '%@inmore.test'
   and split_part(email, '@', 1) in ('owner', 'ahmed', 'fatima', 'sara', 'layla', 'mohammed');

select full_name, email, role, is_active from employees order by role, full_name;
