-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / PL/SQL Tests / Trigger Tests
-- Script       : 03_TRANSACTION_STATUS_HISTORY_TRIGGER_Test.sql
-- Purpose      : Validate transaction status-history capture for single-row,
--                unchanged-status, and multi-row UPDATE statements
-- Scope        : TRG_TRANSACTION_STATUS_HISTORY
-- Safety       : All transaction and history changes are rolled back
-- Environment  : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
SET VERIFY OFF
SET FEEDBACK ON
SET SQLBLANKLINES ON

WHENEVER SQLERROR CONTINUE

PROMPT
PROMPT ================================================================================
PROMPT TRANSACTION STATUS HISTORY TRIGGER - REGRESSION TEST SUITE
PROMPT ================================================================================
PROMPT

DECLARE
    ---------------------------------------------------------------------------
    -- Test transactions
    ---------------------------------------------------------------------------
    l_single_transaction_id  transactions.transaction_id%TYPE;
    l_single_old_status      transactions.status%TYPE;
    l_single_new_status      transactions.status%TYPE;

    l_multi_transaction_id_1 transactions.transaction_id%TYPE;
    l_multi_transaction_id_2 transactions.transaction_id%TYPE;
    l_multi_old_status       transactions.status%TYPE;
    l_multi_new_status       transactions.status%TYPE;

    ---------------------------------------------------------------------------
    -- History values
    ---------------------------------------------------------------------------
    l_history_old_status     transaction_status_history.old_status%TYPE;
    l_history_new_status     transaction_status_history.new_status%TYPE;
    l_history_changed_at     transaction_status_history.changed_at%TYPE;
    l_history_changed_by     transaction_status_history.changed_by%TYPE;
    l_history_group_id       transaction_status_history.change_group_id%TYPE;

    l_test_started_at        TIMESTAMP;
    l_count                  PLS_INTEGER;
    l_distinct_groups        PLS_INTEGER;
    l_pass_count             PLS_INTEGER := 0;
    l_fail_count             PLS_INTEGER := 0;

    ---------------------------------------------------------------------------
    -- Helpers
    ---------------------------------------------------------------------------
    FUNCTION different_status (
        p_current_status IN transactions.status%TYPE
    ) RETURN transactions.status%TYPE
    IS
    BEGIN
        RETURN CASE UPPER(TRIM(p_current_status))
                   WHEN 'SUCCESS' THEN 'FAILED'
                   WHEN 'FAILED'  THEN 'PENDING'
                   ELSE                'SUCCESS'
               END;
    END different_status;

    PROCEDURE record_result (
        p_test_name IN VARCHAR2,
        p_passed    IN BOOLEAN,
        p_details   IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        IF p_passed THEN
            l_pass_count := l_pass_count + 1;
            DBMS_OUTPUT.PUT_LINE('[PASS] ' || p_test_name);
        ELSE
            l_fail_count := l_fail_count + 1;
            DBMS_OUTPUT.PUT_LINE(
                '[FAIL] ' || p_test_name ||
                CASE
                    WHEN p_details IS NOT NULL THEN ' -> ' || p_details
                END
            );
        END IF;
    END record_result;

BEGIN
    SAVEPOINT suite_start;

    ---------------------------------------------------------------------------
    -- A. Trigger health
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- A. TRIGGER HEALTH ---');

    SELECT COUNT(*)
      INTO l_count
      FROM user_triggers
     WHERE trigger_name = 'TRG_TRANSACTION_STATUS_HISTORY'
       AND status = 'ENABLED';

    record_result(
        'Transaction status-history trigger is ENABLED',
        l_count = 1,
        'Expected=1, Actual=' || l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM user_objects
     WHERE object_name = 'TRG_TRANSACTION_STATUS_HISTORY'
       AND object_type = 'TRIGGER'
       AND status = 'VALID';

    record_result(
        'Transaction status-history trigger is VALID',
        l_count = 1,
        'Expected=1, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- Test preparation
    ---------------------------------------------------------------------------
    SELECT transaction_id,
           status
      INTO l_single_transaction_id,
           l_single_old_status
      FROM (
            SELECT transaction_id,
                   status
              FROM transactions
             WHERE status IN ('SUCCESS', 'FAILED', 'PENDING')
             ORDER BY transaction_id
           )
     WHERE ROWNUM = 1;

    l_single_new_status := different_status(l_single_old_status);

    SELECT transaction_id,
           status
      INTO l_multi_transaction_id_1,
           l_multi_old_status
      FROM (
            SELECT transaction_id,
                   status,
                   COUNT(*) OVER (PARTITION BY status) AS status_count
              FROM transactions
             WHERE status IN ('SUCCESS', 'FAILED', 'PENDING')
             ORDER BY status, transaction_id
           )
     WHERE status_count >= 2
       AND ROWNUM = 1;

    SELECT transaction_id
      INTO l_multi_transaction_id_2
      FROM (
            SELECT transaction_id
              FROM transactions
             WHERE status = l_multi_old_status
               AND transaction_id <> l_multi_transaction_id_1
             ORDER BY transaction_id
           )
     WHERE ROWNUM = 1;

    l_multi_new_status := different_status(l_multi_old_status);

    DBMS_OUTPUT.PUT_LINE(
        'Single-row transaction : ' || l_single_transaction_id ||
        ' (' || l_single_old_status || ' -> ' || l_single_new_status || ')'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Multi-row transactions : ' || l_multi_transaction_id_1 ||
        ', ' || l_multi_transaction_id_2 ||
        ' (' || l_multi_old_status || ' -> ' || l_multi_new_status || ')'
    );

    ---------------------------------------------------------------------------
    -- B. Single-row status change
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- B. SINGLE-ROW STATUS CHANGE ---');

    SAVEPOINT single_row_test;
    l_test_started_at := SYSTIMESTAMP;

    UPDATE transactions
       SET status = l_single_new_status
     WHERE transaction_id = l_single_transaction_id;

    SELECT COUNT(*)
      INTO l_count
      FROM transaction_status_history
     WHERE transaction_id = l_single_transaction_id
       AND old_status = l_single_old_status
       AND new_status = l_single_new_status
       AND changed_at >= l_test_started_at - INTERVAL '5' SECOND;

    record_result(
        'A real single-row status change creates one history row',
        l_count = 1,
        'Expected=1, Actual=' || l_count
    );

    SELECT old_status,
           new_status,
           changed_at,
           changed_by,
           change_group_id
      INTO l_history_old_status,
           l_history_new_status,
           l_history_changed_at,
           l_history_changed_by,
           l_history_group_id
      FROM transaction_status_history
     WHERE transaction_id = l_single_transaction_id
       AND old_status = l_single_old_status
       AND new_status = l_single_new_status
       AND changed_at >= l_test_started_at - INTERVAL '5' SECOND;

    record_result(
        'Single-row history stores OLD_STATUS and NEW_STATUS correctly',
        l_history_old_status = l_single_old_status
        AND l_history_new_status = l_single_new_status,
        'Old=' || NVL(l_history_old_status, 'NULL') ||
        ', New=' || NVL(l_history_new_status, 'NULL')
    );

    record_result(
        'Single-row history captures timestamp and database user',
        l_history_changed_at IS NOT NULL
        AND l_history_changed_by = USER,
        'Changed by=' || NVL(l_history_changed_by, 'NULL')
    );

    record_result(
        'Single-row history has a change-group identifier',
        l_history_group_id IS NOT NULL,
        'CHANGE_GROUP_ID is NULL'
    );

    ROLLBACK TO single_row_test;

    SELECT COUNT(*)
      INTO l_count
      FROM transaction_status_history
     WHERE transaction_id = l_single_transaction_id
       AND old_status = l_single_old_status
       AND new_status = l_single_new_status
       AND changed_at >= l_test_started_at - INTERVAL '5' SECOND;

    record_result(
        'Single-row history participates in caller rollback',
        l_count = 0,
        'Expected=0, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- C. Unchanged-status update
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- C. UNCHANGED-STATUS UPDATE ---');

    SAVEPOINT unchanged_status_test;
    l_test_started_at := SYSTIMESTAMP;

    UPDATE transactions
       SET status = status
     WHERE transaction_id = l_single_transaction_id;

    SELECT COUNT(*)
      INTO l_count
      FROM transaction_status_history
     WHERE transaction_id = l_single_transaction_id
       AND changed_at >= l_test_started_at - INTERVAL '5' SECOND;

    record_result(
        'Updating STATUS to the same value creates no history row',
        l_count = 0,
        'Expected=0, Actual=' || l_count
    );

    ROLLBACK TO unchanged_status_test;

    ---------------------------------------------------------------------------
    -- D. Multi-row status change
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- D. MULTI-ROW STATUS CHANGE ---');

    SAVEPOINT multi_row_test;
    l_test_started_at := SYSTIMESTAMP;

    UPDATE transactions
       SET status = l_multi_new_status
     WHERE transaction_id IN (
           l_multi_transaction_id_1,
           l_multi_transaction_id_2
       );

    SELECT COUNT(*),
           COUNT(DISTINCT change_group_id)
      INTO l_count,
           l_distinct_groups
      FROM transaction_status_history
     WHERE transaction_id IN (
           l_multi_transaction_id_1,
           l_multi_transaction_id_2
       )
       AND old_status = l_multi_old_status
       AND new_status = l_multi_new_status
       AND changed_at >= l_test_started_at - INTERVAL '5' SECOND;

    record_result(
        'One multi-row UPDATE creates one history row per changed transaction',
        l_count = 2,
        'Expected=2, Actual=' || l_count
    );

    record_result(
        'Rows changed by the same statement share one CHANGE_GROUP_ID',
        l_distinct_groups = 1,
        'Expected=1, Actual=' || l_distinct_groups
    );

    SELECT COUNT(*)
      INTO l_count
      FROM transaction_status_history
     WHERE transaction_id IN (
           l_multi_transaction_id_1,
           l_multi_transaction_id_2
       )
       AND old_status = l_multi_old_status
       AND new_status = l_multi_new_status
       AND changed_by = USER
       AND change_group_id IS NOT NULL
       AND changed_at >= l_test_started_at - INTERVAL '5' SECOND;

    record_result(
        'Both multi-row history records contain user and group metadata',
        l_count = 2,
        'Expected=2, Actual=' || l_count
    );

    ROLLBACK TO multi_row_test;

    SELECT COUNT(*)
      INTO l_count
      FROM transaction_status_history
     WHERE transaction_id IN (
           l_multi_transaction_id_1,
           l_multi_transaction_id_2
       )
       AND old_status = l_multi_old_status
       AND new_status = l_multi_new_status
       AND changed_at >= l_test_started_at - INTERVAL '5' SECOND;

    record_result(
        'Multi-row history participates in caller rollback',
        l_count = 0,
        'Expected=0, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- E. Final data verification
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- E. FINAL DATA VERIFICATION ---');

    ROLLBACK TO suite_start;

    SELECT COUNT(*)
      INTO l_count
      FROM transactions
     WHERE transaction_id = l_single_transaction_id
       AND status = l_single_old_status;

    record_result(
        'Single-row transaction status is restored',
        l_count = 1,
        'Expected=1, Actual=' || l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM transactions
     WHERE transaction_id IN (
           l_multi_transaction_id_1,
           l_multi_transaction_id_2
       )
       AND status = l_multi_old_status;

    record_result(
        'Both multi-row transaction statuses are restored',
        l_count = 2,
        'Expected=2, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- Final summary
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '================================================================================'
    );
    DBMS_OUTPUT.PUT_LINE('TRANSACTION STATUS HISTORY TRIGGER TEST SUMMARY');
    DBMS_OUTPUT.PUT_LINE(
        'PASSED=' || l_pass_count ||
        ' FAILED=' || l_fail_count ||
        ' TOTAL=' || (l_pass_count + l_fail_count)
    );

    IF l_fail_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=PASS');
    ELSE
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=FAIL');
    END IF;

    DBMS_OUTPUT.PUT_LINE(
        '================================================================================'
    );

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;

        l_fail_count := l_fail_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] Test preparation -> Required transaction rows were not found.'
        );
        DBMS_OUTPUT.PUT_LINE(
            'PASSED=' || l_pass_count ||
            ' FAILED=' || l_fail_count ||
            ' TOTAL=' || (l_pass_count + l_fail_count)
        );
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=FAIL');

    WHEN OTHERS THEN
        ROLLBACK;

        l_fail_count := l_fail_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] Unexpected suite-level error -> SQLCODE=' ||
            SQLCODE || ', SQLERRM=' || SQLERRM
        );
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        DBMS_OUTPUT.PUT_LINE(
            'PASSED=' || l_pass_count ||
            ' FAILED=' || l_fail_count ||
            ' TOTAL=' || (l_pass_count + l_fail_count)
        );
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=FAIL');
END;
/

PROMPT
PROMPT ================================================================================
PROMPT TRIGGER COMPILATION ERROR CHECK
PROMPT ================================================================================
PROMPT

COLUMN name     FORMAT A40
COLUMN type     FORMAT A20
COLUMN line     FORMAT 999,999
COLUMN position FORMAT 999,999
COLUMN text     FORMAT A120

SELECT
    name,
    type,
    line,
    position,
    text
FROM user_errors
WHERE name = 'TRG_TRANSACTION_STATUS_HISTORY'
ORDER BY sequence;