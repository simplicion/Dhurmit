-- 003_member_password.sql
-- Adds password_hash to members table for member-assigned PIN / password authentication

ALTER TABLE members ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255) NULL;
