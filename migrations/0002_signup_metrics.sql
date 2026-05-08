CREATE TABLE IF NOT EXISTS signup_metric_rollups (
  day TEXT NOT NULL,
  event_type TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'site',
  count INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (day, event_type, source)
);

CREATE INDEX IF NOT EXISTS signup_metric_rollups_day_idx
  ON signup_metric_rollups(day);

CREATE INDEX IF NOT EXISTS signup_metric_rollups_event_type_idx
  ON signup_metric_rollups(event_type);
