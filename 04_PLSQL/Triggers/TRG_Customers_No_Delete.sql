-- ============================================================================
-- Trigger : TRG_CUSTOMERS_NO_DELETE
-- Project : Oracle Banking Database
-- Database: Oracle AI Database 26ai Enterprise Edition
-- Version : 23.26.1.0.0
-- Schema  : BANKING_DB
--
-- Purpose
--   Prevents physical deletion of customer records.
--
-- Business Rule
--   Customer history must be retained. Customer records should be deactivated
--   through a status change instead of being deleted.
--
-- Timing and Event
--   BEFORE DELETE ON CUSTOMERS
--
-- Notes
--   * Raises application error -20700 when a DELETE is attempted.
--   * Does not perform transaction control.
-- ============================================================================

CREATE OR REPLACE TRIGGER trg_customers_no_delete 
BEFORE DELETE ON customers
BEGIN
    RAISE_APPLICATION_ERROR(
        -20700,
        'Customer records cannot be deleted. Update the customer status instead.'
    );
END;

/
