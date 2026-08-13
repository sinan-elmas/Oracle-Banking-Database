-- ============================================================================
-- Trigger : TRG_TRANSACTION_STATUS_HISTORY
-- Project : Oracle Banking Database
-- Database: Oracle AI Database 26ai Enterprise Edition
-- Version : 23.26.1.0.0
-- Schema  : BANKING_DB
--
-- Purpose
--   Preserves transaction status changes in a dedicated history table.
--
-- Behavior
--   Collects changed rows during an UPDATE statement and writes the history
--   records in bulk after the statement completes. All rows changed by the
--   same statement share a common change-group identifier.
--
-- Timing and Event
--   COMPOUND TRIGGER FOR UPDATE OF STATUS ON TRANSACTIONS
--
-- Implementation Notes
--   * Ignores updates that do not change the status value.
--   * Uses FORALL for bulk insertion.
--   * History records participate in the caller's transaction.
--
-- Dependency
--   * TRANSACTION_STATUS_HISTORY
-- ============================================================================

CREATE OR REPLACE TRIGGER trg_transaction_status_history 
FOR UPDATE OF status ON transactions
COMPOUND TRIGGER

    TYPE t_history_record IS RECORD (
        transaction_id  transaction_status_history.transaction_id%TYPE,
        old_status      transaction_status_history.old_status%TYPE,
        new_status      transaction_status_history.new_status%TYPE,
        changed_at      transaction_status_history.changed_at%TYPE,
        changed_by      transaction_status_history.changed_by%TYPE,
        change_group_id transaction_status_history.change_group_id%TYPE
    );

    TYPE t_history_table IS TABLE OF t_history_record
        INDEX BY PLS_INTEGER;

    g_history_rows    t_history_table;
    g_row_count       PLS_INTEGER := 0;
    g_change_group_id transaction_status_history.change_group_id%TYPE;

    BEFORE STATEMENT IS
    BEGIN
        g_change_group_id := RAWTOHEX(SYS_GUID());
    END BEFORE STATEMENT;

    AFTER EACH ROW IS
    BEGIN
        IF NVL(:OLD.status, CHR(0)) <> NVL(:NEW.status, CHR(0)) THEN
            g_row_count := g_row_count + 1;

            g_history_rows(g_row_count).transaction_id  := :NEW.transaction_id;
            g_history_rows(g_row_count).old_status      := :OLD.status;
            g_history_rows(g_row_count).new_status      := :NEW.status;
            g_history_rows(g_row_count).changed_at      := SYSTIMESTAMP;
            g_history_rows(g_row_count).changed_by      := USER;
            g_history_rows(g_row_count).change_group_id := g_change_group_id;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        IF g_row_count > 0 THEN
            FORALL i IN INDICES OF g_history_rows
                INSERT INTO transaction_status_history (
                    transaction_id,
                    old_status,
                    new_status,
                    changed_at,
                    changed_by,
                    change_group_id
                )
                VALUES (
                    g_history_rows(i).transaction_id,
                    g_history_rows(i).old_status,
                    g_history_rows(i).new_status,
                    g_history_rows(i).changed_at,
                    g_history_rows(i).changed_by,
                    g_history_rows(i).change_group_id
                );
        END IF;
    END AFTER STATEMENT;

END trg_transaction_status_history;

/
