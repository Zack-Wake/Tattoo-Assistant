# Packet 2 — Unfinished-pieces report

**Build-order step:** 2 of 6
**Status:** Done — built on `task/unfinished-pieces-report`
**Depends on:** Packet 1 (multi-tenant schema, RLS, seed `artists` row for Sean)
**Unblocks:** Packet 3 (follow-up drafting — drafts a message for each piece this report surfaces)

## Why this packet exists
This is CLAUDE.md's highest-value recoverable-revenue group: clients with one
session logged on a multi-session piece and no follow-up booked. They already
trust the artist and have sunk cost — they just need a nudge. No social API
needed for this step — it's a database query and nothing else. Everything else
in the system is a query or a prompt that runs *over* the Packet 1 schema; this
is the first of those.

Guardrail held while building this: a query and a way to prove it's correct.
**No features beyond that** — no UI, no send/draft action, no scoring.

## The signal: what makes a piece "unfinished"
A piece counts as unfinished when **both** are true:
- `pieces.status = 'in_progress'`
- there is **no** `appointments` row for that piece with `status = 'booked'`
  **and** `scheduled_at` in the future

Two rules that came directly out of the Packet 1 decision trail and had to be
held precisely:
- **`whats_left` is the artist's free-text notes box, not the trigger.** It's
  useful context to *show* alongside a flagged piece, but it never decides
  whether a piece is unfinished.
- **Only a future `booked` appointment counts as "covered."** A future
  `cancelled` or `no_show` appointment does **not** clear the flag — a
  cancelled follow-up leaves the piece exactly as unfinished as if nothing had
  ever been booked. Excluding it on a cancelled-but-still-on-the-calendar
  technicality would hide the exact clients this report exists to surface.

## The query
Lives in `src/db/queries/unfinished_pieces.sql`. A single `SELECT` joining
`pieces` → `contacts`, filtered by the rule above, with a correlated subquery
for each piece's most recent appointment (so the artist can see how long it's
been). Output columns: `piece`, `contact`, `whats_left`, `last_appointment_at`.

Output is a plain readable list (console / simple JSON) — no dashboard, no UI,
no send-or-draft action. Those are later packets' jobs.

## Security — tenant scoping via the existing RLS (no app-side filtering)
The query has **no `artist_id = ...` clause**. Tenant scoping comes entirely
from the RLS policies Packet 1 put in place (`artist_id = current_artist_id()`,
reading the caller's JWT `app_metadata.artist_id` claim). Run it through an
authenticated Supabase client (e.g. `src/lib/supabase/server.ts`) and Postgres
supplies the `artist_id` filter automatically — re-implementing it in the query
or app code would be redundant and would risk the two falling out of sync.

## Test data / verification
`scripts/seed-unfinished-pieces-test-data.sql` seeds one fake contact
(`"TEST — throwaway contact (safe to delete)"`) and four fake pieces under
Sean's `artist_id`, named so they're unmistakably throwaway and easy for Sean
to find and remove later:

| Seeded piece | Scenario | Expected | Actual |
|---|---|---|---|
| `TEST — no booking` | in_progress, zero appointments | APPEARS | ✅ Appeared |
| `TEST — booked` | in_progress, future `booked` appt | EXCLUDED | ✅ Excluded |
| `TEST — cancelled` | in_progress, only a future `cancelled` appt | APPEARS (edge case) | ✅ Appeared |
| `TEST — finished` | `status = 'finished'` | EXCLUDED | ✅ Excluded |

Verified by running the query against live data with Sean's `artist_id` JWT
claim simulated (`set_config('request.jwt.claims', ...)` — the same technique
used to verify RLS isolation in Packet 1). All four branches matched.

Note: at verification time the live `pieces` table had **no real records** —
Sean's backfill is still pending (see Packet 1's "Out of scope" /
`docs/decisions.md`). `TEST — no booking` stands in for the true-positive,
no-future-booking case until real client data exists; re-run the report once
it does.

## Definition of Done
- [x] Query returns in-progress pieces with no booked future appointment,
      scoped by the caller's `artist_id` via existing RLS — no filter
      re-implemented in app code.
- [x] Cancelled / no-show future appointments do not exclude a piece.
- [x] All four test cases match expected output (table above).
- [x] Query lives in `src/db/queries/`; seed script in `scripts/`.
- [x] Committed to `task/unfinished-pieces-report`, not `main`.

## Out of scope (named, deferred — do NOT pull in)
- Drafting or sending the actual follow-up message → **Packet 3**
- Any UI / dashboard rendering of this list
- Auto-deleting the throwaway `TEST —` rows (left in place, clearly named, so
  the report stays reproducible — Sean removes them when ready)
- Anything that infers "unfinished" from `whats_left` content, NLP, or any
  signal other than the explicit `status` + booking-gap rule above
- Social media / Instagram intake (step 6)

## Decision trail (so the *why* survives)
- **No `artist_id` filter in the query** — Packet 1's entire point was real RLS
  instead of app-side filtering; re-adding it here would be exactly the
  redundancy that decision was meant to prevent, and a second source of truth
  that could silently drift from the policies.
- **Cancelled/no-show ≠ covered** — came directly from this packet's brief, not
  an inference. The report's whole purpose is to catch slipped-through clients;
  treating a lapsed booking as "handled" would create the false negatives this
  report exists to eliminate.
- **`whats_left` stays a notes box** — Packet 1 already named it as "the
  artist's own notes box AND the unfinished signal" but also flagged that the
  *actual* trigger should be `status = 'in_progress'` + booking gap, not
  `whats_left` alone (`docs/decisions.md`, "Packet 1 correction"). This packet
  is where that distinction got enforced in code.
- **Throwaway test rows kept, not deleted** — the live schema had zero real
  `pieces` rows at build time (Sean's data isn't backfilled yet), so seeded
  data is the only way to prove the query's branches. Leaving it in place
  (clearly labelled) keeps the report reproducible for the next session.
