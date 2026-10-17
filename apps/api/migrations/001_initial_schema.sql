-- 001_initial_schema.sql
-- Migration: Initial Schema for Committee Ledger

-- 1. Users
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    display_name TEXT NOT NULL,
    email TEXT NULL UNIQUE,
    phone_e164 TEXT NULL UNIQUE,
    password_hash TEXT NULL,
    auth_subject TEXT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Workspaces
CREATE TABLE IF NOT EXISTS workspaces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Workspace Memberships
CREATE TABLE IF NOT EXISTS workspace_memberships (
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('OWNER', 'ADMIN', 'COLLECTOR', 'VIEWER')),
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (workspace_id, user_id)
);

-- 4. Committees
CREATE TABLE IF NOT EXISTS committees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('DRAFT', 'ACTIVE', 'COMPLETED', 'ARCHIVED')) DEFAULT 'DRAFT',
    currency_code CHAR(3) NOT NULL DEFAULT 'NPR',
    timezone TEXT NOT NULL DEFAULT 'Asia/Kathmandu',
    start_date DATE NOT NULL,
    end_date DATE NULL,
    duration_count INTEGER NOT NULL CHECK (duration_count > 0),
    duration_unit TEXT NOT NULL CHECK (duration_unit IN ('DAY', 'MONTH')),
    frequency TEXT NOT NULL CHECK (frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'CUSTOM')),
    contribution_amount_minor BIGINT NOT NULL CHECK (contribution_amount_minor > 0),
    schedule_rule JSONB NOT NULL DEFAULT '{}'::jsonb,
    allocation_policy TEXT NOT NULL DEFAULT 'FIFO' CHECK (allocation_policy IN ('FIFO', 'MANUAL')),
    allow_partial_payment BOOLEAN NOT NULL DEFAULT false,
    allow_unallocated_credit BOOLEAN NOT NULL DEFAULT false,
    config_version INTEGER NOT NULL DEFAULT 1,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_committees_workspace_id ON committees(workspace_id);

-- 5. Committee Configuration Versions
CREATE TABLE IF NOT EXISTS committee_config_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    committee_id UUID NOT NULL REFERENCES committees(id) ON DELETE CASCADE,
    version INTEGER NOT NULL,
    config_snapshot JSONB NOT NULL,
    effective_from DATE NOT NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (committee_id, version)
);

-- 6. Members
CREATE TABLE IF NOT EXISTS members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
    display_name TEXT NOT NULL,
    phone TEXT NULL,
    external_reference TEXT NULL,
    notes TEXT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'ARCHIVED')),
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_members_workspace_status ON members(workspace_id, status);

-- 7. Committee Members
CREATE TABLE IF NOT EXISTS committee_members (
    committee_id UUID NOT NULL REFERENCES committees(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES members(id) ON DELETE RESTRICT,
    membership_status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (membership_status IN ('ACTIVE', 'INACTIVE')),
    joined_at DATE NOT NULL,
    left_at DATE NULL,
    member_config JSONB NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY (committee_id, member_id)
);

-- 8. Obligations
CREATE TABLE IF NOT EXISTS obligations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
    committee_id UUID NOT NULL REFERENCES committees(id) ON DELETE RESTRICT,
    member_id UUID NOT NULL REFERENCES members(id) ON DELETE RESTRICT,
    due_date DATE NOT NULL,
    due_amount_minor BIGINT NOT NULL CHECK (due_amount_minor >= 0),
    currency_code CHAR(3) NOT NULL DEFAULT 'NPR',
    schedule_version INTEGER NOT NULL DEFAULT 1,
    status_cache TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (committee_id, member_id, due_date)
);

CREATE INDEX IF NOT EXISTS idx_obligations_committee_due_date ON obligations(committee_id, due_date);
CREATE INDEX IF NOT EXISTS idx_obligations_committee_member_due ON obligations(committee_id, member_id, due_date);
CREATE INDEX IF NOT EXISTS idx_obligations_workspace ON obligations(workspace_id);

-- 9. Collections
CREATE TABLE IF NOT EXISTS collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
    committee_id UUID NOT NULL REFERENCES committees(id) ON DELETE RESTRICT,
    member_id UUID NOT NULL REFERENCES members(id) ON DELETE RESTRICT,
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
    currency_code CHAR(3) NOT NULL DEFAULT 'NPR',
    received_at TIMESTAMPTZ NOT NULL,
    method_label TEXT NULL,
    reference TEXT NULL,
    note TEXT NULL,
    recorded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reversal_status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (reversal_status IN ('ACTIVE', 'REVERSED'))
);

CREATE INDEX IF NOT EXISTS idx_collections_member_received ON collections(member_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_collections_committee_received ON collections(committee_id, received_at DESC);

-- 10. Collection Allocations
CREATE TABLE IF NOT EXISTS collection_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
    collection_id UUID NOT NULL REFERENCES collections(id) ON DELETE RESTRICT,
    obligation_id UUID NOT NULL REFERENCES obligations(id) ON DELETE RESTRICT,
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_allocations_collection ON collection_allocations(collection_id);
CREATE INDEX IF NOT EXISTS idx_allocations_obligation ON collection_allocations(obligation_id);

-- 11. Ledger Adjustments & Reversals
CREATE TABLE IF NOT EXISTS ledger_adjustments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
    committee_id UUID NOT NULL REFERENCES committees(id) ON DELETE RESTRICT,
    member_id UUID NOT NULL REFERENCES members(id) ON DELETE RESTRICT,
    obligation_id UUID NULL REFERENCES obligations(id) ON DELETE RESTRICT,
    collection_id UUID NULL REFERENCES collections(id) ON DELETE RESTRICT,
    adjustment_type TEXT NOT NULL CHECK (adjustment_type IN ('REVERSAL', 'CREDIT', 'DEBIT', 'WAIVE')),
    amount_minor BIGINT NOT NULL,
    reason TEXT NOT NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. Idempotency Records
CREATE TABLE IF NOT EXISTS idempotency_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    idempotency_key TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    response_status INTEGER NOT NULL,
    response_body JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (workspace_id, actor_id, idempotency_key)
);

-- 13. Audit Events
CREATE TABLE IF NOT EXISTS audit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
    actor_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    reason TEXT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_workspace_created ON audit_events(workspace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_events(entity_type, entity_id);
