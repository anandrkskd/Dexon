-- Dexon database schema (v1)
--
-- Write-boundary convention enforced by application code (see proto/API
-- design docs), not DB grants, for this v1:
--   - API server:      writes users, api_keys, tiers (admin), and the
--                       initial insert of a vms row (status=pending).
--                       Never writes vms.status again after insert --
--                       deletes are relayed via a direct call to Fleet
--                       manager, not a DB write (see below).
--   - Scheduler:       writes vms.host_id, vms.status
--                       ('scheduled'/'provisioning'), and hosts rows.
--   - Fleet manager:   sole writer of vms.status once a VM leaves
--                       'pending'/'scheduled'/'provisioning'
--                       ('running'/'deleting'/'deleted'/'failed') and
--                       vms.failure_reason, plus hosts.last_heartbeat_at
--                       and hosts.available. Called by the Scheduler
--                       (create commands, needs placement) and directly
--                       by the API (delete requests -- no placement
--                       decision needed, so no reason to route through
--                       the Scheduler). Either caller only ever *invokes*
--                       Fleet manager; it alone writes the resulting
--                       status transition, preserving a single writer
--                       even with two callers.
--   - Agent:           never writes to this database directly.
--
-- Known asymmetry: creates stay fully decoupled (API only touches the
-- DB; Scheduler picks up independently) so a slow/down Scheduler just
-- delays pending requests. Deletes call Fleet manager synchronously, so
-- a down Fleet manager makes DELETE fail loudly rather than degrade.
-- Accepted tradeoff for v1 since delete has no decision to defer.

CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- for gen_random_uuid()

-- ---- Tiers & quota -------------------------------------------------------

CREATE TABLE tiers (
    name        TEXT PRIMARY KEY,           -- e.g. 'free', 'pro'
    max_vms     INTEGER NOT NULL CHECK (max_vms >= 0)
);

-- ---- Users & auth ----------------------------------------------------------

CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT NOT NULL UNIQUE,
    tier        TEXT NOT NULL REFERENCES tiers(name) DEFAULT 'free',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE api_keys (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_hash    TEXT NOT NULL UNIQUE,        -- store a hash, never the raw key
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at  TIMESTAMPTZ                  -- NULL = active
);

CREATE INDEX idx_api_keys_user_id ON api_keys(user_id) WHERE revoked_at IS NULL;

-- ---- Flavors ---------------------------------------------------------------

CREATE TABLE flavors (
    name        TEXT PRIMARY KEY,            -- e.g. 'small', 'medium', 'large'
    vcpus       INTEGER NOT NULL CHECK (vcpus > 0),
    memory_mb   INTEGER NOT NULL CHECK (memory_mb > 0),
    disk_gb     INTEGER NOT NULL CHECK (disk_gb > 0)
);

-- ---- Hosts -------------------------------------------------------------
-- Persisted so the fleet manager has a durable inventory across restarts,
-- rather than rebuilding capacity knowledge purely from re-registrations.

CREATE TABLE hosts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cpu_cores           INTEGER NOT NULL,
    memory_bytes        BIGINT NOT NULL,
    hyperthreading      BOOLEAN NOT NULL DEFAULT false,
    available           BOOLEAN NOT NULL DEFAULT false, -- false until registered/healthy
    last_heartbeat_at   TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---- VMs ---------------------------------------------------------------

CREATE TYPE vm_status AS ENUM (
    'pending', 'scheduled', 'provisioning', 'running', 'deleting', 'deleted', 'failed'
);

CREATE TABLE vms (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            TEXT,                     -- optional user label, not an identifier
    flavor          TEXT NOT NULL REFERENCES flavors(name),
    disk_image      TEXT NOT NULL,
    status          vm_status NOT NULL DEFAULT 'pending',
    failure_reason  TEXT,                     -- set only when status = 'failed'
    host_id         UUID REFERENCES hosts(id), -- internal only; never returned by the API
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_vms_user_id ON vms(user_id);
CREATE INDEX idx_vms_status ON vms(status);
CREATE INDEX idx_vms_host_id ON vms(host_id);

-- Enforce max_vms quota: count of this user's non-terminal VMs must stay
-- under their tier's limit. Checked in application code at request time
-- (see API design) -- this index just makes that check cheap.
CREATE INDEX idx_vms_user_active
    ON vms(user_id)
    WHERE status NOT IN ('deleted', 'failed');

-- ---- Notify wiring for the API <-> Scheduler handoff --------------------
-- API writes a vms row, then calls pg_notify('vm_pending', id::text).
-- Scheduler LISTENs on 'vm_pending' and also polls periodically as a
-- fallback (see design doc) in case a notification is ever missed.

CREATE OR REPLACE FUNCTION notify_vm_pending() RETURNS trigger AS $$
BEGIN
    IF NEW.status = 'pending' THEN
        PERFORM pg_notify('vm_pending', NEW.id::text);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_notify_vm_pending
    AFTER INSERT ON vms
    FOR EACH ROW
    EXECUTE FUNCTION notify_vm_pending();
