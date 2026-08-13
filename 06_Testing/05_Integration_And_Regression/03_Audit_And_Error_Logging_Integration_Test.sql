-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Integration and Regression
-- Script       : 03_Audit_And_Error_Logging_Integration_Test.sql
-- Purpose      : Validate successful business auditing, failed-operation error
--                logging, transaction separation, and targeted cleanup
-- Scope        : PKG_CARD_MANAGEMENT, PKG_AUDIT, PKG_ERROR_LOG,
--                AUDIT_LOGS, ERROR_LOGS
-- Safety       : Business DML and audit rows are rolled back. The autonomous
--                error-log row is removed with a targeted DELETE and COMMIT.
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
PROMPT AUDIT AND ERROR LOGGING INTEGRATION TEST
PROMPT ================================================================================
PROMPT

DECLARE
    l_pass_count      PLS_INTEGER := 0;
    l_fail_count      PLS_INTEGER := 0;
    l_count           PLS_INTEGER;

    l_test_started_at TIMESTAMP := SYSTIMESTAMP;
    l_session_id      NUMBER :=
        TO_NUMBER(SYS_CONTEXT('USERENV', 'SESSIONID'));

    l_account_id      accounts.account_id%TYPE;
    l_card_type_id    card_types.card_type_id%TYPE;
    l_card_id         cards.card_id%TYPE;
    l_card_number     cards.card_number%TYPE;

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

    PROCEDURE assert_number (
        p_test_name IN VARCHAR2,
        p_expected  IN NUMBER,
        p_actual    IN NUMBER
    ) IS
    BEGIN
        record_result(
            p_test_name,
            NVL(p_expected, -999999999999999) =
            NVL(p_actual,   -999999999999999),
            'Expected=' || NVL(TO_CHAR(p_expected), 'NULL') ||
            ', Actual=' || NVL(TO_CHAR(p_actual), 'NULL')
        );
    END assert_number;

    PROCEDURE cleanup_error_logs IS
    BEGIN
        DELETE FROM error_logs
         WHERE logged_at >= l_test_started_at - INTERVAL '5' SECOND
           AND session_id = l_session_id
           AND operation_name = 'PKG_CARD_MANAGEMENT.ISSUE_CARD'
           AND error_code = -20410
           AND entity_name = 'CARDS';

        COMMIT;
    END cleanup_error_logs;

