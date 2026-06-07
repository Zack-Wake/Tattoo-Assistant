-- Migration: 001_initial_schema  (Packet 1 — multi-tenant data model)
-- Produces the data SHAPE and security model only. No features, no UI, no payment logic.
--
-- Tenant identity: artist_id arrives via a JWT claim (app_metadata.artist_id), NOT
-- Supabase Auth's auth.uid(). No login/signup UI is built here — that's deferred
-- machinery (see packet-1.md "Out of scope"). Sean is issued a token carrying his
-- artist_id directly (e.g. by setting his auth.users.raw_app_meta_data).

-- ─────────────────────────────────────────────
-- Enums
-- ─────────────────────────────────────────────

CREATE TYPE contact_category AS ENUM (
  'new_enquiry',
  'active_client',
  'unfinished_piece',
  'past_client',
  'spam_junk'
);

CREATE TYPE piece_status AS ENUM ('in_progress', 'finished');

CREATE TYPE appointment_status AS ENUM ('done', 'booked', 'no_show', 'cancelled');

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

-- search_path is pinned on both functions to close the "search_path mutable"
-- security lint (prevents search-path hijacking of unqualified references).
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Reads the artist_id carried in the caller's JWT app_metadata claim.
-- Returns NULL for service-role / unauthenticated contexts (RLS then denies all rows).
CREATE OR REPLACE FUNCTION current_artist_id()
RETURNS UUID
LANGUAGE SQL STABLE
SET search_path = ''
AS $$
  SELECT (auth.jwt() -> 'app_metadata' ->> 'artist_id')::uuid
$$;

-- ─────────────────────────────────────────────
-- artists — the tenant / config row. Voice is config, not code.
-- ─────────────────────────────────────────────

