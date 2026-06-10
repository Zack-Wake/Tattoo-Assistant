-- PKT-007 — Rebooking rate + time-to-rebook
--
-- CLAUDE.md vision #5: client lifetime value, and whether the aftercare ->
-- next-piece loop exists or is pure luck.
--
-- Two distinct per-client signals (kept separate on purpose — see spec):
--
--   - rebooked — TRUE if the contact has MORE THAN ONE 'done' appointment.
--     They didn't just book again, they actually came back and completed
--     another session. This is the PKT-007 definition of "rebooked".
--
--   - rebooking_intent — TRUE if the contact currently has a future
--     'booked' appointment (status = 'booked' AND scheduled_at > now()),
--     regardless of how many sessions they've completed so far. This
--     covers the "one done session, then a future booking" case: they
--     haven't rebooked (completed a return visit) YET, but a return visit
--     is on the calendar.
--
-- avg_time_to_rebook — per-client average gap between consecutive 'done'
-- appointments (NULL for contacts with fewer than two 'done' appointments —
-- nothing to measure yet).
--
-- Note: this is a different question from src/db/queries/rebooking.sql
-- (PKT-005), whose `rebooked` column means "has a future booked
-- appointment" — i.e. closer to this file's `rebooking_intent`. The two
-- files are kept separate rather than reconciled, since they were built as
-- distinct, independently-specified packets.
--
-- Tenant scoping: deliberately has NO `artist_id = ...` clause. Scoping
-- comes entirely from the existing RLS (`artist_id = current_artist_id()`)
-- on `appointments` and `contacts` — same pattern as unfinished_pieces.sql
-- and rebooking.sql.

WITH done_appointments AS (
  SELECT
    contact_id,
    scheduled_at,
    LAG(scheduled_at) OVER (
      PARTITION BY contact_id ORDER BY scheduled_at
    ) AS prev_scheduled_at
  FROM appointments
  WHERE status = 'done'
),
per_contact AS (
  SELECT
    contact_id,
    COUNT(*) AS completed_sessions,
    AVG(scheduled_at - prev_scheduled_at)
      FILTER (WHERE prev_scheduled_at IS NOT NULL) AS avg_time_to_rebook
  FROM done_appointments
  GROUP BY contact_id
)
-- Per-client detail.
SELECT
  c.id   AS contact_id,
  c.name AS contact,
  pc.completed_sessions,
  pc.completed_sessions > 1 AS rebooked,
  pc.avg_time_to_rebook,
  EXISTS (
    SELECT 1 FROM appointments fa
    WHERE fa.contact_id = c.id
      AND fa.status = 'booked'
      AND fa.scheduled_at > now()
  ) AS rebooking_intent
FROM contacts c
JOIN per_contact pc ON pc.contact_id = c.id
ORDER BY pc.completed_sessions DESC, c.name;

-- Summary: overall rebooking rate + average time-to-rebook.
--
-- rebooking_rate = share of clients with a completed ('done') appointment
-- who have more than one — i.e. came back and completed another session.
-- avg_time_to_rebook_overall = average, across clients with >= 2 'done'
-- appointments, of their own average gap between consecutive 'done'
-- appointments.
WITH done_appointments AS (
  SELECT
    contact_id,
    scheduled_at,
    LAG(scheduled_at) OVER (
      PARTITION BY contact_id ORDER BY scheduled_at
    ) AS prev_scheduled_at
  FROM appointments
  WHERE status = 'done'
),
per_contact AS (
  SELECT
    contact_id,
    COUNT(*) AS completed_sessions,
    AVG(scheduled_at - prev_scheduled_at)
      FILTER (WHERE prev_scheduled_at IS NOT NULL) AS avg_time_to_rebook
  FROM done_appointments
  GROUP BY contact_id
)
SELECT
  COUNT(*) AS clients_with_completed_session,
  COUNT(*) FILTER (WHERE completed_sessions > 1) AS rebooked_clients,
  ROUND(
    COUNT(*) FILTER (WHERE completed_sessions > 1)::NUMERIC
      / NULLIF(COUNT(*), 0),
    2
  ) AS rebooking_rate,
  AVG(avg_time_to_rebook) AS avg_time_to_rebook_overall
FROM per_contact;
