-- Migration: 001_initial_schema
-- Multi-tenant tattoo studio assistant data model

-- ─────────────────────────────────────────────
-- Enums
-- ─────────────────────────────────────────────

CREATE TYPE contact_category AS ENUM (
  'new_enquiry',
  'active_client',
  'unfinished_piece',
  'past_client',
  'spam'
);

CREATE TYPE piece_status AS ENUM ('in_progress', 'complete', 'abandoned');

CREATE TYPE session_status AS ENUM (
  'pending',
  'confirmed',
  'completed',
  'no_show',
  'cancelled'
);

CREATE TYPE enquiry_source AS ENUM (
  'instagram_dm',
  'instagram_story_reply',
  'instagram_comment',
  'manual'
);

CREATE TYPE enquiry_status AS ENUM ('open', 'responded', 'converted', 'dropped');

CREATE TYPE deposit_status AS ENUM ('pending', 'received', 'forfeited', 'refunded');

CREATE TYPE message_direction AS ENUM ('inbound', 'outbound');

CREATE TYPE reply_status AS ENUM ('none', 'drafted', 'approved', 'sent');

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────
-- artists — multi-tenant root
-- id = auth.uid() so RLS collapses to a single equality check
-- ─────────────────────────────────────────────

CREATE TABLE artists (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name                 TEXT        NOT NULL,
  email                TEXT        UNIQUE NOT NULL,
  instagram_account_id TEXT,
  tone_profile         JSONB       NOT NULL DEFAULT '{}',
  deposit_rules        JSONB       NOT NULL DEFAULT '{"amount_pence": 5000, "non_refundable": true}',
  working_hours        JSONB       NOT NULL DEFAULT '{}',
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER artists_updated_at
  BEFORE UPDATE ON artists
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-create an artist row when a user signs up via Supabase Auth
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.artists (id, name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(COALESCE(NEW.email, ''), '@', 1)),
    COALESCE(NEW.email, NEW.id::text)
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ─────────────────────────────────────────────
-- contacts — people who message the artist
-- ─────────────────────────────────────────────

CREATE TABLE contacts (
  id                UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id         UUID             NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  instagram_user_id TEXT,
  name              TEXT,
  phone             TEXT,
  email             TEXT,
  category          contact_category NOT NULL DEFAULT 'new_enquiry',
  do_not_engage     BOOLEAN          NOT NULL DEFAULT FALSE,
  notes             TEXT,
  created_at        TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  UNIQUE (artist_id, instagram_user_id)
);

CREATE INDEX idx_contacts_artist   ON contacts(artist_id);
CREATE INDEX idx_contacts_category ON contacts(artist_id, category);
-- Partial index used by the do-not-engage filter at ingestion
CREATE INDEX idx_contacts_dne      ON contacts(artist_id) WHERE do_not_engage = FALSE;

CREATE TRIGGER contacts_updated_at
  BEFORE UPDATE ON contacts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────
-- pieces — tattoo pieces, drives multi-session tracking
-- ─────────────────────────────────────────────

CREATE TABLE pieces (
  id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id        UUID         NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  contact_id       UUID         NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  title            TEXT,
  description      TEXT,
  is_multi_session BOOLEAN      NOT NULL DEFAULT FALSE,
  status           piece_status NOT NULL DEFAULT 'in_progress',
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pieces_artist    ON pieces(artist_id);
CREATE INDEX idx_pieces_contact   ON pieces(contact_id);
-- Partial index for the unfinished-pieces report query
CREATE INDEX idx_pieces_unfinished ON pieces(artist_id)
  WHERE status = 'in_progress' AND is_multi_session = TRUE;

CREATE TRIGGER pieces_updated_at
  BEFORE UPDATE ON pieces
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────
-- sessions — bookings / appointments
-- ─────────────────────────────────────────────

CREATE TABLE sessions (
  id               UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id        UUID           NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  contact_id       UUID           NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  piece_id         UUID           REFERENCES pieces(id) ON DELETE SET NULL,
  scheduled_at     TIMESTAMPTZ    NOT NULL,
  duration_minutes INTEGER        NOT NULL DEFAULT 60,
  status           session_status NOT NULL DEFAULT 'pending',
  deposit_paid     BOOLEAN        NOT NULL DEFAULT FALSE,
  notes            TEXT,
  created_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_artist    ON sessions(artist_id);
CREATE INDEX idx_sessions_contact   ON sessions(contact_id);
CREATE INDEX idx_sessions_piece     ON sessions(piece_id);
CREATE INDEX idx_sessions_scheduled ON sessions(artist_id, scheduled_at);
CREATE INDEX idx_sessions_status    ON sessions(artist_id, status);

CREATE TRIGGER sessions_updated_at
  BEFORE UPDATE ON sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────
-- enquiries — inbound enquiry tracking
-- ─────────────────────────────────────────────

CREATE TABLE enquiries (
  id                      UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id               UUID           NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  contact_id              UUID           NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  source                  enquiry_source NOT NULL DEFAULT 'manual',
  message_text            TEXT,
  received_at             TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  status                  enquiry_status NOT NULL DEFAULT 'open',
  converted_to_session_id UUID           REFERENCES sessions(id) ON DELETE SET NULL,
  response_time_minutes   INTEGER,
  created_at              TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_enquiries_artist  ON enquiries(artist_id);
CREATE INDEX idx_enquiries_contact ON enquiries(contact_id);
CREATE INDEX idx_enquiries_status  ON enquiries(artist_id, status);

CREATE TRIGGER enquiries_updated_at
  BEFORE UPDATE ON enquiries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────
-- deposits
-- ─────────────────────────────────────────────

CREATE TABLE deposits (
  id           UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id    UUID           NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  contact_id   UUID           NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  session_id   UUID           REFERENCES sessions(id) ON DELETE SET NULL,
  amount_pence INTEGER        NOT NULL,
  status       deposit_status NOT NULL DEFAULT 'pending',
  received_at  TIMESTAMPTZ,
  notes        TEXT,
  created_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_deposits_artist  ON deposits(artist_id);
CREATE INDEX idx_deposits_session ON deposits(session_id);

CREATE TRIGGER deposits_updated_at
  BEFORE UPDATE ON deposits
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────
-- messages — social intake skeleton (Step 6, modelled now)
-- ─────────────────────────────────────────────

CREATE TABLE messages (
  id                   UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id            UUID              NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  contact_id           UUID              NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  instagram_message_id TEXT              UNIQUE,
  direction            message_direction NOT NULL,
  content              TEXT              NOT NULL,
  sent_at              TIMESTAMPTZ       NOT NULL,
  draft_reply          TEXT,
  reply_status         reply_status      NOT NULL DEFAULT 'none',
  created_at           TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_messages_artist  ON messages(artist_id);
CREATE INDEX idx_messages_contact ON messages(contact_id);
-- Partial index for the "pending approval" inbox
CREATE INDEX idx_messages_drafts  ON messages(artist_id) WHERE reply_status = 'drafted';

-- ─────────────────────────────────────────────
-- Row Level Security
-- Every artist sees exactly their own data. artist_id = auth.uid() on all tables.
-- ─────────────────────────────────────────────

ALTER TABLE artists   ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE pieces    ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE enquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE deposits  ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "artists_select_own" ON artists FOR SELECT USING (auth.uid() = id);
CREATE POLICY "artists_insert_own" ON artists FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "artists_update_own" ON artists FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "contacts_all_own"  ON contacts  USING (artist_id = auth.uid()) WITH CHECK (artist_id = auth.uid());
CREATE POLICY "pieces_all_own"    ON pieces    USING (artist_id = auth.uid()) WITH CHECK (artist_id = auth.uid());
CREATE POLICY "sessions_all_own"  ON sessions  USING (artist_id = auth.uid()) WITH CHECK (artist_id = auth.uid());
CREATE POLICY "enquiries_all_own" ON enquiries USING (artist_id = auth.uid()) WITH CHECK (artist_id = auth.uid());
CREATE POLICY "deposits_all_own"  ON deposits  USING (artist_id = auth.uid()) WITH CHECK (artist_id = auth.uid());
CREATE POLICY "messages_all_own"  ON messages  USING (artist_id = auth.uid()) WITH CHECK (artist_id = auth.uid());

-- ─────────────────────────────────────────────
-- unfinished_pieces view (Build Order Step 2)
-- security_invoker=on: RLS on the underlying tables still applies,
-- so each artist only ever sees their own rows.
--
-- A contact appears here when:
--   1. They have a multi-session piece still in_progress
--   2. That piece has at least one completed session
--   3. That piece has NO future confirmed/pending sessions
-- ─────────────────────────────────────────────

CREATE VIEW unfinished_pieces WITH (security_invoker = on) AS
SELECT
  c.id                AS contact_id,
  c.artist_id,
  c.name              AS contact_name,
  c.instagram_user_id,
  c.category,
  p.id                AS piece_id,
  p.title             AS piece_title,
  p.description       AS piece_description,
  COUNT(s.id)         AS sessions_completed,
  MAX(s.scheduled_at) AS last_session_at
FROM contacts c
JOIN pieces p
  ON  p.contact_id     = c.id
  AND p.is_multi_session = TRUE
  AND p.status           = 'in_progress'
JOIN sessions s
  ON  s.piece_id = p.id
  AND s.status   = 'completed'
WHERE c.do_not_engage = FALSE
  AND NOT EXISTS (
    SELECT 1
    FROM sessions s2
    WHERE s2.piece_id = p.id
      AND s2.scheduled_at > NOW()
      AND s2.status NOT IN ('cancelled', 'no_show')
  )
GROUP BY
  c.id, c.artist_id, c.name, c.instagram_user_id, c.category,
  p.id, p.title, p.description
ORDER BY last_session_at DESC;
