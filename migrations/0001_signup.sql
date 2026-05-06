CREATE TABLE IF NOT EXISTS subscribers (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  status TEXT NOT NULL DEFAULT 'subscribed',
  source TEXT NOT NULL DEFAULT 'site',
  page_referrer TEXT,
  user_agent TEXT,
  consent_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  resend_contact_id TEXT,
  resend_synced_at TEXT,
  sync_error TEXT
);

CREATE INDEX IF NOT EXISTS subscribers_status_idx
  ON subscribers(status);

CREATE INDEX IF NOT EXISTS subscribers_updated_at_idx
  ON subscribers(updated_at);

CREATE TABLE IF NOT EXISTS signup_events (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL COLLATE NOCASE,
  event_type TEXT NOT NULL,
  payload TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS signup_events_email_idx
  ON signup_events(email);

CREATE INDEX IF NOT EXISTS signup_events_created_at_idx
  ON signup_events(created_at);
