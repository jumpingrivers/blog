-- Production version of the audit table (the app's SQLite file is for the
-- demo). Not run by the test suite; checked by hand on Postgres 16, where the
-- app's role can insert and read, and UPDATE, DELETE and TRUNCATE are refused.
CREATE TABLE audit (
  id BIGSERIAL PRIMARY KEY,
  ts TEXT NOT NULL,
  "user" TEXT NOT NULL,
  conversation TEXT NOT NULL,
  event TEXT NOT NULL,
  tool TEXT,
  input TEXT,
  output TEXT,
  model TEXT,
  prompt_hash TEXT,
  app_version TEXT,
  -- UNIQUE: two rows can never chain onto the same parent.
  prev_hash TEXT NOT NULL UNIQUE,
  row_hash TEXT NOT NULL
);
-- No foreign keys, so deleting anything else can never cascade into the log.

-- Under Postgres's default isolation two writers (the app and the MCP server)
-- can read the same head. Serialise appends: begin each append's transaction
-- with SELECT pg_advisory_xact_lock(4711); before reading the head. The
-- UNIQUE constraint above turns a missed lock into an error, not a fork.

-- The app connects as trial_app, which can add and read rows, nothing else.
-- Give it a password (ALTER ROLE trial_app PASSWORD ...) or your platform's
-- own authentication.
CREATE ROLE trial_app LOGIN;
GRANT INSERT, SELECT ON audit TO trial_app;
GRANT USAGE ON SEQUENCE audit_id_seq TO trial_app;
REVOKE UPDATE, DELETE, TRUNCATE ON audit FROM trial_app;
