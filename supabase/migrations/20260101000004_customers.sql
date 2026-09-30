-- =============================================================================
-- 004 — Customer search and duplicate detection  (slice step 1)
--
-- The one real data-quality problem here is the phone number. The same customer
-- arrives as "+974 5555 1234", "97455551234" and "5555-1234", and a supervisor
-- under time pressure will create a second record rather than hunt for the
-- first. Normalizing in the database means every client - desktop, the website
-- RPC, and whatever comes later - matches the same way.
-- =============================================================================

-- Digits only; a Qatar country code on an 8-digit local number is dropped so
-- the three spellings above all collapse to '55551234'.  Other formats are left
-- as their digits rather than guessed at.
create or replace function normalize_phone(p_phone text) returns text
language sql immutable as $$
  select nullif(
    case
      when regexp_replace(coalesce(p_phone, ''), '\D', '', 'g') ~ '^974[0-9]{8}$'
        then right(regexp_replace(p_phone, '\D', '', 'g'), 8)
      else regexp_replace(coalesce(p_phone, ''), '\D', '', 'g')
    end,
    ''
  );
$$;

alter table customers
  add column phone_normalized text
  generated always as (normalize_phone(phone)) stored;

-- Not unique: shared numbers and missing numbers are both real.  Duplicates are
-- surfaced to the user as a warning, never blocked.
create index customers_phone_normalized_idx on customers (phone_normalized)
  where phone_normalized is not null;

comment on column customers.phone_normalized is
  'Generated. Match on this, never on the raw phone column.';

-- -----------------------------------------------------------------------------
-- Search: name, company and phone in one call, ranked by trigram similarity.
--
-- Not security definer: it runs as the caller so customers RLS still applies.
-- -----------------------------------------------------------------------------
create or replace function search_customers(
  p_query text,
  p_limit int default 25
) returns setof customers
language sql stable as $$
  with q as (
    select nullif(trim(coalesce(p_query, '')), '') as text_q,
           normalize_phone(p_query)                as phone_q
  )
  select c.*
  from customers c, q
  where not c.is_archived
    and (
      q.text_q is null
      or c.name ilike '%' || q.text_q || '%'
      or coalesce(c.company, '') ilike '%' || q.text_q || '%'
      or (q.phone_q is not null and c.phone_normalized like '%' || q.phone_q || '%')
    )
  order by
    case when q.text_q is null then 0
         else greatest(similarity(c.name, q.text_q),
                       similarity(coalesce(c.company, ''), q.text_q))
    end desc,
    c.name asc
  limit greatest(p_limit, 1);
$$;

-- -----------------------------------------------------------------------------
-- Duplicate warning: "3 customers already share this number".
-- Called as the supervisor types, before the record is created.
-- -----------------------------------------------------------------------------
create or replace function customers_sharing_phone(
  p_phone text,
  p_exclude_id uuid default null
) returns setof customers
language sql stable as $$
  select c.*
  from customers c
  where c.phone_normalized is not null
    and c.phone_normalized = normalize_phone(p_phone)
    and (p_exclude_id is null or c.id <> p_exclude_id)
  order by c.created_at;
$$;

grant execute on function normalize_phone(text)              to authenticated;
grant execute on function search_customers(text, int)        to authenticated;
grant execute on function customers_sharing_phone(text, uuid) to authenticated;
