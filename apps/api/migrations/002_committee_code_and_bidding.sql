-- 002_committee_code_and_bidding.sql
-- Adds 8-character unique committee join code, member user linking, user type, and chit fund bidding rounds/bids

-- 1. Add unique 8-character join code to committees
ALTER TABLE committees ADD COLUMN IF NOT EXISTS code VARCHAR(8);

-- Backfill existing committees with unique 8-char alphanumeric codes if null
UPDATE committees 
SET code = UPPER(SUBSTRING(MD5(id::text || name) FROM 1 FOR 8))
WHERE code IS NULL;

ALTER TABLE committees ALTER COLUMN code SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_committees_code ON committees(code);

-- 2. Add user_id reference to members table to link registered app users with member profiles
ALTER TABLE members ADD COLUMN IF NOT EXISTS user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_members_user_id ON members(user_id);
CREATE INDEX IF NOT EXISTS idx_members_phone ON members(phone);

-- 3. Add user_type to users ('ORGANIZER' or 'MEMBER')
ALTER TABLE users ADD COLUMN IF NOT EXISTS user_type TEXT NOT NULL DEFAULT 'ORGANIZER';

-- 4. Bidding Rounds (Release Bets / Committee Auctions)
CREATE TABLE IF NOT EXISTS bidding_rounds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    committee_id UUID NOT NULL REFERENCES committees(id) ON DELETE CASCADE,
    round_number INTEGER NOT NULL,
    round_date DATE NOT NULL,
    total_pot_minor BIGINT NOT NULL CHECK (total_pot_minor > 0),
    min_bid_minor BIGINT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED', 'AWARDED', 'CANCELLED')),
    winner_member_id UUID NULL REFERENCES members(id) ON DELETE SET NULL,
    winning_bid_minor BIGINT NULL,
    net_payout_minor BIGINT NULL,
    awarded_at TIMESTAMPTZ NULL,
    notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (committee_id, round_number)
);

CREATE INDEX IF NOT EXISTS idx_bidding_rounds_committee ON bidding_rounds(committee_id, round_date ASC);

-- 5. Member Bids
CREATE TABLE IF NOT EXISTS bids (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    round_id UUID NOT NULL REFERENCES bidding_rounds(id) ON DELETE CASCADE,
    committee_id UUID NOT NULL REFERENCES committees(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    bid_amount_minor BIGINT NOT NULL CHECK (bid_amount_minor >= 0),
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'WITHDRAWN', 'WINNING')),
    notes TEXT NULL
);

CREATE INDEX IF NOT EXISTS idx_bids_round_amount ON bids(round_id, bid_amount_minor DESC);
CREATE INDEX IF NOT EXISTS idx_bids_member ON bids(member_id);
