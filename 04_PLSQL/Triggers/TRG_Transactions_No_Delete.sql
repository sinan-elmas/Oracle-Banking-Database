-- ============================================================================
-- Trigger : TRG_TRANSACTIONS_NO_DELETE
-- Project : Oracle Banking Database
-- Database: Oracle AI Database 26ai Enterprise Edition
-- Version : 23.26.1.0.0
-- Schema  : BANKING_DB
--
-- Purpose
--   Prevents physical deletion of transaction records.
--
-- Business Rule
--   Transaction history must remain immutable for operational and audit
--   traceability.
--
-- Timing and Event
--   BEFORE DELETE ON TRANSACTIONS
--
-- Notes
--   * Raises application error -20702 when a DELETE is attempted.
--   * Does not perform transaction control.
-- ============================================================================

CREATE OR REPLACE TRIGGER trg_transactions_no_delete 
BEFORE DELETE ON transactions
BEGIN
    RAISE_APPLICATION_ERROR(
        -20702,
        'Transaction records cannot be deleted.'
    );
END;

/
