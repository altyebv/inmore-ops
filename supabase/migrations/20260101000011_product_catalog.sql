-- =============================================================================
-- Starting product catalog.
--
-- This was in seed.sql, but `supabase db push` never runs the seed, so a
-- hosted project came up with an empty catalog.  The catalog is reference
-- data every environment needs; the seed keeps only what is local-only (dev
-- accounts, placeholder partners).
--
-- A vocabulary, not a constraint.  Anything not listed can still be typed as a
-- free-form request item.  `on conflict` so a project that was given these by
-- hand is left as it is.
-- =============================================================================

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
