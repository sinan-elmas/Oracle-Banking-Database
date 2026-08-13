-- ============================================================================
-- Trigger : TRG_EXCHANGE_RATES_AUDIT
-- Project : Oracle Banking Database
-- Database: Oracle AI Database 26ai Enterprise Edition
-- Version : 23.26.1.0.0
-- Schema  : BANKING_DB
--
-- Purpose
--   Maintains update metadata for exchange-rate records.
--
-- Behavior
--   Sets UPDATED_AT before each update and assigns UPDATED_BY to the current
--   database user when no updater value is supplied.
--
-- Timing and Event
--   BEFORE UPDATE ON EXCHANGE_RATES FOR EACH ROW
--
-- Notes
--   * Preserves an explicitly supplied UPDATED_BY value.
--   * Does not perform transaction control.
-- ============================================================================

CREATE OR REPLACE TRIGGER trg_exchange_rates_audit 
BEFORE UPDATE ON exchange_rates
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSDATE;

    IF :NEW.updated_by IS NULL THEN
        :NEW.updated_by := USER;
    END IF;
END;

/
