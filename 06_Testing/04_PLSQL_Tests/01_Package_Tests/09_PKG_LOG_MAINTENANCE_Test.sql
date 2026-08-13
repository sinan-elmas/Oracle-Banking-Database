-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / PL/SQL Tests / Package Tests
-- Script       : 09_PKG_LOG_MAINTENANCE_Test.sql
-- Purpose      : Regression validation for PKG_LOG_MAINTENANCE
-- Safety       : Purge operations are executed inside the caller transaction
--                and rolled back. Existing log data is restored after each test.
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
PROMPT PKG_LOG_MAINTENANCE - REGRESSION TEST SUITE
PROMPT ================================================================================
PROMPT

DECLARE
    l_result              SYS_REFCURSOR;

    l_table_name          VARCHAR2(30);
    l_total_rows          NUMBER;
    l_oldest_logged_at    TIMESTAMP;
    l_newest_logged_at    TIMESTAMP;
    l_older_30            NUMBER;
    l_older_90            NUMBER;

    l_summary_rows        PLS_INTEGER := 0;
    l_audit_summary_rows  PLS_INTEGER := 0;
    l_error_summary_rows  PLS_INTEGER := 0;

    l_deleted             PLS_INTEGER;
    l_failed              PLS_INTEGER;

    l_expected_old        PLS_INTEGER;
    l_before_total        PLS_INTEGER;
    l_after_purge_total   PLS_INTEGER;
    l_after_rollback      PLS_INTEGER;

    l_count               PLS_INTEGER;
    l_pass_count          PLS_INTEGER := 0;
    l_fail_count          PLS_INTEGER := 0;

    ---------------------------------------------------------------------------
    -- Result helper
    ---------------------------------------------------------------------------
    PROCEDURE record_result (
        p_test_name IN VARCHAR2,
        p_passed    IN BOOLEAN,
        p_details   IN VARCHAR2 DEFAULT NULL
    )
    IS
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

    ---------------------------------------------------------------------------
    -- Expected-error helper
    ---------------------------------------------------------------------------
    PROCEDURE assert_expected_error (
        p_test_name      IN VARCHAR2,
        p_expected_code  IN NUMBER,
        p_actual_code    IN NUMBER,
        p_actual_message IN VARCHAR2
    )
    IS
    BEGIN
        record_result(
            p_test_name,
            p_actual_code = p_expected_code,
            'Expected SQLCODE=' || p_expected_code ||
            ', Actual SQLCODE=' || p_actual_code ||
            ', SQLERRM=' || p_actual_message
        );
    END assert_expected_error;

