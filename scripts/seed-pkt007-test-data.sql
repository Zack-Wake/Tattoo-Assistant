-- Throwaway TEST data for verifying the PKT-007 report:
--   src/db/queries/rebooking_rate.sql
--
-- Seeds three fake contacts under Sean's artist_id, covering the three
-- cases from the packet spec:
--
-- "TEST — PKT-007 repeat client, no future booking (safe to delete)"
--   done @ NOW()-50d, done @ NOW()-15d, nothing future
--   -> completed_sessions=2, rebooked=TRUE, avg_time_to_rebook ~ 35 days,
--      rebooking_intent=FALSE
--   ("a contact with two 'done' appts spaced apart -> counts as rebooked,
--   gap measured")
--
-- "TEST — PKT-007 single-session client (safe to delete)"
--   done @ NOW()-20d, nothing else
--   -> completed_sessions=1, rebooked=FALSE, avg_time_to_rebook=NULL,
--      rebooking_intent=FALSE
--   ("a contact with one 'done' appt only -> not rebooked")
--
-- "TEST — PKT-007 done then future booking (safe to delete)"
--   done @ NOW()-25d, booked @ NOW()+7d
--   -> completed_sessions=1, rebooked=FALSE, avg_time_to_rebook=NULL,
--      rebooking_intent=TRUE
--   ("a contact with a 'done' then a future 'booked' -> counts toward
--   rebooking intent" — handled as a separate `rebooking_intent` column,
--   distinct from `rebooked`, since they have not yet completed a return
--   session)
--
-- These add to the existing PKT-002/PKT-005 fixtures already in this
-- project (a one-and-done client, a repeat client with a ~40-day gap plus
-- a future booking, no-show/deposit fixtures with a 3-day gap between two
-- done appointments, and a throwaway contact with one done appointment plus
-- a future booking). Combined, the summary query in rebooking_rate.sql
-- should read:
--   clients_with_completed_session = 7
--   rebooked_clients               = 3   (the PKT-005 repeat client, the
--                                          PKT-005 no-show/deposit fixtures,
--                                          and this packet's repeat client)
--   rebooking_rate                 = 0.43
--   avg_time_to_rebook_overall     = 26 days  (average of 3, 40, 35 days)
--
-- All rows are clearly named "TEST — PKT-007 ..." / "(safe to delete)" so
-- Sean can find and remove them later. Left in place deliberately so the
-- report's output is reproducible — same convention as
-- scripts/seed-pkt005-test-data.sql.
--
-- Run with a connection that bypasses RLS (e.g. the Supabase SQL editor /
-- service-role connection) — these inserts target Sean's artist_id
-- directly, which an RLS-scoped `authenticated` session could not do for
-- another tenant.

DO $$
DECLARE
  v_artist_id UUID := 'bc1b2a71-ca98-46d6-a9e3-4edfcaa81134'; -- Sean
  v_contact_x UUID; -- repeat client, no future booking
  v_contact_y UUID; -- single-session client
  v_contact_z UUID; -- done then future booking
BEGIN
  -- Contact X: two 'done' appointments, 35 days apart, nothing future
  INSERT INTO contacts (artist_id, name, external_handle)
  VALUES (v_artist_id, 'TEST — PKT-007 repeat client, no future booking (safe to delete)', '@test_pkt007_x')
  RETURNING id INTO v_contact_x;

  INSERT INTO appointments (artist_id, contact_id, status, scheduled_at, duration)
  VALUES (v_artist_id, v_contact_x, 'done', NOW() - INTERVAL '50 days', INTERVAL '2 hours');

  INSERT INTO appointments (artist_id, contact_id, status, scheduled_at, duration)
  VALUES (v_artist_id, v_contact_x, 'done', NOW() - INTERVAL '15 days', INTERVAL '2 hours');

  -- Contact Y: a single 'done' appointment, nothing else
  INSERT INTO contacts (artist_id, name, external_handle)
  VALUES (v_artist_id, 'TEST — PKT-007 single-session client (safe to delete)', '@test_pkt007_y')
  RETURNING id INTO v_contact_y;

  INSERT INTO appointments (artist_id, contact_id, status, scheduled_at, duration)
  VALUES (v_artist_id, v_contact_y, 'done', NOW() - INTERVAL '20 days', INTERVAL '1.5 hours');

  -- Contact Z: one 'done' appointment, then a future 'booked' follow-up
  INSERT INTO contacts (artist_id, name, external_handle)
  VALUES (v_artist_id, 'TEST — PKT-007 done then future booking (safe to delete)', '@test_pkt007_z')
  RETURNING id INTO v_contact_z;

  INSERT INTO appointments (artist_id, contact_id, status, scheduled_at, duration)
  VALUES (v_artist_id, v_contact_z, 'done', NOW() - INTERVAL '25 days', INTERVAL '2 hours');

  INSERT INTO appointments (artist_id, contact_id, status, scheduled_at, duration)
  VALUES (v_artist_id, v_contact_z, 'booked', NOW() + INTERVAL '7 days', INTERVAL '2 hours');
END $$;
