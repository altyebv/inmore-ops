-- =============================================================================
-- Giving a staff member access — run in the hosted project's SQL Editor.
--
-- 1. Dashboard → Authentication → Users → Add user → Create new user.
--    Email + a temporary password, tick "Auto Confirm User".
--    handle_new_auth_user() creates their employees row: inactive, SUPERVISOR,
--    named after the part of the email before the @.
--
-- 2. Set their name and role, and activate them — edit the values and run the
--    matching lines.  Roles: OWNER, SUPERVISOR, DESIGNER, PRODUCTION.
--    The SQL Editor runs with no auth.uid(), which trg_employees_restrict_role
--    treats as the admin path, so this is allowed here and nowhere else.
--
-- An inactive employee can sign in but sees nothing: every policy goes through
-- current_employee_id(), which only returns active rows.  Deactivating someone
-- is the way to remove access while keeping their name on the history —
-- never delete the auth user (employees.id is `on delete restrict` for that
-- reason).
-- =============================================================================

update employees
   set full_name = 'Full Name', role = 'OWNER', is_active = true
 where email = 'owner@example.com';

-- update employees
--    set full_name = 'Full Name', role = 'SUPERVISOR', is_active = true
--  where email = 'someone@example.com';

-- Remove access, keep history:
-- update employees set is_active = false where email = 'someone@example.com';

-- Check:
select full_name, email, role, is_active from employees order by role, full_name;