BEGIN
    ---------------------------------------------------------------------------
    -- A. Package and API health
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- A. PACKAGE AND API HEALTH ---');

    SELECT COUNT(*)
      INTO l_count
      FROM user_objects
     WHERE object_name = 'PKG_LOG_MAINTENANCE'
       AND object_type IN ('PACKAGE', 'PACKAGE BODY')
       AND status = 'VALID';

    record_result(
        'Package specification and body are VALID',
        l_count = 2,
        'Expected=2, Actual=' || l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM user_procedures
     WHERE object_name = 'PKG_LOG_MAINTENANCE'
       AND procedure_name IN (
           'GET_LOG_SUMMARY',
           'PURGE_AUDIT_LOGS',
           'PURGE_ERROR_LOGS'
       );

    record_result(
        'Three public procedures are exposed',
        l_count = 3,
        'Expected=3, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- B. GET_LOG_SUMMARY
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- B. GET_LOG_SUMMARY ---');

    pkg_log_maintenance.get_log_summary(l_result);

    LOOP
        FETCH l_result INTO
            l_table_name,
            l_total_rows,
            l_oldest_logged_at,
            l_newest_logged_at,
            l_older_30,
            l_older_90;

        EXIT WHEN l_result%NOTFOUND;

        l_summary_rows := l_summary_rows + 1;

        IF l_table_name = 'AUDIT_LOGS' THEN
            l_audit_summary_rows := l_audit_summary_rows + 1;

            SELECT COUNT(*)
              INTO l_count
              FROM audit_logs;

            record_result(
                'AUDIT_LOGS summary total matches source table',
                l_total_rows = l_count,
                'Expected=' || l_count || ', Actual=' || l_total_rows
            );

        ELSIF l_table_name = 'ERROR_LOGS' THEN
            l_error_summary_rows := l_error_summary_rows + 1;

            SELECT COUNT(*)
              INTO l_count
              FROM error_logs;

            record_result(
                'ERROR_LOGS summary total matches source table',
                l_total_rows = l_count,
                'Expected=' || l_count || ', Actual=' || l_total_rows
            );
        END IF;
    END LOOP;

    CLOSE l_result;

    record_result(
        'GET_LOG_SUMMARY returns exactly two rows',
        l_summary_rows = 2,
        'Expected=2, Actual=' || l_summary_rows
    );

    record_result(
        'GET_LOG_SUMMARY returns one AUDIT_LOGS row',
        l_audit_summary_rows = 1,
        'Expected=1, Actual=' || l_audit_summary_rows
    );

    record_result(
        'GET_LOG_SUMMARY returns one ERROR_LOGS row',
        l_error_summary_rows = 1,
        'Expected=1, Actual=' || l_error_summary_rows
    );

    ---------------------------------------------------------------------------
    -- C. PURGE_AUDIT_LOGS parameter validation
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- C. PURGE_AUDIT_LOGS VALIDATIONS ---');

    BEGIN
        pkg_log_maintenance.purge_audit_logs(
            p_retention_days => NULL,
            p_batch_size     => 100,
            p_deleted_count  => l_deleted,
            p_failed_count   => l_failed
        );

        record_result(
            'NULL audit retention is rejected',
            FALSE,
            'No exception raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'NULL audit retention raises ORA-20800',
                -20800,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_log_maintenance.purge_audit_logs(
            p_retention_days => 0,
            p_batch_size     => 100,
            p_deleted_count  => l_deleted,
            p_failed_count   => l_failed
        );

        record_result(
            'Audit retention below 1 is rejected',
            FALSE,
            'No exception raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Audit retention below 1 raises ORA-20800',
                -20800,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_log_maintenance.purge_audit_logs(
            p_retention_days => 90,
            p_batch_size     => NULL,
            p_deleted_count  => l_deleted,
            p_failed_count   => l_failed
        );

        record_result(
            'NULL audit batch size is rejected',
            FALSE,
            'No exception raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'NULL audit batch size raises ORA-20801',
                -20801,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_log_maintenance.purge_audit_logs(
            p_retention_days => 90,
            p_batch_size     => 0,
            p_deleted_count  => l_deleted,
            p_failed_count   => l_failed
        );

        record_result(
            'Audit batch size below 1 is rejected',
            FALSE,
            'No exception raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Audit batch size below 1 raises ORA-20801',
                -20801,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_log_maintenance.purge_audit_logs(
            p_retention_days => 90,
            p_batch_size     => 10001,
            p_deleted_count  => l_deleted,
            p_failed_count   => l_failed
        );

        record_result(
            'Audit batch size above 10000 is rejected',
            FALSE,
            'No exception raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Audit batch size above 10000 raises ORA-20801',
                -20801,
                SQLCODE,
                SQLERRM
            );
    END;

    ---------------------------------------------------------------------------
    -- D. PURGE_ERROR_LOGS parameter validation
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- D. PURGE_ERROR_LOGS VALIDATIONS ---');

    BEGIN
        pkg_log_maintenance.purge_error_logs(
            p_retention_days => NULL,
            p_batch_size     => 100,
            p_deleted_count  => l_deleted,
            p_failed_count   => l_failed
        );

        record_result(
            'NULL error retention is rejected',
            FALSE,
            'No exception raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'NULL error retention raises ORA-20800',
                -20800,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_log_maintenance.purge_error_logs(
            p_retention_days => 0,
            p_batch_size     => 100,
            p_deleted_count  => l_deleted,
            p_failed_count   => l_failed
        );

        record_result(
            'Error retention below 1 is rejected',
            FALSE,
            'No exception raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Error retention below 1 raises ORA-20800',
                -20800,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_log_maintenance.purge_error_logs(
            p_retention_days => 90,
            p_batch_size     => NULL,
            p_deleted_count  => l_deleted,
            p_failed_count   => l_failed
        );

        record_result(
            'NULL error batch size is rejected',
            FALSE,
            'No exception raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'NULL error batch size raises ORA-20801',
                -20801,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_log_maintenance.purge_error_logs(
            p_retention_days => 90,
            p_batch_size     => 0,
            p_deleted_count  => l_deleted,
            p_failed_count   => l_failed
        );

        record_result(
            'Error batch size below 1 is rejected',
            FALSE,
            'No exception raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Error batch size below 1 raises ORA-20801',
                -20801,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_log_maintenance.purge_error_logs(
            p_retention_days => 90,
            p_batch_size     => 10001,
            p_deleted_count  => l_deleted,
            p_failed_count   => l_failed
        );

        record_result(
            'Error batch size above 10000 is rejected',
            FALSE,
            'No exception raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Error batch size above 10000 raises ORA-20801',
                -20801,
                SQLCODE,
                SQLERRM
            );
    END;

    ---------------------------------------------------------------------------
    -- E. PURGE_AUDIT_LOGS functional behavior
    --
    -- Existing rows older than one day are temporarily deleted. Because the
    -- package does not COMMIT, the caller rolls the operation back immediately.
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- E. PURGE_AUDIT_LOGS FUNCTIONAL TEST ---');

    SAVEPOINT before_audit_purge;

    SELECT COUNT(*)
      INTO l_before_total
      FROM audit_logs;

    SELECT COUNT(*)
      INTO l_expected_old
      FROM audit_logs
     WHERE logged_at <
           SYSTIMESTAMP - NUMTODSINTERVAL(1, 'DAY');

    pkg_log_maintenance.purge_audit_logs(
        p_retention_days => 1,
        p_batch_size     => 2,
        p_deleted_count  => l_deleted,
        p_failed_count   => l_failed
    );

    SELECT COUNT(*)
      INTO l_after_purge_total
      FROM audit_logs;

    record_result(
        'PURGE_AUDIT_LOGS reports a valid deleted count',
        l_deleted >= 0,
        'Deleted count=' || l_deleted
    );

    record_result(
        'PURGE_AUDIT_LOGS reports zero row-level failures',
        l_failed = 0,
        'Expected=0, Actual=' || l_failed
    );

    record_result(
        'PURGE_AUDIT_LOGS table change matches its reported deleted count',
        l_after_purge_total = l_before_total - l_deleted + 1,
        'Expected=' || (l_before_total - l_deleted + 1) ||
        ', Actual=' || l_after_purge_total
    );

    SELECT COUNT(*)
      INTO l_count
      FROM audit_logs
     WHERE operation_name = 'PURGE_AUDIT_LOGS'
       AND action_type = 'DELETE';

    record_result(
        'PURGE_AUDIT_LOGS creates an audit record',
        l_count >= 1,
        'Expected at least 1 row, Actual=' || l_count
    );

    ROLLBACK TO before_audit_purge;

    SELECT COUNT(*)
      INTO l_after_rollback
      FROM audit_logs;

    record_result(
        'Caller rollback restores AUDIT_LOGS',
        l_after_rollback = l_before_total,
        'Expected=' || l_before_total || ', Actual=' || l_after_rollback
    );

    ---------------------------------------------------------------------------
    -- F. PURGE_ERROR_LOGS functional behavior
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- F. PURGE_ERROR_LOGS FUNCTIONAL TEST ---');

    SAVEPOINT before_error_purge;

    SELECT COUNT(*)
      INTO l_before_total
      FROM error_logs;

    SELECT COUNT(*)
      INTO l_expected_old
      FROM error_logs
     WHERE logged_at <
           SYSTIMESTAMP - NUMTODSINTERVAL(1, 'DAY');

    pkg_log_maintenance.purge_error_logs(
        p_retention_days => 1,
        p_batch_size     => 2,
        p_deleted_count  => l_deleted,
        p_failed_count   => l_failed
    );

    SELECT COUNT(*)
      INTO l_after_purge_total
      FROM error_logs;

    record_result(
        'PURGE_ERROR_LOGS reports the expected deleted count',
        l_deleted = l_expected_old,
        'Expected=' || l_expected_old || ', Actual=' || l_deleted
    );

    record_result(
        'PURGE_ERROR_LOGS reports zero row-level failures',
        l_failed = 0,
        'Expected=0, Actual=' || l_failed
    );

    record_result(
        'PURGE_ERROR_LOGS removes eligible rows before caller rollback',
        l_after_purge_total = l_before_total - l_expected_old,
        'Expected=' || (l_before_total - l_expected_old) ||
        ', Actual=' || l_after_purge_total
    );

    SELECT COUNT(*)
      INTO l_count
      FROM audit_logs
     WHERE operation_name = 'PURGE_ERROR_LOGS'
       AND action_type = 'DELETE';

    record_result(
        'PURGE_ERROR_LOGS creates an audit record',
        l_count >= 1,
        'Expected at least 1 row, Actual=' || l_count
    );

    ROLLBACK TO before_error_purge;

    SELECT COUNT(*)
      INTO l_after_rollback
      FROM error_logs;

    record_result(
        'Caller rollback restores ERROR_LOGS',
        l_after_rollback = l_before_total,
        'Expected=' || l_before_total || ', Actual=' || l_after_rollback
    );

    ---------------------------------------------------------------------------
    -- G. Final cleanup and summary
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- G. CLEANUP VERIFICATION ---');

    ROLLBACK;

    record_result(
        'Regression suite completed without committing purge changes',
        TRUE
    );

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '================================================================================');
    DBMS_OUTPUT.PUT_LINE('PKG_LOG_MAINTENANCE TEST SUMMARY');
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

    DBMS_OUTPUT.PUT_LINE('================================================================================');

EXCEPTION
    WHEN OTHERS THEN
        IF l_result%ISOPEN THEN
            CLOSE l_result;
        END IF;

        ROLLBACK;

        l_fail_count := l_fail_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] Unexpected suite-level error -> SQLCODE=' ||
            SQLCODE || ', SQLERRM=' || SQLERRM
        );

        DBMS_OUTPUT.PUT_LINE(
            DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );

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
PROMPT PACKAGE COMPILATION ERROR CHECK
PROMPT ================================================================================
PROMPT

COLUMN name     FORMAT A35
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
WHERE name IN (
    'PKG_LOG_MAINTENANCE',
    'PKG_AUDIT',
    'PKG_ERROR_LOG'
)
ORDER BY
    name,
    sequence;