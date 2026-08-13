-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / PL/SQL Tests / Package Tests
-- Script       : 01_PKG_ERROR_LOG_Test.sql
-- Purpose      : Validate PKG_ERROR_LOG error capture, severity handling,
--                diagnostic persistence, JSON enforcement, and autonomous
--                transaction behavior
-- Scope        : PKG_ERROR_LOG and ERROR_LOGS
-- Safety       : Creates temporary test log rows and removes them afterward
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
PROMPT PKG_ERROR_LOG - REGRESSION TEST SUITE
PROMPT ================================================================================
PROMPT

DECLARE
    ---------------------------------------------------------------------------
    -- Test state
    ---------------------------------------------------------------------------
    l_test_prefix       VARCHAR2(80);
    l_operation_name    error_logs.operation_name%TYPE;
    l_count             PLS_INTEGER;
    l_pass_count        PLS_INTEGER := 0;
    l_fail_count        PLS_INTEGER := 0;

    ---------------------------------------------------------------------------
    -- Retrieved log values
    ---------------------------------------------------------------------------
    l_error_log_id      error_logs.error_log_id%TYPE;
    l_logged_at         error_logs.logged_at%TYPE;
    l_severity          error_logs.severity%TYPE;
    l_error_code        error_logs.error_code%TYPE;
    l_error_message     error_logs.error_message%TYPE;
    l_error_stack       error_logs.error_stack%TYPE;
    l_error_backtrace   error_logs.error_backtrace%TYPE;
    l_call_stack        error_logs.call_stack%TYPE;
    l_operation_value   error_logs.operation_name%TYPE;
    l_entity_name       error_logs.entity_name%TYPE;
    l_entity_id         error_logs.entity_id%TYPE;
    l_context_data      error_logs.context_data%TYPE;
    l_session_user      error_logs.session_user%TYPE;
    l_session_id        error_logs.session_id%TYPE;

    ---------------------------------------------------------------------------
    -- Severity test collections
    ---------------------------------------------------------------------------
    TYPE t_text_array IS TABLE OF VARCHAR2(30)
        INDEX BY PLS_INTEGER;

    l_input_severity    t_text_array;
    l_expected_severity t_text_array;

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

    PROCEDURE assert_contains(
        p_test_name IN VARCHAR2,
        p_value     IN VARCHAR2,
        p_expected  IN VARCHAR2
    ) IS
    BEGIN
        record_result(
            p_test_name,
            p_value IS NOT NULL
            AND INSTR(p_value, p_expected) > 0,
            'Expected text not found: ' || p_expected
        );
    END assert_contains;

    ---------------------------------------------------------------------------
    -- Creates an Oracle error and logs it inside the active exception context
    ---------------------------------------------------------------------------
    PROCEDURE create_error_log(
        p_operation_name IN VARCHAR2,
        p_error_code     IN PLS_INTEGER,
        p_error_message  IN VARCHAR2,
        p_severity       IN VARCHAR2,
        p_context_data   IN CLOB DEFAULT NULL
    ) IS
    BEGIN
        BEGIN
            RAISE_APPLICATION_ERROR(
                p_error_code,
                p_error_message
            );
        EXCEPTION
            WHEN OTHERS THEN
                pkg_error_log.log_error(
                    p_operation_name => p_operation_name,
                    p_entity_name    => 'TEST_ENTITY',
                    p_entity_id      => l_test_prefix,
                    p_context_data   => p_context_data,
                    p_severity       => p_severity
                );
        END;
    END create_error_log;

    ---------------------------------------------------------------------------
    -- Cleanup procedure
    ---------------------------------------------------------------------------
    PROCEDURE cleanup_test_rows IS
    BEGIN
        DELETE FROM error_logs
        WHERE operation_name LIKE l_test_prefix || '%';

        COMMIT;
    END cleanup_test_rows;

