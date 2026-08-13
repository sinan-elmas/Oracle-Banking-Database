-- ============================================================================
-- Trigger : TRG_ACCOUNTS_NO_DELETE
-- Project : Oracle Banking Database
-- Database: Oracle AI Database 26ai Enterprise Edition
-- Version : 23.26.1.0.0
-- Schema  : BANKING_DB
--
-- Purpose
--   Prevents physical deletion of account records.
--
-- Business Rule
--   Accounts must be closed through the account lifecycle process instead of
--   being removed from the database.
--
-- Timing and Event
--   BEFORE DELETE ON ACCOUNTS
--
-- Notes
--   * Raises application error -20701 when a DELETE is attempted.
--   * Does not perform transaction control.
-- ============================================================================

CREATE OR REPLACE TRIGGER trg_accounts_no_delete 
BEFORE DELETE ON accounts
BEGIN
    RAISE_APPLICATION_ERROR(
        -20701,
        'Account records cannot be deleted. Close the account instead.'
    );
END;

/