CREATE TABLE artists (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name               TEXT        NOT NULL,
  voice_tone_profile JSONB       NOT NULL DEFAULT '{}',
  working_hours      JSONB       NOT NULL DEFAULT '{}',
  deposit_rules      JSONB       NOT NULL DEFAULT '{}',
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- blocklist — the do-not-engage boundary.
-- Deliberately has NO foreign key to contacts: blocked people are dropped at
-- ingestion, before any contact record exists. Enforcement happens in Packet 6;
-- this table just needs to exist and be queryable now.
-- ─────────────────────────────────────────────

CREATE TABLE blocklist (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id  UUID        NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  identifier TEXT        NOT NULL,
  note       TEXT,
  added_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_blocklist_artist ON blocklist(artist_id);

-- ─────────────────────────────────────────────
-- contacts — people who have messaged. do_not_engage is NOT a category here
-- (that's the blocklist above) — it's a separate concern entirely.
-- ─────────────────────────────────────────────

CREATE TABLE contacts (
  id              UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id       UUID             NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  name            TEXT             NOT NULL,
  external_handle TEXT,
  category        contact_category NOT NULL DEFAULT 'new_enquiry',
  created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_contacts_artist   ON contacts(artist_id);
CREATE INDEX idx_contacts_category ON contacts(artist_id, category);

CREATE TRIGGER contacts_updated_at
  BEFORE UPDATE ON contacts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────
-- pieces — a tattoo project, possibly multi-session.
-- whats_left is the artist's own notes box AND the unfinished signal — used only
-- while in_progress. Packet 2 combines status='in_progress' with "no future
-- appointment" as the strongest unfinished-piece signal (not whats_left alone).
-- ─────────────────────────────────────────────

CREATE TABLE pieces (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id   UUID         NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  contact_id  UUID         NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  description TEXT,
  status      piece_status NOT NULL DEFAULT 'in_progress',
  whats_left  TEXT,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pieces_artist          ON pieces(artist_id);
CREATE INDEX idx_pieces_contact         ON pieces(contact_id);
CREATE INDEX idx_pieces_in_progress     ON pieces(artist_id) WHERE status = 'in_progress';

CREATE TRIGGER pieces_updated_at
  BEFORE UPDATE ON pieces
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────
-- appointments — one list, past + future, filtered by status.
-- Not split into separate past/future tables: easiest for the artist to work
-- through, and Packet 5's no-show reporting wants the status anyway.
-- ─────────────────────────────────────────────

CREATE TABLE appointments (
  id           UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id    UUID               NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  contact_id   UUID               NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  piece_id     UUID               REFERENCES pieces(id) ON DELETE SET NULL,
  status       appointment_status NOT NULL DEFAULT 'booked',
  scheduled_at TIMESTAMPTZ        NOT NULL,
  duration     INTERVAL,
  created_at   TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ        NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_appointments_artist    ON appointments(artist_id);
CREATE INDEX idx_appointments_contact   ON appointments(contact_id);
CREATE INDEX idx_appointments_piece     ON appointments(piece_id);
CREATE INDEX idx_appointments_scheduled ON appointments(artist_id, scheduled_at);
CREATE INDEX idx_appointments_status    ON appointments(artist_id, status);

CREATE TRIGGER appointments_updated_at
  BEFORE UPDATE ON appointments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────
-- deposits — manual record, NOT a payment integration. Sean confirms by eye.
-- method is a label only (bank / stripe / cash) for the day a future artist
-- takes money differently — no processing, no Stripe, no API.
-- ─────────────────────────────────────────────

CREATE TABLE deposits (
  id             UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id      UUID           NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  appointment_id UUID           REFERENCES appointments(id) ON DELETE SET NULL,
  amount         NUMERIC(10,2)  NOT NULL,
  confirmed_at   TIMESTAMPTZ,   -- null = unconfirmed
  confirmed_by   TEXT,
  method         TEXT,          -- free-text label: 'bank' / 'stripe' / 'cash' / ...
  created_at     TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_deposits_artist      ON deposits(artist_id);
CREATE INDEX idx_deposits_appointment ON deposits(appointment_id);

-- ─────────────────────────────────────────────
-- enquiries — bare stub so the foundation matches build-order step 1's named
-- schema. Filled in by Packet 4. No tracking/conversion logic here.
-- ─────────────────────────────────────────────

CREATE TABLE enquiries (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id  UUID        NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  contact_id UUID        NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_enquiries_artist ON enquiries(artist_id);

-- ─────────────────────────────────────────────
-- Row Level Security — real RLS, enforced now.
-- Every policy keys on artist_id = current_artist_id() (the JWT app_metadata claim),
-- so an artist can only ever see/write their own rows.
-- ─────────────────────────────────────────────

ALTER TABLE artists      ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocklist    ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE pieces       ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE deposits     ENABLE ROW LEVEL SECURITY;
ALTER TABLE enquiries    ENABLE ROW LEVEL SECURITY;

CREATE POLICY "artists_tenant_isolation" ON artists
  USING (id = current_artist_id()) WITH CHECK (id = current_artist_id());

CREATE POLICY "blocklist_tenant_isolation" ON blocklist
  USING (artist_id = current_artist_id()) WITH CHECK (artist_id = current_artist_id());

CREATE POLICY "contacts_tenant_isolation" ON contacts
  USING (artist_id = current_artist_id()) WITH CHECK (artist_id = current_artist_id());

CREATE POLICY "pieces_tenant_isolation" ON pieces
  USING (artist_id = current_artist_id()) WITH CHECK (artist_id = current_artist_id());

CREATE POLICY "appointments_tenant_isolation" ON appointments
  USING (artist_id = current_artist_id()) WITH CHECK (artist_id = current_artist_id());

CREATE POLICY "deposits_tenant_isolation" ON deposits
  USING (artist_id = current_artist_id()) WITH CHECK (artist_id = current_artist_id());

CREATE POLICY "enquiries_tenant_isolation" ON enquiries
  USING (artist_id = current_artist_id()) WITH CHECK (artist_id = current_artist_id());

-- ─────────────────────────────────────────────
-- Seed: one artists row for Sean so Packets 2-3 have something to run against.
-- PLACEHOLDER — update name/config once Sean's details are confirmed.
-- ─────────────────────────────────────────────

INSERT INTO artists (name, voice_tone_profile, working_hours, deposit_rules)
VALUES ('Sean', '{}', '{}', '{}');
