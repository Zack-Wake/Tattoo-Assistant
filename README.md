# Tattoo-Assistant
# Tattoo Studio Assistant

An inbound AI assistant for tattoo artists. It replies to people who message the artist first, books consultations for desgins, and sessions, and surfaces recoverable revenue the artist would otherwise lose.

## What it is
A productised service (multi-tenant from day one). **Sean** is the pilot artist used to get the product right before onboarding others. Long-term: a multi-artist Saas that is posing as a productised service to increase profits, possibly other appointment-based trades later.

## The problem it solves
Tattoo artists leak revenue they could recover: half-finished multi-session pieces with no follow-up, enquiries that never convert to a deposit, no-shows, and clients who never get rebooked. Nobody chases these. This system finds them and acts on them.

## What it does
1. **Unfinished pieces** — flags clients with a session logged on a big piece and no follow-up booked (highest-value group).
2. **Inquiry → deposit conversion** — shows where enquiries die and how slow responses are.
3. **No-shows / late cancels** — split by deposit-protected vs not.
4. **Utilisation** — % of hours booked, which days sit empty.
5. **Rebooking** — rate and time-to-rebook per client.
6. **Source & seasonality** — where bookings come from, when demand spikes.

Replies are **inbound-only** and **drafted for the artist to approve** — the assistant never cold-messages anyone, and never reads or replies to people on the artist's do-not-engage list.

## Status
**Phase 0 — foundations.** Nothing built yet. First build is the multi-tenant data model.

## Stack (proposed — not final)
- Dashboard: Next.js
- Database: Supabase (Postgres) + Row Level Security
- AI replies: Anthropic Claude API (voice is per-artist config)
- Calendar: Google Calendar
- Payments / deposits: Stripe
- Social: Meta Instagram Graph API (official API only)

## Structure
```
src/        application code
src/db/     Supabase schema + queries
src/ai/     Claude prompts + reply drafting
docs/       decisions, architecture notes
scripts/    utilities
```

## Build rules
See **CLAUDE.md** for the build order, constraints (Meta API limits, do-not-engage filtering), and the rules Claude Code follows in this repo.