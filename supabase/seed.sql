-- =============================================================================
-- Local development seed.
--
-- LOCAL ONLY.  These accounts and passwords exist so `supabase start` gives you
-- a working login for each role.  They are never applied to the hosted projects
-- (`supabase db push` does not run this file).  Real staff accounts are created
-- from the Supabase dashboard; see docs/blueprint.md §E.
--
-- Dev accounts, all with password:  inmore-dev
--   owner@inmore.local        OWNER
--   ahmed@inmore.local        SUPERVISOR
--   fatima@inmore.local       SUPERVISOR
--   sara@inmore.local         DESIGNER
--   layla@inmore.local        DESIGNER
--   mohammed@inmore.local     PRODUCTION
--
-- Sign in as sara@ or mohammed@ to verify the money boundary: quotations,
-- payments, task costs and money activity events must all come back empty.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Auth users.  handle_new_auth_user() creates the matching employees row
-- (inactive, SUPERVISOR); we then set the real role below.
-- -----------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000',
  u.id, 'authenticated', 'authenticated', u.email,
  extensions.crypt('inmore-dev', extensions.gen_salt('bf')),
  now(), now(), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('full_name', u.full_name),
  '', '', '', ''
from (values
  ('11111111-1111-1111-1111-111111111111'::uuid, 'owner@inmore.local',    'Inmore Owner'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'ahmed@inmore.local',    'Ahmed'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'fatima@inmore.local',   'Fatima'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'sara@inmore.local',     'Sara'),
  ('55555555-5555-5555-5555-555555555555'::uuid, 'layla@inmore.local',    'Layla'),
  ('66666666-6666-6666-6666-666666666666'::uuid, 'mohammed@inmore.local', 'Mohammed')
) as u(id, email, full_name)
on conflict (id) do nothing;

-- GoTrue needs an identity row to accept an email/password sign-in.
insert into auth.identities (
  provider_id, user_id, identity_data, provider, last_sign_in_at,
  created_at, updated_at
)
select u.id::text, u.id,
       jsonb_build_object('sub', u.id::text, 'email', u.email,
                          'email_verified', true, 'phone_verified', false),
       'email', now(), now(), now()
from auth.users u
where u.email like '%@inmore.local'
on conflict (provider, provider_id) do nothing;

-- -----------------------------------------------------------------------------
-- Roles.  auth.uid() is null here, so trg_employees_restrict_role lets this
-- through as an admin path.
-- -----------------------------------------------------------------------------
update employees set role = 'OWNER',      is_active = true
  where email = 'owner@inmore.local';
update employees set role = 'SUPERVISOR', is_active = true
  where email in ('ahmed@inmore.local', 'fatima@inmore.local');
update employees set role = 'DESIGNER',   is_active = true
  where email in ('sara@inmore.local', 'layla@inmore.local');
update employees set role = 'PRODUCTION', is_active = true
  where email = 'mohammed@inmore.local';

-- -----------------------------------------------------------------------------
-- Product catalog — a vocabulary, not a constraint.  Anything not listed can
-- still be typed as a free-form request item.
-- -----------------------------------------------------------------------------
insert into products (name, category, default_unit, sort_order) values
  ('Paper Cups',            'Printed Packaging', 'pcs',   10),
  ('Paper Bags',            'Printed Packaging', 'pcs',   20),
  ('Plastic Bags',          'Printed Packaging', 'pcs',   30),
  ('Food Boxes',            'Printed Packaging', 'pcs',   40),
  ('Custom Packaging',      'Printed Packaging', 'pcs',   50),
  ('Stickers',              'Print',             'pcs',   60),
  ('Business Cards',        'Print',             'pcs',   70),
  ('Flyers',                'Print',             'pcs',   80),
  ('Brochures',             'Print',             'pcs',   90),
  ('Roll-up Banner',        'Large Format',      'pcs',  100),
  ('Vinyl Banner',          'Large Format',      'sqm',  110),
  ('Signage',               'Large Format',      'pcs',  120),
  ('Vehicle Branding',      'Large Format',      'job',  130),
  ('Logo Design',           'Design',            'job',  140),
  ('Brand Identity',        'Design',            'job',  150),
  ('Social Media Design',   'Design',            'job',  160)
on conflict (name) do nothing;

-- -----------------------------------------------------------------------------
-- Partners — placeholders so the external-work path is exercisable.
-- -----------------------------------------------------------------------------
insert into partners (name, contact_name, phone, services) values
  ('Doha Print House',   'Khalid', '+974 4400 0001', 'Offset printing, large runs'),
  ('Gulf Packaging Co.', 'Rashid', '+974 4400 0002', 'Custom boxes, die-cutting'),
  ('Al Waab Signage',    'Yousef', '+974 4400 0003', 'Signage, vehicle wraps')
on conflict do nothing;
