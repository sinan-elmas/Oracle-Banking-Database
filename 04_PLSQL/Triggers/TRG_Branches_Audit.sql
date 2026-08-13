-- ============================================================================
-- Trigger : TRG_BRANCHES_AUDIT
-- Project : Oracle Banking Database
-- Database: Oracle AI Database 26ai Enterprise Edition
-- Version : 23.26.1.0.0
-- Schema  : BANKING_DB
--
-- Purpose
--   Maintains update metadata for branch records.
--
-- Behavior
--   Sets UPDATED_AT and UPDATED_BY before each branch update.
--
-- Timing and Event
--   BEFORE UPDATE ON BRANCHES FOR EACH ROW
--
-- Notes
--   * Uses the current database user for UPDATED_BY.
--   * Does not perform transaction control.
-- ============================================================================

CREATE OR REPLACE TRIGGER trg_branches_audit 
BEFORE UPDATE ON branches
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSDATE;
    :NEW.updated_by := USER;
END;

/
