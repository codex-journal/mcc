CREATE TABLE IF NOT EXISTS mcc_events (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'planned',
  starts_at TEXT,
  ends_at TEXT,
  location_label TEXT,
  location_address TEXT,
  capacity INTEGER,
  description TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS mcc_events_status_idx
  ON mcc_events(status);

CREATE INDEX IF NOT EXISTS mcc_events_starts_at_idx
  ON mcc_events(starts_at);

INSERT INTO mcc_events (
  id,
  slug,
  title,
  status,
  starts_at,
  ends_at,
  location_label,
  location_address,
  capacity,
  description,
  created_at,
  updated_at
)
VALUES (
  'session-01',
  'first-session',
  'First session',
  'planned',
  '2026-06-25T23:00:00.000Z',
  NULL,
  'NYC',
  NULL,
  NULL,
  'First public Marx Compute Club session.',
  '2026-06-16T00:00:00.000Z',
  '2026-06-16T00:00:00.000Z'
)
ON CONFLICT(slug) DO UPDATE SET
  title = excluded.title,
  status = excluded.status,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at,
  location_label = excluded.location_label,
  location_address = excluded.location_address,
  capacity = excluded.capacity,
  description = excluded.description,
  updated_at = excluded.updated_at;

CREATE TABLE IF NOT EXISTS event_rsvps (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  email TEXT NOT NULL COLLATE NOCASE,
  name_handle TEXT,
  status TEXT NOT NULL DEFAULT 'rsvp',
  community_opt_in INTEGER NOT NULL DEFAULT 0 CHECK (community_opt_in IN (0, 1)),
  source TEXT NOT NULL DEFAULT 'event-page',
  consent_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  sync_error TEXT,
  FOREIGN KEY (event_id) REFERENCES mcc_events(id) ON DELETE CASCADE,
  UNIQUE(event_id, email)
);

CREATE INDEX IF NOT EXISTS event_rsvps_event_id_idx
  ON event_rsvps(event_id);

CREATE INDEX IF NOT EXISTS event_rsvps_email_idx
  ON event_rsvps(email);

CREATE INDEX IF NOT EXISTS event_rsvps_updated_at_idx
  ON event_rsvps(updated_at);

CREATE INDEX IF NOT EXISTS event_rsvps_community_opt_in_idx
  ON event_rsvps(community_opt_in, sync_status);
