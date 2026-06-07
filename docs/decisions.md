# Architecture Decisions

## Stack choices (Phase 0, June 2026)

**Next.js 15 (App Router)**
Chosen because it's already in use and pairs cleanly with Supabase SSR. Server Components let us fetch data without an API layer for read-heavy dashboard pages. Server Actions handle mutations (e.g. generating draft messages) without separate endpoints.

**Supabase (Postgres + Auth + RLS)**
- Multi-tenant from day one: every table carries `artist_id`
- RLS policy: `artist_id = auth.uid()` — each artist is isolated at the database layer, not the application layer
- `artists.id = auth.uid()`: the artist's auth UUID is their artist ID. A trigger on `auth.users` auto-creates the `artists` row on signup, so the IDs are always in sync
- `security_invoker = on` on the `unfinished_pieces` view: the view respects the caller's RLS context, so it never leaks cross-tenant data

**Anthropic Claude API (claude-opus-4-8)**
The voice/tone is a **per-artist config field** (`tone_profile` JSONB on the `artists` table), never hardcoded. Changing an artist's voice = editing their row, not editing code. Draft generation is a Server Action so the API key never reaches the browser.

**Deposits: pence (integer)**
Monetary values stored as integers in the smallest unit (pence) to avoid floating-point errors. Display layer divides by 100.

---

## Build order decisions

**Why unfinished pieces first?**
The highest-value recoverable revenue group. Clients already trust the artist and have sunk cost; they just need a nudge. No social API needed for this step — just a database query and a draft message.

**Why model the `messages` table now if social intake is Step 6?**
Retrofitting the schema is painful. The table exists but is empty; the application ignores it until Step 6. Cheap now, saves a migration later.

**Why `do_not_engage` filter at the view/query level, not at RLS?**
RLS is the right place for access control (who can see what). `do_not_engage` is a business rule (never process these people) — it belongs in the query. The partial index on `contacts(artist_id) WHERE do_not_engage = FALSE` makes the filter free.

---

## Packet 1 correction (June 2026): schema rebuilt to match packet-1.md exactly

The schema above was built *before* `packet-1.md` (the formal spec for build-order step 1) was reviewed, and diverged from it in several ways. The migration in `src/db/migrations/001_initial_schema.sql` was rewritten from scratch to match the packet's Definition of Done. Key corrections, superseding the decisions above:

- **Tables renamed/restructured to the packet's exact 7**: `artists`, `blocklist` (new), `contacts`, `pieces`, `appointments` (was `sessions`), `deposits`, `enquiries`. The `messages` table was dropped — it belongs to step 6 (social intake), not this packet, and modelling it now was scope creep.
- **`do_not_engage` is now the separate `blocklist` table**, not a flag/category on `contacts`, and deliberately has *no* foreign key to `contacts` — blocked people are dropped at ingestion, before any contact record would ever exist.
- **`pieces.status`** is `in_progress | finished` with a free-text `whats_left` field (the artist's own notes box *and* the unfinished signal), replacing `is_multi_session`/`title`. Packet 2 will combine `status = 'in_progress'` with "no future appointment" as the actual unfinished-piece signal — `whats_left` alone is not it.
- **`appointments`** is one list filtered by `status` (`done | booked | no_show | cancelled`), not separate past/future tables — simplest for the artist to work through and what Packet 5's no-show reporting needs.
- **`deposits`** is a manual record (`amount`, `confirmed_at`/`confirmed_by`, optional `method` text label) — not a payment integration. Sean confirms by eye; `method` exists only so a future artist using Stripe/cash has somewhere to note it.
- **`enquiries` is a bare stub** (`id`, `artist_id`, `contact_id`, `created_at`) for this packet — conversion/response-time tracking is Packet 4.
- **RLS now keys on a JWT claim, not `auth.uid()`.** `artists.id` is no longer tied to `auth.users.id`; tenant identity comes from `app_metadata.artist_id` in the caller's JWT, read via a pinned-search-path helper `current_artist_id()`. This is what the packet specifies ("Sean is issued a token carrying his artist_id"), and — critically — it means **no login/signup UI is required for this packet** (the packet explicitly lists that as out of scope/deferred machinery).
- Verified isolation directly: simulated two different `artist_id` JWT claims against live rows and confirmed each could see only its own — per the packet's Definition of Done ("verify with a second dummy artist_id that Sean's token cannot read").

**Open issue this surfaces**: the login page, middleware, and auth callback route built in the first pass implement full Supabase Auth email/password sign-in keyed to `auth.uid()`. That UI is now both (a) architecturally incompatible with the JWT-claim RLS model, and (b) explicitly out of scope for this packet. It hasn't been removed — that's a call for Zack, not something to do unilaterally given "do not delete files without explicit instruction."
