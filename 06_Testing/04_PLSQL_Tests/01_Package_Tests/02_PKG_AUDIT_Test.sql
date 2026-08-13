-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / PL/SQL Tests / Package Tests
-- Script       : 02_PKG_AUDIT_Test.sql
-- Purpose      : Validate PKG_AUDIT action handling, audit payload storage,
--                transaction participation, JSON constraints, session context,
--                and PKG_ERROR_LOG integration
-- Scope        : PKG_AUDIT, AUDIT_LOGS, and PKG_ERROR_LOG integration
-- Safety       : Creates temporary audit/error rows and removes them afterward
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

ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

PROMPT
PROMPT ================================================================================
PROMPT PKG_AUDIT - REGRESSION TEST SUITE
PROMPT ================================================================================
PROMPT

DECLARE
    ---------------------------------------------------------------------------
    -- Test state
    ---------------------------------------------------------------------------
    l_test_token       VARCHAR2(64);
    l_operation_name   audit_logs.operation_name%TYPE;
    l_count            PLS_INTEGER;
    l_pass_count       PLS_INTEGER := 0;
    l_fail_count       PLS_INTEGER := 0;
    l_exception_raised BOOLEAN;

    ---------------------------------------------------------------------------
    -- Retrieved audit values
    ---------------------------------------------------------------------------
    l_audit_log_id     audit_logs.audit_log_id%TYPE;
    l_logged_at        audit_logs.logged_at%TYPE;
    l_action_type      audit_logs.action_type%TYPE;
    l_entity_name      audit_logs.entity_name%TYPE;
    l_entity_id        audit_logs.entity_id%TYPE;
    l_operation_value  audit_logs.operation_name%TYPE;
    l_old_data         audit_logs.old_data%TYPE;
    l_new_data         audit_logs.new_data%TYPE;
    l_context_data     audit_logs.context_data%TYPE;
    l_session_user     audit_logs.session_user%TYPE;
    l_session_id       audit_logs.session_id%TYPE;

    ---------------------------------------------------------------------------
    -- Supported action collection
    ---------------------------------------------------------------------------
    TYPE t_text_array IS TABLE OF VARCHAR2(30)
        INDEX BY PLS_INTEGER;

    l_input_action     t_text_array;
    l_expected_action  t_text_array;

    ---------------------------------------------------------------------------
    -- Result helpers
    ---------------------------------------------------------------------------
    PROCEDURE record_result(
        p_test_name IN VARCHAR2,
        p_passed    IN BOOLEAN,
        p_details   IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        IF p_passed THEN
            l_pass_count := l_pass_count + 1;

            DBMS_OUTPUT.PUT_LINE(
                '[PASS] ' || p_test_name
            );
        ELSE
            l_fail_count := l_fail_count + 1;

            DBMS_OUTPUT.PUT_LINE(
                '[FAIL] ' || p_test_name ||
                CASE
                    WHEN p_details IS NOT NULL
                        THEN ' -> ' || p_details
                END
            );
        END IF;
    END record_result;

    PROCEDURE assert_number(
        p_test_name IN VARCHAR2,
        p_expected  IN NUMBER,
        p_actual    IN NUMBER
    ) IS
    BEGIN
        record_result(
            p_test_name,
            p_expected = p_actual,
            'Expected=' || NVL(TO_CHAR(p_expected), 'NULL') ||
            ', Actual=' || NVL(TO_CHAR(p_actual), 'NULL')
        );
    END assert_number;

    PROCEDURE assert_text(
        p_test_name IN VARCHAR2,
        p_expected  IN VARCHAR2,
        p_actual    IN VARCHAR2
    ) IS
    BEGIN
        record_result(
            p_test_name,
            NVL(p_expected, '#NULL#') = NVL(p_actual, '#NULL#'),
            'Expected=' || NVL(p_expected, 'NULL') ||
            ', Actual=' || NVL(p_actual, 'NULL')
        );
    END assert_text;

    PROCEDURE assert_not_null(
        p_test_name IN VARCHAR2,
        p_value     IN VARCHAR2
    ) IS
    BEGIN
        record_result(
            p_test_name,
            p_value IS NOT NULL,
            'Value is NULL'
        );
    END assert_not_null;

    ---------------------------------------------------------------------------
    -- Test-data cleanup
    ---------------------------------------------------------------------------
    PROCEDURE cleanup_test_rows IS
    BEGIN
        DELETE FROM audit_logs
        WHERE entity_id = l_test_token
           OR operation_name LIKE l_test_token || '%';

        DELETE FROM error_logs
        WHERE entity_id = l_test_token
          AND operation_name = 'PKG_AUDIT.LOG_ACTION';

        COMMIT;
    END cleanup_test_rows;

BEGIN
    l_test_token :=
        'PKG_AUDIT_' || RAWTOHEX(SYS_GUID());

    ---------------------------------------------------------------------------
    -- A. Package and API health
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        '--- A. PACKAGE AND API HEALTH ---'
    );

    SELECT COUNT(*)
    INTO l_count
    FROM user_objects
    WHERE object_name = 'PKG_AUDIT'
      AND object_type IN ('PACKAGE', 'PACKAGE BODY')
      AND status = 'VALID';

    assert_number(
        'Package specification and body are VALID',
        2,
        l_count
    );

    SELECT COUNT(*)
    INTO l_count
    FROM user_procedures
    WHERE object_name = 'PKG_AUDIT'
      AND procedure_name = 'LOG_ACTION';

    assert_number(
        'LOG_ACTION is exposed as the single public procedure',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- B. Supported action types and normalization
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- B. SUPPORTED ACTION TYPES AND NORMALIZATION ---'
    );

    l_input_action(1)    := ' insert ';
    l_expected_action(1) := 'INSERT';

    l_input_action(2)    := 'update';
    l_expected_action(2) := 'UPDATE';

    l_input_action(3)    := ' DELETE ';
    l_expected_action(3) := 'DELETE';

    l_input_action(4)    := 'status_change';
    l_expected_action(4) := 'STATUS_CHANGE';

    l_input_action(5)    := ' business_action ';
    l_expected_action(5) := 'BUSINESS_ACTION';

    SAVEPOINT supported_action_tests;

    FOR i IN 1 .. 5 LOOP
        l_operation_name :=
            l_test_token || '_ACTION_' || TO_CHAR(i);

        pkg_audit.log_action(
            p_action_type    => l_input_action(i),
            p_entity_name    => ' test_entity ',
            p_entity_id      => l_test_token,
            p_operation_name => l_operation_name,
            p_context_data   =>
                '{"suite":"PKG_AUDIT","case":"action"}'
        );

        SELECT
            action_type,
            entity_name
        INTO
            l_action_type,
            l_entity_name
        FROM audit_logs
        WHERE operation_name = l_operation_name;

        assert_text(
            'Action "' || l_input_action(i) ||
            '" is normalized to ' || l_expected_action(i),
            l_expected_action(i),
            l_action_type
        );

        assert_text(
            'Entity name is trimmed and converted to uppercase',
            'TEST_ENTITY',
            l_entity_name
        );
    END LOOP;

    ROLLBACK TO supported_action_tests;

    SELECT COUNT(*)
    INTO l_count
    FROM audit_logs
    WHERE entity_id = l_test_token;

    assert_number(
        'Supported-action rows participate in caller rollback',
        0,
        l_count
    );

    ---------------------------------------------------------------------------
    -- C. Complete audit payload
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- C. COMPLETE AUDIT PAYLOAD ---'
    );

    l_operation_name := l_test_token || '_PAYLOAD';

    SAVEPOINT payload_test;

    pkg_audit.log_action(
        p_action_type    => 'UPDATE',
        p_entity_name    => 'ACCOUNT',
        p_entity_id      => l_test_token,
        p_operation_name => l_operation_name,
        p_old_data       =>
            '{"status":"ACTIVE","balance":1000}',
        p_new_data       =>
            '{"status":"BLOCKED","balance":1000}',
        p_context_data   =>
            '{"suite":"PKG_AUDIT","reason":"regression-test"}'
    );

    SELECT
        audit_log_id,
        logged_at,
        action_type,
        entity_name,
        entity_id,
        operation_name,
        old_data,
        new_data,
        context_data,
        session_user,
        session_id
    INTO
        l_audit_log_id,
        l_logged_at,
        l_action_type,
        l_entity_name,
        l_entity_id,
        l_operation_value,
        l_old_data,
        l_new_data,
        l_context_data,
        l_session_user,
        l_session_id
    FROM audit_logs
    WHERE operation_name = l_operation_name;

    assert_not_null(
        'Generated audit log ID is populated',
        TO_CHAR(l_audit_log_id)
    );

    assert_not_null(
        'Audit timestamp is populated',
        TO_CHAR(l_logged_at)
    );

    assert_text(
        'Action type is stored',
        'UPDATE',
        l_action_type
    );

    assert_text(
        'Entity name is stored',
        'ACCOUNT',
        l_entity_name
    );

    assert_text(
        'Entity ID is stored',
        l_test_token,
        l_entity_id
    );

    assert_text(
        'Operation name is stored',
        l_operation_name,
        l_operation_value
    );

    assert_text(
        'OLD_DATA JSON is stored',
        '{"status":"ACTIVE","balance":1000}',
        DBMS_LOB.SUBSTR(l_old_data, 4000, 1)
    );

    assert_text(
        'NEW_DATA JSON is stored',
        '{"status":"BLOCKED","balance":1000}',
        DBMS_LOB.SUBSTR(l_new_data, 4000, 1)
    );

    assert_text(
        'CONTEXT_DATA JSON is stored',
        '{"suite":"PKG_AUDIT","reason":"regression-test"}',
        DBMS_LOB.SUBSTR(l_context_data, 4000, 1)
    );

    assert_text(
        'Session user is captured',
        USER,
        l_session_user
    );

    assert_not_null(
        'Session ID is captured',
        TO_CHAR(l_session_id)
    );

    ROLLBACK TO payload_test;

    SELECT COUNT(*)
    INTO l_count
    FROM audit_logs
    WHERE operation_name = l_operation_name;

    assert_number(
        'Payload test row is removed by caller rollback',
        0,
        l_count
    );

    ---------------------------------------------------------------------------
    -- D. Caller COMMIT behavior
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- D. CALLER COMMIT BEHAVIOR ---'
    );

    l_operation_name := l_test_token || '_COMMIT';

    pkg_audit.log_action(
        p_action_type    => 'BUSINESS_ACTION',
        p_entity_name    => 'TEST_ENTITY',
        p_entity_id      => l_test_token,
        p_operation_name => l_operation_name,
        p_context_data   =>
            '{"suite":"PKG_AUDIT","case":"commit"}'
    );

    COMMIT;

    SELECT COUNT(*)
    INTO l_count
    FROM audit_logs
    WHERE operation_name = l_operation_name
      AND entity_id = l_test_token;

    assert_number(
        'Audit row persists after caller COMMIT',
        1,
        l_count
    );

    DELETE FROM audit_logs
    WHERE operation_name = l_operation_name
      AND entity_id = l_test_token;

    COMMIT;

    SELECT COUNT(*)
    INTO l_count
    FROM audit_logs
    WHERE operation_name = l_operation_name
      AND entity_id = l_test_token;

    assert_number(
        'Committed audit test row is cleaned up',
        0,
        l_count
    );

    ---------------------------------------------------------------------------
    -- E. Invalid action handling
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- E. INVALID ACTION HANDLING ---'
    );

    BEGIN
        pkg_audit.log_action(
            p_action_type    => 'UNSUPPORTED',
            p_entity_name    => 'TEST_ENTITY',
            p_entity_id      => l_test_token,
            p_operation_name => l_test_token || '_INVALID_ACTION'
        );

        record_result(
            'Unsupported action type is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            record_result(
                'Unsupported action type raises ORA-20010',
                SQLCODE = -20010,
                'Expected SQLCODE=-20010, Actual SQLCODE=' ||
                SQLCODE || ', SQLERRM=' || SQLERRM
            );
    END;

    SELECT COUNT(*)
    INTO l_count
    FROM audit_logs
    WHERE operation_name = l_test_token || '_INVALID_ACTION';

    assert_number(
        'Unsupported action creates no audit row',
        0,
        l_count
    );

    SELECT COUNT(*)
    INTO l_count
    FROM error_logs
    WHERE operation_name = 'PKG_AUDIT.LOG_ACTION'
      AND entity_id = l_test_token
      AND error_code = -20010;

    assert_number(
        'Unsupported action is recorded through PKG_ERROR_LOG',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- F. Required-value handling
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- F. REQUIRED-VALUE HANDLING ---'
    );

    l_exception_raised := FALSE;

    BEGIN
        pkg_audit.log_action(
            p_action_type    => NULL,
            p_entity_name    => 'TEST_ENTITY',
            p_entity_id      => l_test_token,
            p_operation_name => l_test_token || '_NULL_ACTION'
        );
    EXCEPTION
        WHEN OTHERS THEN
            l_exception_raised := TRUE;
    END;

    record_result(
        'NULL action type is rejected',
        l_exception_raised,
        'No exception was raised'
    );

    SELECT COUNT(*)
    INTO l_count
    FROM audit_logs
    WHERE operation_name = l_test_token || '_NULL_ACTION';

    assert_number(
        'NULL action creates no audit row',
        0,
        l_count
    );

    l_exception_raised := FALSE;

    BEGIN
        pkg_audit.log_action(
            p_action_type    => 'BUSINESS_ACTION',
            p_entity_name    => NULL,
            p_entity_id      => l_test_token,
            p_operation_name => l_test_token || '_NULL_ENTITY'
        );
    EXCEPTION
        WHEN OTHERS THEN
            l_exception_raised := TRUE;
    END;

    record_result(
        'NULL entity name is rejected',
        l_exception_raised,
        'No exception was raised'
    );

    SELECT COUNT(*)
    INTO l_count
    FROM audit_logs
    WHERE operation_name = l_test_token || '_NULL_ENTITY';

    assert_number(
        'NULL entity creates no audit row',
        0,
        l_count
    );

    ---------------------------------------------------------------------------
    -- G. JSON constraint handling
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- G. JSON CONSTRAINT HANDLING ---'
    );

    l_exception_raised := FALSE;

    BEGIN
        pkg_audit.log_action(
            p_action_type    => 'UPDATE',
            p_entity_name    => 'TEST_ENTITY',
            p_entity_id      => l_test_token,
            p_operation_name => l_test_token || '_INVALID_OLD_JSON',
            p_old_data       => '{invalid-old-json}'
        );
    EXCEPTION
        WHEN OTHERS THEN
            l_exception_raised := TRUE;

            record_result(
                'Invalid OLD_DATA JSON is rejected',
                SQLCODE = -2290,
                'Expected SQLCODE=-2290, Actual SQLCODE=' ||
                SQLCODE || ', SQLERRM=' || SQLERRM
            );
    END;

    IF NOT l_exception_raised THEN
        record_result(
            'Invalid OLD_DATA JSON is rejected',
            FALSE,
            'No exception was raised'
        );
    END IF;

    l_exception_raised := FALSE;

    BEGIN
        pkg_audit.log_action(
            p_action_type    => 'UPDATE',
            p_entity_name    => 'TEST_ENTITY',
            p_entity_id      => l_test_token,
            p_operation_name => l_test_token || '_INVALID_NEW_JSON',
            p_new_data       => '{invalid-new-json}'
        );
    EXCEPTION
        WHEN OTHERS THEN
            l_exception_raised := TRUE;

            record_result(
                'Invalid NEW_DATA JSON is rejected',
                SQLCODE = -2290,
                'Expected SQLCODE=-2290, Actual SQLCODE=' ||
                SQLCODE || ', SQLERRM=' || SQLERRM
            );
    END;

    IF NOT l_exception_raised THEN
        record_result(
            'Invalid NEW_DATA JSON is rejected',
            FALSE,
            'No exception was raised'
        );
    END IF;

    l_exception_raised := FALSE;

    BEGIN
        pkg_audit.log_action(
            p_action_type    => 'BUSINESS_ACTION',
            p_entity_name    => 'TEST_ENTITY',
            p_entity_id      => l_test_token,
            p_operation_name => l_test_token || '_INVALID_CONTEXT_JSON',
            p_context_data   => '{invalid-context-json}'
        );
    EXCEPTION
        WHEN OTHERS THEN
            l_exception_raised := TRUE;

            record_result(
                'Invalid CONTEXT_DATA JSON is rejected',
                SQLCODE = -2290,
                'Expected SQLCODE=-2290, Actual SQLCODE=' ||
                SQLCODE || ', SQLERRM=' || SQLERRM
            );
    END;

    IF NOT l_exception_raised THEN
        record_result(
            'Invalid CONTEXT_DATA JSON is rejected',
            FALSE,
            'No exception was raised'
        );
    END IF;

    SELECT COUNT(*)
    INTO l_count
    FROM audit_logs
    WHERE entity_id = l_test_token
      AND operation_name IN (
          l_test_token || '_INVALID_OLD_JSON',
          l_test_token || '_INVALID_NEW_JSON',
          l_test_token || '_INVALID_CONTEXT_JSON'
      );

    assert_number(
        'Rejected JSON payloads create no audit rows',
        0,
        l_count
    );

    SELECT COUNT(*)
    INTO l_count
    FROM error_logs
    WHERE operation_name = 'PKG_AUDIT.LOG_ACTION'
      AND entity_id = l_test_token;

    record_result(
        'Audit logging failures are recorded through PKG_ERROR_LOG',
        l_count >= 6,
        'Expected at least 6 error rows, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- H. Cleanup
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- H. CLEANUP ---'
    );

    cleanup_test_rows;

    SELECT COUNT(*)
    INTO l_count
    FROM audit_logs
    WHERE entity_id = l_test_token
       OR operation_name LIKE l_test_token || '%';

    assert_number(
        'Test rows are removed from AUDIT_LOGS',
        0,
        l_count
    );

    SELECT COUNT(*)
    INTO l_count
    FROM error_logs
    WHERE entity_id = l_test_token
      AND operation_name = 'PKG_AUDIT.LOG_ACTION';

    assert_number(
        'Test-generated error rows are removed from ERROR_LOGS',
        0,
        l_count
    );

    ---------------------------------------------------------------------------
    -- Final summary
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '================================================================================'
    );

    DBMS_OUTPUT.PUT_LINE(
        'PKG_AUDIT TEST SUMMARY'
    );

    DBMS_OUTPUT.PUT_LINE(
        'PASSED=' || l_pass_count ||
        ' FAILED=' || l_fail_count ||
        ' TOTAL=' || (l_pass_count + l_fail_count)
    );

    IF l_fail_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE(
            'OVERALL_STATUS=PASS'
        );
    ELSE
        DBMS_OUTPUT.PUT_LINE(
            'OVERALL_STATUS=FAIL'
        );
    END IF;

    DBMS_OUTPUT.PUT_LINE(
        '================================================================================'
    );

EXCEPTION
    WHEN OTHERS THEN
        l_fail_count := l_fail_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] Unexpected suite-level error -> SQLCODE=' ||
            SQLCODE || ', SQLERRM=' || SQLERRM
        );

        DBMS_OUTPUT.PUT_LINE(
            DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );

        BEGIN
            cleanup_test_rows;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(
                    '[FAIL] Emergency cleanup failed -> SQLCODE=' ||
                    SQLCODE || ', SQLERRM=' || SQLERRM
                );
        END;

        DBMS_OUTPUT.PUT_LINE(
            'PASSED=' || l_pass_count ||
            ' FAILED=' || l_fail_count ||
            ' TOTAL=' || (l_pass_count + l_fail_count)
        );

        DBMS_OUTPUT.PUT_LINE(
            'OVERALL_STATUS=FAIL'
        );
END;
/

PROMPT
PROMPT ================================================================================
PROMPT PACKAGE COMPILATION ERROR CHECK
PROMPT ================================================================================
PROMPT

COLUMN name     FORMAT A30
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
    'PKG_AUDIT',
    'PKG_ERROR_LOG'
)
ORDER BY
    name,
    sequence;