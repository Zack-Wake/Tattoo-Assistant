-- PKT-002 — Unfinished-pieces report
--
-- An "unfinished piece" is one the artist has started but has no follow-up on
-- the books for:
--
--   pieces.status = 'in_progress'
--   AND there is NO appointment for that piece with status = 'booked'
--       and scheduled_at in the future
--
-- Notes on the logic (read before changing it):
-- - `whats_left` is the artist's free-text notes box, not a signal — it is
--   never used to decide unfinished/finished.
-- - Only a future 'booked' appointment counts as "covered". Future
--   'cancelled' or 'no_show' appointments do NOT exclude a piece — a
--   cancelled follow-up means the piece is just as unfinished as if nothing
--   had ever been booked.
--
-- Tenant scoping: deliberately has NO `artist_id = ...` filter. Scoping comes
-- entirely from the existing RLS policies (`artist_id = current_artist_id()`,
-- reading the caller's JWT `app_metadata.artist_id` claim) — see
-- src/db/migrations/001_initial_schema.sql. Run this through an authenticated
-- Supabase client (e.g. src/lib/supabase/server.ts) and RLS supplies the
-- `artist_id` automatically; do not re-add it here.

SELECT
  p.id          AS piece_id,
  p.description AS piece,
  c.name        AS contact,
  p.whats_left  AS whats_left,
  (
    SELECT MAX(a.scheduled_at)
    FROM appointments a
    WHERE a.piece_id = p.id
  )             AS last_appointment_at
FROM pieces p
JOIN contacts c ON c.id = p.contact_id
WHERE p.status = 'in_progress'
  AND NOT EXISTS (
    SELECT 1
    FROM appointments a
    WHERE a.piece_id = p.id
      AND a.status = 'booked'
      AND a.scheduled_at > now()
  )
ORDER BY last_appointment_at NULLS FIRST;