BEGIN
    DBMS_OUTPUT.PUT_LINE('--- A. INTEGRATION PREREQUISITES ---');

    SELECT COUNT(*)
      INTO l_count
      FROM user_objects
     WHERE object_name IN (
           'PKG_CARD_MANAGEMENT',
           'PKG_AUDIT',
           'PKG_ERROR_LOG'
       )
       AND object_type IN ('PACKAGE', 'PACKAGE BODY')
       AND status = 'VALID';

    assert_number(
        'Card, audit, and error-log package specifications/bodies are VALID',
        6,
        l_count
    );

    SELECT account_id
      INTO l_account_id
      FROM (
            SELECT account_id
              FROM accounts
             WHERE UPPER(TRIM(status)) = 'ACTIVE'
             ORDER BY account_id
           )
     WHERE ROWNUM = 1;

    SELECT card_type_id
      INTO l_card_type_id
      FROM (
            SELECT card_type_id
              FROM card_types
             ORDER BY card_type_id
           )
     WHERE ROWNUM = 1;

    DBMS_OUTPUT.PUT_LINE('Active account ID : ' || l_account_id);
    DBMS_OUTPUT.PUT_LINE('Card type ID      : ' || l_card_type_id);
    DBMS_OUTPUT.PUT_LINE('Session ID        : ' || l_session_id);

    SAVEPOINT integration_start;

    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- B. SUCCESSFUL BUSINESS ACTION AND AUDIT INTEGRATION ---'
    );

    pkg_card_management.issue_card(
        p_account_id   => l_account_id,
        p_card_type_id => l_card_type_id,
        p_created_by   => 'INTEGRATION_LOG_TEST',
        p_card_id      => l_card_id,
        p_card_number  => l_card_number
    );

    record_result(
        'Successful card issuance returns generated identifiers',
        l_card_id IS NOT NULL AND l_card_number IS NOT NULL,
        'CARD_ID or CARD_NUMBER is NULL.'
    );

    SELECT COUNT(*)
      INTO l_count
      FROM cards
     WHERE card_id = l_card_id
       AND account_id = l_account_id
       AND card_type_id = l_card_type_id
       AND card_number = l_card_number
       AND status = 'ACTIVE'
       AND created_by = 'INTEGRATION_LOG_TEST';

    assert_number(
        'Successful business action creates the expected card row',
        1,
        l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM audit_logs
     WHERE entity_name = 'CARDS'
       AND entity_id = TO_CHAR(l_card_id)
       AND action_type = 'INSERT'
       AND operation_name = 'ISSUE_CARD'
       AND session_user = USER
       AND session_id = l_session_id;

    assert_number(
        'Successful business action creates one complete AUDIT_LOGS row',
        1,
        l_count
    );

    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- C. EXPECTED FAILURE AND ERROR-LOG INTEGRATION ---'
    );

    BEGIN
        pkg_card_management.issue_card(
            p_account_id   => NULL,
            p_card_type_id => l_card_type_id,
            p_created_by   => 'INTEGRATION_LOG_TEST',
            p_card_id      => l_card_id,
            p_card_number  => l_card_number
        );

        record_result(
            'NULL account validation is raised',
            FALSE,
            'No exception was raised.'
        );
    EXCEPTION
        WHEN OTHERS THEN
            record_result(
                'NULL account validation raises ORA-20410',
                SQLCODE = -20410,
                'Expected SQLCODE=-20410, Actual SQLCODE=' ||
                SQLCODE || ', SQLERRM=' || SQLERRM
            );
    END;

    SELECT COUNT(*)
      INTO l_count
      FROM audit_logs
     WHERE entity_name = 'CARDS'
       AND entity_id = TO_CHAR(l_card_id)
       AND action_type = 'INSERT'
       AND operation_name = 'ISSUE_CARD';

    assert_number(
        'Rejected operation creates no additional success audit row',
        1,
        l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM error_logs
     WHERE logged_at >= l_test_started_at - INTERVAL '5' SECOND
       AND session_id = l_session_id
       AND operation_name = 'PKG_CARD_MANAGEMENT.ISSUE_CARD'
       AND error_code = -20410
       AND severity = 'ERROR'
       AND entity_name = 'CARDS'
       AND error_message IS NOT NULL
       AND error_stack IS NOT NULL
       AND call_stack IS NOT NULL
       AND context_data IS NOT NULL
       AND session_user = USER;

    assert_number(
        'Rejected business action creates one diagnostic ERROR_LOGS row',
        1,
        l_count
    );

    DBMS_OUTPUT.PUT_LINE(
        CHR(10) || '--- D. TRANSACTION SEPARATION ---'
    );

    ROLLBACK TO integration_start;

    SELECT COUNT(*)
      INTO l_count
      FROM cards
     WHERE card_id = l_card_id;

    assert_number(
        'Caller rollback removes the successful card row',
        0,
        l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM audit_logs
     WHERE entity_name = 'CARDS'
       AND entity_id = TO_CHAR(l_card_id)
       AND action_type = 'INSERT'
       AND operation_name = 'ISSUE_CARD';

    assert_number(
        'Caller rollback removes the success audit row',
        0,
        l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM error_logs
     WHERE logged_at >= l_test_started_at - INTERVAL '5' SECOND
       AND session_id = l_session_id
       AND operation_name = 'PKG_CARD_MANAGEMENT.ISSUE_CARD'
       AND error_code = -20410
       AND entity_name = 'CARDS';

    assert_number(
        'Autonomous error-log row survives caller rollback',
        1,
        l_count
    );

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- E. TARGETED CLEANUP ---');

    cleanup_error_logs;

    SELECT COUNT(*)
      INTO l_count
      FROM error_logs
     WHERE logged_at >= l_test_started_at - INTERVAL '5' SECOND
       AND session_id = l_session_id
       AND operation_name = 'PKG_CARD_MANAGEMENT.ISSUE_CARD'
       AND error_code = -20410
       AND entity_name = 'CARDS';

    assert_number(
        'Test-generated autonomous ERROR_LOGS row is removed',
        0,
        l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM cards
     WHERE created_by = 'INTEGRATION_LOG_TEST'
       AND created_at >= l_test_started_at - INTERVAL '5' SECOND;

    assert_number(
        'No test card residue remains',
        0,
        l_count
    );

    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '================================================================================'
    );
    DBMS_OUTPUT.PUT_LINE(
        'AUDIT AND ERROR LOGGING INTEGRATION TEST SUMMARY'
    );
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

        BEGIN
            cleanup_error_logs;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;

        l_fail_count := l_fail_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] Test preparation -> Required active account or card type was not found.'
        );
        DBMS_OUTPUT.PUT_LINE(
            'PASSED=' || l_pass_count ||
            ' FAILED=' || l_fail_count ||
            ' TOTAL=' || (l_pass_count + l_fail_count)
        );
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=FAIL');

    WHEN OTHERS THEN
        ROLLBACK;

        BEGIN
            cleanup_error_logs;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;

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
    'PKG_CARD_MANAGEMENT',
    'PKG_AUDIT',
    'PKG_ERROR_LOG'
)
ORDER BY
    name,
    sequence;