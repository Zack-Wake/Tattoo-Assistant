-- PKT-005 — No-show / late-cancel rate, split by deposit-protected
--
-- CLAUDE.md vision #3: shows whether the deposit policy works and the cost
-- of each empty chair-hour, split by deposit-protected vs not.
--
-- Definitions (per spec):
--   - No-show     = appointment with status = 'no_show'.
--   - Late-cancel = appointment with status = 'cancelled'. No late-cancel
--     window (e.g. "cancelled within 24h of the appointment") is modelled
--     yet, so ALL 'cancelled' appointments are treated as late-cancels.
--     Revisit this if a cancellation grace period is ever added.
--   - Deposit-protected = a deposits row exists for the appointment with
--     confirmed_at IS NOT NULL (an unconfirmed deposit does not count as
--     protection).
--
-- Denominator: appointments with a realized outcome — status IN
-- ('done', 'no_show', 'cancelled'). Future 'booked' appointments are
-- excluded, since their outcome hasn't happened yet and including them
-- would understate the rates. 'done' appointments count toward the total
-- but not toward either rate — this is what pulls the rate down relative
-- to a denominator of just no_show + cancelled.
--
-- Tenant scoping: deliberately has NO `artist_id = ...` clause — scoping
-- comes entirely from the existing RLS (`artist_id = current_artist_id()`)
-- on `appointments` and `deposits`, same pattern as unfinished_pieces.sql.

SELECT
  EXISTS (
    SELECT 1 FROM deposits d
    WHERE d.appointment_id = a.id AND d.confirmed_at IS NOT NULL
  ) AS deposit_protected,
  COUNT(*) AS total_appointments,
  COUNT(*) FILTER (WHERE a.status = 'no_show')   AS no_show_count,
  COUNT(*) FILTER (WHERE a.status = 'cancelled') AS late_cancel_count,
  ROUND(COUNT(*) FILTER (WHERE a.status = 'no_show')::NUMERIC / COUNT(*), 2)   AS no_show_rate,
  ROUND(COUNT(*) FILTER (WHERE a.status = 'cancelled')::NUMERIC / COUNT(*), 2) AS late_cancel_rate
FROM appointments a
WHERE a.status IN ('done', 'no_show', 'cancelled')
GROUP BY deposit_protected
ORDER BY deposit_protected;
