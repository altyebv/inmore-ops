-- =============================================================================
-- 006 — Realtime
--
-- Three tables only (blueprint §E): the desktop work board and request detail,
-- and the owner's live overview. Quotations and payments are deliberately not
-- published - the person writing them is looking at the screen already, so it
-- would be load without a behaviour change.
--
-- RLS still applies to realtime, so a designer never receives a row they could
-- not have selected.
-- =============================================================================

alter publication supabase_realtime add table requests;
alter publication supabase_realtime add table tasks;
alter publication supabase_realtime add table activities;
