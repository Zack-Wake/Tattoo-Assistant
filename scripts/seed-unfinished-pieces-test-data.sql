-- Throwaway TEST data for verifying src/db/queries/unfinished_pieces.sql
-- (PKT-002 — unfinished-pieces report).
--
-- Seeds one fake contact and four fake in-progress/finished pieces under
-- Sean's artist_id, covering every branch of the unfinished-piece logic:
--
--   "TEST — no booking"  in_progress, no appointments at all      -> should APPEAR
--   "TEST — booked"      in_progress, future 'booked' appointment -> should be EXCLUDED
--   "TEST — cancelled"   in_progress, future 'cancelled' appt only -> should APPEAR (edge case)
--   "TEST — finished"    status = 'finished'                       -> should be EXCLUDED
--
-- All rows are clearly named "TEST — ..." / "(safe to delete)" so Sean can
-- find and remove them later. Left in place deliberately so the report's
-- output is reproducible — do not auto-delete.
--
-- Run with a connection that bypasses RLS (e.g. the Supabase SQL editor /
-- service-role connection) — these inserts target Sean's artist_id directly,
-- which an RLS-scoped `authenticated` session could not do for another tenant.

DO $$
DECLARE
  v_artist_id        UUID := 'bc1b2a71-ca98-46d6-a9e3-4edfcaa81134'; -- Sean
  v_contact_id       UUID;
  v_piece_no_booking UUID;
  v_piece_booked     UUID;
  v_piece_cancelled  UUID;
  v_piece_finished   UUID;
BEGIN
  INSERT INTO contacts (artist_id, name, external_handle)
  VALUES (v_artist_id, 'TEST — throwaway contact (safe to delete)', '@test_throwaway')
  RETURNING id INTO v_contact_id;

  INSERT INTO pieces (artist_id, contact_id, description, status, whats_left)
  VALUES (v_artist_id, v_contact_id, 'TEST — no booking', 'in_progress',
          'Throwaway test piece for PKT-002 verification — safe to delete')
  RETURNING id INTO v_piece_no_booking;

  INSERT INTO pieces (artist_id, contact_id, description, status, whats_left)
  VALUES (v_artist_id, v_contact_id, 'TEST — booked', 'in_progress',
          'Throwaway test piece for PKT-002 verification — safe to delete')
  RETURNING id INTO v_piece_booked;

  INSERT INTO pieces (artist_id, contact_id, description, status, whats_left)
  VALUES (v_artist_id, v_contact_id, 'TEST — cancelled', 'in_progress',
          'Throwaway test piece for PKT-002 verification — safe to delete')
  RETURNING id INTO v_piece_cancelled;

  INSERT INTO pieces (artist_id, contact_id, description, status, whats_left)
  VALUES (v_artist_id, v_contact_id, 'TEST — finished', 'finished', NULL)
  RETURNING id INTO v_piece_finished;

  -- future 'booked' appointment -> should EXCLUDE "TEST — booked"
  INSERT INTO appointments (artist_id, contact_id, piece_id, status, scheduled_at)
  VALUES (v_artist_id, v_contact_id, v_piece_booked, 'booked', NOW() + INTERVAL '14 days');

  -- future 'cancelled' appointment -> must NOT exclude "TEST — cancelled" (edge case)
  INSERT INTO appointments (artist_id, contact_id, piece_id, status, scheduled_at)
  VALUES (v_artist_id, v_contact_id, v_piece_cancelled, 'cancelled', NOW() + INTERVAL '10 days');

  -- past 'done' appointment, for realism on the finished piece
  INSERT INTO appointments (artist_id, contact_id, piece_id, status, scheduled_at)
  VALUES (v_artist_id, v_contact_id, v_piece_finished, 'done', NOW() - INTERVAL '20 days');
END $$;
