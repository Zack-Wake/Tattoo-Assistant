# CLAUDE.md — Tattoo Studio Assistant

This file is read by Claude Code before any session begins. Keep it honest and up to date.

## Project
- **Name:** tattoo-studio-assistant (working name — rename when decided)
- **What it does:** An AI assistant for a tattoo artist that handles inbound enquiries from social media, books consultations and sessions, and surfaces recoverable revenue — unfinished multi-session pieces, lost deposits, no-shows, and clients due a rebook.
- **Owner:** Zack (building this as a productised service)
- **Pilot client:** Sean (one tattoo artist) — used to get the product right before onboarding anyone else
- **Long-term:** a multi-artist SaaS for tattoo artists; possibly other appointment-based trades far later
- **Status:** Active build — Phase 0, defining foundations. Nothing built yet.

## The Full Vision (recorded for context — NOT all built at once)
The system tracks and acts on six things:

1. **Unfinished multi-session pieces** — clients with one session on a big piece and no follow-up booked. Highest-value recoverable group: they already trust the artist and have sunk cost. Flag them and prompt a follow-up.
2. **Inquiry → deposit conversion + lead time** — where enquiries die before a paid deposit, and how slow the response is. Tells us whether to fix the top or the middle of the funnel.
3. **No-show / late-cancel rate** — split by deposit-protected vs not. Shows whether the deposit policy works and the cost of each empty chair-hour.
4. **Utilisation / dead time** — % of available hours booked and which days sit empty. "Too busy" needs triage; "lumpy" needs gap-filling.
5. **Rebooking rate + time-to-rebook** — client lifetime value, and whether the aftercare → next-piece loop exists or is pure luck.
6. **Source + seasonality** — where bookings come from and the predictable demand spikes (pre-summer, pre-Christmas) to pre-fill instead of react to.

## Architecture: Multi-Tenant from Day One
Built as a productised service, so the data model is multi-tenant from the start — cheap now, brutal to retrofit later.

- Every table carries an **`artist_id`**. All data belongs to exactly one artist.
- An **`artists`** config table holds per-artist settings: name, AI voice/tone profile, connected social account(s), deposit rules, working hours.
- **The AI voice is a config field, not hardcoded.** Changing an artist's voice = editing their row, not editing code.
- Use **Supabase Row Level Security** keyed on `artist_id` so no artist can ever see another's data.
- Each artist connects their OWN Instagram via OAuth; tokens stored against their `artist_id`. Meta app review happens ONCE (for the app), then each artist authorises it.

**Do NOT build yet:** self-serve signup, billing, admin dashboards. Build the multi-tenant foundation now; add onboarding/billing machinery only after the Sean pilot works end to end. Foundation first, machinery later.

## Contact Categories
Every person who messages (except those on the do-not-engage list) is sorted into one category. Sean can move anyone between categories, and can drop anyone into do-not-engage at any time.

- **Do-not-engage** — never read or reply. Messages dropped at ingestion. Manually controlled by Sean.
- **New enquiry** — first-time message, never booked. Top-of-funnel.
- **Active client** — booked or mid-piece.
- **Unfinished piece** — a session logged on a multi-session piece, no follow-up booked. Highest-value group (vision #1).
- **Past client** — finished, rebook candidate.
- **Spam / junk** — auto-ignore, no reply.

## Stack (DECISIONS TO CONFIRM — not final)
Proposed based on tools already in use. Confirm before building on them.

- **Dashboard / UI:** Next.js — artist-facing: see metrics, review AI-drafted replies, manage bookings
- **Database:** Supabase (Postgres) — clients, sessions, enquiries, deposits
- **AI replies:** Anthropic Claude API — drafts replies in each artist's voice. The voice/tone is a **per-artist config field** (a tone profile + sample replies), never hardcoded, so onboarding a new artist is a settings change, not a code change.
- **Bookings / calendar:** Google Calendar integration
- **Deposits / payments:** Stripe
- **Social media:** Meta (Instagram/Facebook) Messaging API — HARD constraint, see below

## Hard Constraints (read before designing anything)
- **Inbound-only. The assistant NEVER initiates contact.** It only ever responds to people who message Sean first (DM, story reply, or comment). This is the supported, sanctioned path under Meta's official Instagram Graph API. Cold/outbound automated messaging to people who haven't engaged is banned — do not design any feature that does it.
- **Do-not-engage list (privacy boundary):** the system keeps a list of people the assistant must NEVER read or reply to — friends, family, personal contacts, anyone Sean flags. Their incoming messages are dropped at ingestion: never stored, never passed to the AI. Check every sender against this list BEFORE any processing. Sean controls the list.
- **Contact categorisation:** every non-excluded inbound contact is auto-sorted into a category (see Contact Categories below). This drives what the assistant does with them.
- **Requirements for the social piece (build-order step 6):** official Instagram Graph API only (no scraping, no login simulation), a professional/business account linked to a Facebook Page, and Meta app review for messaging permissions.
- **24-hour window:** automated replies are only allowed within 24 hours of the person's last message. Outside it, hand off to Sean — do not auto-message.
- **Rate limit:** ~200 automated messages per hour per account (rolling 60-min window), shared across all connected tools. Do not design anything that could exceed this.
- **Default behaviour: the AI DRAFTS replies; Sean reviews and sends (or one-tap approves)** until he trusts it. Keeps his voice and keeps the account safe.

## Build Order (start tiny — earliest first, do not skip ahead)
1. **Data model first** — a clean, **multi-tenant** Supabase schema for clients, sessions, enquiries, deposits. Every table carries an **`artist_id`**; an **`artists`** config table holds per-artist voice + settings; Row Level Security keys on `artist_id`. Each contact record also carries a **category** and a **do-not-engage flag**. Everything else is a query over this.
2. **Unfinished-pieces report** — query for clients with a logged session on a multi-session piece and no future booking. Output a list. *(No social API needed. Biggest recoverable number — build it first.)*
3. **Follow-up message drafting** — for that list, Claude API drafts a personal "ready to finish your piece?" message the artist reviews and sends.
4. **Inquiry + deposit tracking** — log enquiries and whether they converted; surface conversion rate and response time.
5. **No-show / utilisation / rebooking reporting** — once booking data exists, these are all reports over it.
6. **Social media intake + reply drafting** — only after the above works manually. Inbound-only, filtered through the do-not-engage list at ingestion, then categorised, then a drafted reply for Sean to approve. The regulated, hardest piece. Last.

## Folder Structure
```
src/        → application code
src/db/     → Supabase schema + queries
src/ai/     → Claude API prompts + reply drafting
docs/       → decisions, architecture notes
scripts/    → utilities
```

## Git Rules
- One branch per task. Branch name: `task/[short-description]`
- No direct commits to `main`
- Every session ends with a commit or PR to the task branch

## Claude Code Rules
- Read this file before touching anything
- Work only on the task defined in the current packet
- Stop when the packet's Definition of Done is met — do not expand scope
- Do not modify files outside the packet's declared targets
- Do not pull the social media / Meta API piece into any packet before build-order step 6
- Produce a summary of what changed when done

## What Claude Code Must Not Do
- Do not change the stack without a new decision recorded in this file
- Do not assume fully-automated DMing is allowed — drafts for human approval only, for now
- Do not delete files without explicit instruction
- Do not invent conventions not defined here