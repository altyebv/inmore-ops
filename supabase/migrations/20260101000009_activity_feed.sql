-- =============================================================================
-- 009 — Activity feed read model  (slice step 5)
--
-- The timeline is the screen that makes the whole log worth keeping: it is
-- where a supervisor answers "what happened to #1042 and when".
--
-- security_invoker means the money filter on activities still applies, so a
-- designer reading this feed gets the operational story with the quotation and
-- payment entries absent. Amounts stay in metadata and are never projected
-- into a column here.
-- =============================================================================

create view v_activity_feed with (security_invoker = on) as
select a.id,
       a.occurred_at,
       a.request_id,
       r.number     as request_number,
       a.entity_type,
       a.entity_id,
       a.event_type,
       a.from_value,
       a.to_value,
       a.metadata,
       a.actor_kind,
       a.actor_id,
       coalesce(e.full_name,
                case a.actor_kind
                  when 'CUSTOMER' then 'Customer'
                  when 'SYSTEM'   then 'System'
                  else 'Unknown'
                end) as actor_name
from activities a
left join employees e on e.id = a.actor_id
left join requests  r on r.id = a.request_id;

comment on view v_activity_feed is
  'Request timeline. Money-bearing events are filtered by the activities RLS '
  'policy, so this is safe to show to any role. ORDER BY id, not occurred_at.';

-- ORDER BY id, NOT occurred_at.
--
-- now() returns the transaction timestamp, so every event written by a single
-- operation shares one occurred_at - create_request alone writes request.created
-- plus one item.added per item, all with the identical value. Ordering a
-- timeline by occurred_at therefore scrambles those groups at random. The
-- monotonic id is the only correct ordering; occurred_at is for date filtering
-- and durations.
create index activities_request_id_idx on activities (request_id, id desc);

grant select on v_activity_feed to authenticated;