BEGIN
    l_test_prefix :=
        'PKG_ERROR_LOG_' || RAWTOHEX(SYS_GUID());

    ---------------------------------------------------------------------------
    -- A. Package and API health
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        '--- A. PACKAGE AND API HEALTH ---'
    );

    SELECT COUNT(*)
    INTO l_count
    FROM user_objects
    WHERE object_name = 'PKG_ERROR_LOG'
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
    WHERE object_name = 'PKG_ERROR_LOG'
      AND procedure_name = 'LOG_ERROR';

    assert_number(
        'LOG_ERROR is exposed as the single public procedure',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- B. Diagnostic capture and autonomous transaction behavior
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- B. DIAGNOSTIC CAPTURE AND AUTONOMOUS TRANSACTION ---'
    );

    l_operation_name := l_test_prefix || '_DIAGNOSTIC';

    SAVEPOINT caller_savepoint;

    create_error_log(
        p_operation_name => l_operation_name,
        p_error_code     => -20991,
        p_error_message  => 'Intentional PKG_ERROR_LOG diagnostic test',
        p_severity       => 'WARN',
        p_context_data   =>
            '{"suite":"PKG_ERROR_LOG","case":"diagnostic"}'
    );

    ROLLBACK TO caller_savepoint;

    SELECT
        error_log_id,
        logged_at,
        severity,
        error_code,
        error_message,
        error_stack,
        error_backtrace,
        call_stack,
        operation_name,
        entity_name,
        entity_id,
        context_data,
        session_user,
        session_id
    INTO
        l_error_log_id,
        l_logged_at,
        l_severity,
        l_error_code,
        l_error_message,
        l_error_stack,
        l_error_backtrace,
        l_call_stack,
        l_operation_value,
        l_entity_name,
        l_entity_id,
        l_context_data,
        l_session_user,
        l_session_id
    FROM error_logs
    WHERE operation_name = l_operation_name;

    assert_not_null(
        'Generated error log ID is populated',
        TO_CHAR(l_error_log_id)
    );

    assert_not_null(
        'Log timestamp is populated',
        TO_CHAR(l_logged_at)
    );

    assert_text(
        'Requested severity is stored',
        'WARN',
        l_severity
    );

    assert_number(
        'Oracle error code is captured',
        -20991,
        l_error_code
    );

    assert_contains(
        'Oracle error message is captured',
        l_error_message,
        'Intentional PKG_ERROR_LOG diagnostic test'
    );

    assert_contains(
        'Formatted error stack contains the Oracle error',
        DBMS_LOB.SUBSTR(l_error_stack, 4000, 1),
        'ORA-20991'
    );

    assert_not_null(
        'Error backtrace is captured',
        DBMS_LOB.SUBSTR(l_error_backtrace, 4000, 1)
    );

    assert_not_null(
        'PL/SQL call stack is captured',
        DBMS_LOB.SUBSTR(l_call_stack, 4000, 1)
    );

    assert_text(
        'Operation name is stored',
        l_operation_name,
        l_operation_value
    );

    assert_text(
        'Entity name is stored',
        'TEST_ENTITY',
        l_entity_name
    );

    assert_text(
        'Entity ID is stored',
        l_test_prefix,
        l_entity_id
    );

    assert_text(
        'JSON context is stored',
        '{"suite":"PKG_ERROR_LOG","case":"diagnostic"}',
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

    SELECT COUNT(*)
    INTO l_count
    FROM error_logs
    WHERE operation_name = l_operation_name;

    assert_number(
        'Log survives caller rollback',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- C. Supported severity values and normalization
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- C. SUPPORTED SEVERITY VALUES ---'
    );

    l_input_severity(1)    := ' info ';
    l_expected_severity(1) := 'INFO';

    l_input_severity(2)    := 'warn';
    l_expected_severity(2) := 'WARN';

    l_input_severity(3)    := ' ERROR ';
    l_expected_severity(3) := 'ERROR';

    l_input_severity(4)    := 'fatal';
    l_expected_severity(4) := 'FATAL';

    FOR i IN 1 .. 4 LOOP
        l_operation_name :=
            l_test_prefix || '_SEVERITY_' || TO_CHAR(i);

        create_error_log(
            p_operation_name => l_operation_name,
            p_error_code     => -20992,
            p_error_message  => 'Severity normalization test',
            p_severity       => l_input_severity(i)
        );

        SELECT severity
        INTO l_severity
        FROM error_logs
        WHERE operation_name = l_operation_name;

        assert_text(
            'Severity input "' ||
            l_input_severity(i) ||
            '" is normalized to ' ||
            l_expected_severity(i),
            l_expected_severity(i),
            l_severity
        );
    END LOOP;

    ---------------------------------------------------------------------------
    -- D. Default, NULL, and invalid severity behavior
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- D. DEFAULT AND INVALID SEVERITY HANDLING ---'
    );

    l_operation_name := l_test_prefix || '_DEFAULT';

    BEGIN
        RAISE_APPLICATION_ERROR(
            -20993,
            'Default severity test'
        );
    EXCEPTION
        WHEN OTHERS THEN
            pkg_error_log.log_error(
                p_operation_name => l_operation_name,
                p_entity_name    => 'TEST_ENTITY',
                p_entity_id      => l_test_prefix
            );
    END;

    SELECT severity
    INTO l_severity
    FROM error_logs
    WHERE operation_name = l_operation_name;

    assert_text(
        'Omitted severity defaults to ERROR',
        'ERROR',
        l_severity
    );

    l_operation_name := l_test_prefix || '_NULL';

    create_error_log(
        p_operation_name => l_operation_name,
        p_error_code     => -20994,
        p_error_message  => 'NULL severity test',
        p_severity       => NULL
    );

    SELECT severity
    INTO l_severity
    FROM error_logs
    WHERE operation_name = l_operation_name;

    assert_text(
        'NULL severity defaults to ERROR',
        'ERROR',
        l_severity
    );

    l_operation_name := l_test_prefix || '_INVALID';

    create_error_log(
        p_operation_name => l_operation_name,
        p_error_code     => -20995,
        p_error_message  => 'Invalid severity test',
        p_severity       => 'NOTICE'
    );

    SELECT severity
    INTO l_severity
    FROM error_logs
    WHERE operation_name = l_operation_name;

    assert_text(
        'Unsupported severity is normalized to ERROR',
        'ERROR',
        l_severity
    );

    ---------------------------------------------------------------------------
    -- E. ERROR_LOGS JSON constraint propagation
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- E. INVALID JSON HANDLING ---'
    );

    l_operation_name := l_test_prefix || '_INVALID_JSON';

    BEGIN
        BEGIN
            RAISE_APPLICATION_ERROR(
                -20996,
                'Invalid JSON context test'
            );
        EXCEPTION
            WHEN OTHERS THEN
                pkg_error_log.log_error(
                    p_operation_name => l_operation_name,
                    p_entity_name    => 'TEST_ENTITY',
                    p_entity_id      => l_test_prefix,
                    p_context_data   => '{invalid-json}',
                    p_severity       => 'ERROR'
                );
        END;

        record_result(
            'Invalid JSON context is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            record_result(
                'Invalid JSON context is rejected',
                SQLCODE = -2290,
                'Expected SQLCODE=-2290, Actual SQLCODE=' ||
                SQLCODE || ', SQLERRM=' || SQLERRM
            );
    END;

    SELECT COUNT(*)
    INTO l_count
    FROM error_logs
    WHERE operation_name = l_operation_name;

    assert_number(
        'Rejected JSON context leaves no error-log row',
        0,
        l_count
    );

    ---------------------------------------------------------------------------
    -- F. Cleanup and residual-data validation
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- F. CLEANUP ---'
    );

    cleanup_test_rows;

    SELECT COUNT(*)
    INTO l_count
    FROM error_logs
    WHERE operation_name LIKE l_test_prefix || '%';

    assert_number(
        'Test rows are removed from ERROR_LOGS',
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
        'PKG_ERROR_LOG TEST SUMMARY'
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
WHERE name = 'PKG_ERROR_LOG'
ORDER BY
    sequence;