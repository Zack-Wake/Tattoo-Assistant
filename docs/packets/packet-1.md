# Packet 1 — Multi-tenant data model

**Build-order step:** 1 of 6 (foundation)
**Status:** Specced, ready to build
**Depends on:** nothing
**Unblocks:** Packet 2 (unfinished-pieces report), Packet 3 (follow-up drafting)

## Why this packet exists
Every other packet in the system is a query or a prompt that runs *over* this schema.
Tenancy (`artist_id` on every table) goes in now because adding it to populated tables
later is the expensive, error-prone retrofit the project is explicitly trying to avoid.
This packet produces the data **shape** and the security model. It deliberately produces
**no features** — no reports, no prompts, no payment logic, no UI.

Guardrail held while spec'ing this: build the full multi-tenant data shape now, build
**zero** speculative machinery on top of it. Tables and `artist_id`: yes. Stripe/payment
processing, signup, enquiry-scoring: no — those wait for a real, named need.

## Tables
All seven carry `artist_id`. Types below are proposals; Claude Code firms them up against
the live Supabase docs.

### artists  (the tenant / config row)
- `id`, `name`
- `voice_tone_profile` — the per-artist AI voice. **Voice is config, not code.**
- `working_hours`
- `deposit_rules`
- `created_at`

### blocklist  (the do-not-engage boundary)
- `id`, `artist_id`
- `identifier` — handle / external ID to drop at ingestion
- `note` (optional), `added_at`
- Intentionally has **no** foreign key to `contacts`. Do-not-engage people are dropped
  *before* any contact record exists — never stored as contacts, never categorised.
  Enforcement happens at ingestion (Packet 6); the table exists now so it's ready.

### contacts  (people who have messaged)
- `id`, `artist_id`, `name`
- `external_handle` (nullable — populated in step 6)
- `category` — one of: `new_enquiry`, `active_client`, `unfinished_piece`,
  `past_client`, `spam_junk`
- `created_at`, `updated_at`
- Note: `do_not_engage` is **not** a category here. It is the blocklist (see above).

### pieces  (a tattoo project, possibly multi-session)
- `id`, `artist_id`, `contact_id`
- `description`
- `status` — `in_progress` | `finished`
- `whats_left` — free text; what remains on the piece. Used only while `in_progress`;
  ignored / locked once `finished`. This is the artist's own notes box AND the
  unfinished signal.
- `created_at`, `updated_at`

### appointments  (one list, past + future, by status)
- `id`, `artist_id`, `contact_id`
- `piece_id` (nullable — not every appointment belongs to a multi-session piece)
- `status` — `done` | `booked` | `no_show` | `cancelled`
- `scheduled_at`
- `duration` (optional — helps Packet 5 utilisation reporting later)
- `created_at`, `updated_at`
- One list filtered by status, not separate past/future tables — easiest for the artist
  to work through, and Packet 5's no-show reporting wants the status anyway.

### deposits  (manual record — NOT a payment integration)
- `id`, `artist_id`, `appointment_id` (nullable)
- `amount`
- `confirmed_at` (null = unconfirmed), `confirmed_by`
- `method` — optional text (`bank` / `stripe` / `cash`). A *label* only, for the day a
  future artist takes money differently. No processing, no Stripe, no API. Sean confirms
  by eye.
- `created_at`

### enquiries  (stub now, filled in Packet 4)
- `id`, `artist_id`, `contact_id`, `created_at`
- Bare table so the foundation matches the spec and Packet 4 has somewhere to write.
  No tracking/conversion logic in this packet.

## Security — RLS (decision: real RLS now)
- RLS **enabled and enforced** on every table.
- Policies key on `artist_id` so an artist can only ever see their own rows.
- Tenant identity comes from a **JWT claim carrying the artist's `artist_id`** — no
  login/signup UI is built (that's deferred machinery). Sean is issued a token carrying
  his `artist_id`.
- Exact policy SQL and token-minting are written by Claude Code against the current
  Supabase auth/RLS docs — not hardcoded here, because that syntax moves and must be
  verified at build time. This doc states the requirement; the build makes it true.

## Definition of Done
- [ ] Migration creates all seven tables, each with `artist_id` and the enums above.
- [ ] RLS enabled and enforced; an artist sees only their own rows (verify with a
      second dummy artist_id that Sean's token cannot read).
- [ ] One seed `artists` row for Sean, so Packets 2–3 have something to run against.
- [ ] Migration lives in `src/db/`.
- [ ] Committed to a `task/` branch, not `main`.

## Out of scope (named, deferred — do NOT pull in)
- Login / signup / onboarding UI
- Billing
- Payment processing / Stripe / multiple payment-method flows
- Any Meta / Instagram / social ingestion (step 6)
- Backfilling Sean's existing client history → **separate future packet**, pending his
  answer to: "Do you have past clients/sessions in a calendar or spreadsheet I can
  export?" (Not via Instagram — that's step 6, regulated.)

## Decision trail (so the *why* survives)
- **Do-not-engage = separate blocklist**, checked at ingestion before storage. Resolves
  the CLAUDE.md contradiction (it was listed both as "never stored" and as a contact
  flag/category). It is not a contacts category.
- **Unfinished piece = explicit `status` + `whats_left` box**, not inferred from booking
  gaps alone. Sean roughly knows length up front but may finish early; an inferred-only
  flag would nag him forever after an early finish. Packet 2 combines the explicit
  `in_progress` status WITH "no future appointment" as the strongest signal.
- **One appointments list with status**, not past/future split — easiest for the artist.
- **Deposits manual**, with optional `method` label; no payment integration now.
- **enquiries** kept as a stub so the foundation matches build-order step 1's named
  schema ("clients, sessions, enquiries, deposits").
- **Real RLS via JWT claim** chosen over app-side filtering: smallest version of doing
  security properly, matches "multi-tenant from day one," done once.
