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
