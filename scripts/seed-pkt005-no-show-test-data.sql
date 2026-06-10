-- Throwaway TEST data for verifying the PKT-005 report:
--   src/db/queries/no_show_rate.sql
--
-- Seeds one fake contact under Sean's artist_id with five appointments,
-- covering exactly the cases from the packet spec:
--
-- "TEST — PKT-005 no-show report fixtures (safe to delete)"
--   1. no_show, confirmed deposit  -> protected no-show
--   2. no_show, no deposit         -> unprotected no-show
--   3. cancelled, confirmed deposit -> protected late-cancel
--   4. cancelled, no deposit        -> unprotected late-cancel
--   5. done, no deposit             -> counts in totals, not as
--      no-show/cancel
--
-- Expected, for THIS contact's rows in isolation:
--   deposit_protected = true:  total=2 (1 no_show + 1 cancelled)
--                       no_show_rate = 0.50, late_cancel_rate = 0.50
--   deposit_protected = false: total=3 (1 no_show + 1 cancelled + 1 done)
--                       no_show_rate = 0.33, late_cancel_rate = 0.33
-- The "false" group's rates are pulled down by the done appointment in the
-- denominator — demonstrating "a done appt counts in totals, not as
-- no-show/cancel".
--
-- The full no_show_rate.sql report also includes earlier TEST fixtures from
-- PKT-002/PKT-005(unmerged)/PKT-007 already in this project, the same way
-- those packets' reports include each other's fixtures — see their seed
-- scripts for what they contribute.
--
-- All rows are clearly named "TEST — PKT-005 ..." / "(safe to delete)" so
-- Sean can find and remove them later. Left in place deliberately so the
-- report's output is reproducible.
--
-- Run with a connection that bypasses RLS (e.g. the Supabase SQL editor /
-- service-role connection) — these inserts target Sean's artist_id
-- directly, which an RLS-scoped `authenticated` session could not do for
-- another tenant.

DO $$
DECLARE
  v_artist_id UUID := 'bc1b2a71-ca98-46d6-a9e3-4edfcaa81134'; -- Sean
  v_contact_id UUID;
  v_appt_id   UUID;
BEGIN
  INSERT INTO contacts (artist_id, name, external_handle)
  VALUES (v_artist_id, 'TEST — PKT-005 no-show report fixtures (safe to delete)', '@test_pkt005_noshow')
  RETURNING id INTO v_contact_id;

  -- 1. no_show, deposit-protected (confirmed)
  INSERT INTO appointments (artist_id, contact_id, status, scheduled_at, duration)
  VALUES (v_artist_id, v_contact_id, 'no_show', NOW() - INTERVAL '5 days', INTERVAL '1 hour')
  RETURNING id INTO v_appt_id;
  INSERT INTO deposits (artist_id, appointment_id, amount, confirmed_at, confirmed_by, method)
  VALUES (v_artist_id, v_appt_id, 50.00, NOW() - INTERVAL '6 days', 'Sean', 'bank');

  -- 2. no_show, NOT deposit-protected (no deposit row at all)
  INSERT INTO appointments (artist_id, contact_id, status, scheduled_at, duration)
  VALUES (v_artist_id, v_contact_id, 'no_show', NOW() - INTERVAL '10 days', INTERVAL '1 hour');

  -- 3. cancelled, deposit-protected (confirmed)
  INSERT INTO appointments (artist_id, contact_id, status, scheduled_at, duration)
  VALUES (v_artist_id, v_contact_id, 'cancelled', NOW() - INTERVAL '3 days', INTERVAL '2 hours')
  RETURNING id INTO v_appt_id;
  INSERT INTO deposits (artist_id, appointment_id, amount, confirmed_at, confirmed_by, method)
  VALUES (v_artist_id, v_appt_id, 50.00, NOW() - INTERVAL '4 days', 'Sean', 'bank');

  -- 4. cancelled, NOT deposit-protected (no deposit row at all)
  INSERT INTO appointments (artist_id, contact_id, status, scheduled_at, duration)
  VALUES (v_artist_id, v_contact_id, 'cancelled', NOW() - INTERVAL '7 days', INTERVAL '1 hour');

  -- 5. done, NOT deposit-protected -- counts in totals, not as no-show/cancel
  INSERT INTO appointments (artist_id, contact_id, status, scheduled_at, duration)
  VALUES (v_artist_id, v_contact_id, 'done', NOW() - INTERVAL '12 days', INTERVAL '2 hours');
END $$;
