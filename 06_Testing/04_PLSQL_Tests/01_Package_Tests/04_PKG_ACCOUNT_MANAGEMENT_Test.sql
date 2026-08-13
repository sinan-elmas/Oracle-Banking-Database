-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / PL/SQL Tests / Package Tests
-- Script       : 04_PKG_ACCOUNT_MANAGEMENT_Test.sql
-- Purpose      : Validate account opening, status management, account detail
--                retrieval, balance retrieval, audit integration, error
--                handling, and caller-controlled transaction behavior
-- Scope        : PKG_ACCOUNT_MANAGEMENT
-- Safety       : All business-data changes are rolled back after testing
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
PROMPT PKG_ACCOUNT_MANAGEMENT - REGRESSION TEST SUITE
PROMPT ================================================================================
PROMPT

DECLARE
    ---------------------------------------------------------------------------
    -- Test state
    ---------------------------------------------------------------------------
    l_test_started_at       TIMESTAMP := SYSTIMESTAMP;
    l_session_id            NUMBER :=
        TO_NUMBER(SYS_CONTEXT('USERENV', 'SESSIONID'));

    l_pass_count            PLS_INTEGER := 0;
    l_fail_count            PLS_INTEGER := 0;
    l_count                 PLS_INTEGER;

    ---------------------------------------------------------------------------
    -- Reference values
    ---------------------------------------------------------------------------
    l_customer_id           customers.customer_id%TYPE;
    l_branch_id             branches.branch_id%TYPE;
    l_account_type_id       account_types.account_type_id%TYPE;
    l_currency_id           currencies.currency_id%TYPE;

    l_original_customer_status customers.status%TYPE;

    l_unknown_customer_id   customers.customer_id%TYPE;
    l_unknown_branch_id     branches.branch_id%TYPE;
    l_unknown_type_id       account_types.account_type_id%TYPE;
    l_unknown_currency_id   currencies.currency_id%TYPE;
    l_unknown_account_id    accounts.account_id%TYPE;

    ---------------------------------------------------------------------------
    -- Created account values
    ---------------------------------------------------------------------------
    l_account_id            accounts.account_id%TYPE;
    l_account_number        accounts.account_number%TYPE;
    l_iban                  accounts.iban%TYPE;

    l_zero_account_id       accounts.account_id%TYPE;
    l_zero_account_number   accounts.account_number%TYPE;
    l_zero_iban             accounts.iban%TYPE;

    l_balance               accounts.balance%TYPE;
    l_status                accounts.status%TYPE;
    l_closing_date          accounts.closing_date%TYPE;
    l_created_by            accounts.created_by%TYPE;
    l_updated_by            accounts.updated_by%TYPE;

    l_result_cursor         SYS_REFCURSOR;

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
            DBMS_OUTPUT.PUT_LINE('[PASS] ' || p_test_name);
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


    PROCEDURE assert_expected_error(
        p_test_name      IN VARCHAR2,
        p_expected_code  IN NUMBER,
        p_actual_code    IN NUMBER,
        p_actual_message IN VARCHAR2
    ) IS
    BEGIN
        record_result(
            p_test_name,
            p_expected_code = p_actual_code,
            'Expected SQLCODE=' || p_expected_code ||
            ', Actual SQLCODE=' || p_actual_code ||
            ', SQLERRM=' || p_actual_message
        );
    END assert_expected_error;


    ---------------------------------------------------------------------------
    -- Autonomous error-log cleanup
    ---------------------------------------------------------------------------
    PROCEDURE cleanup_test_error_logs IS
    BEGIN
        DELETE FROM error_logs
        WHERE logged_at >= l_test_started_at
          AND session_id = l_session_id
          AND operation_name IN (
              'PKG_ACCOUNT_MANAGEMENT.OPEN_ACCOUNT',
              'PKG_ACCOUNT_MANAGEMENT.UPDATE_ACCOUNT_STATUS',
              'PKG_ACCOUNT_MANAGEMENT.GET_ACCOUNT_INFO',
              'GET_AVAILABLE_BALANCE'
          )
          AND error_code BETWEEN -20233 AND -20210;

        COMMIT;
    END cleanup_test_error_logs;

BEGIN
    SAVEPOINT suite_start;

    ---------------------------------------------------------------------------
    -- Prepare valid reference values
    ---------------------------------------------------------------------------
    SELECT customer_id,
           status
    INTO l_customer_id,
         l_original_customer_status
    FROM (
        SELECT customer_id,
               status
        FROM customers
        WHERE status = 'ACTIVE'
        ORDER BY customer_id
    )
    WHERE ROWNUM = 1;

    SELECT branch_id
    INTO l_branch_id
    FROM (
        SELECT branch_id
        FROM branches
        ORDER BY branch_id
    )
    WHERE ROWNUM = 1;

    SELECT account_type_id
    INTO l_account_type_id
    FROM (
        SELECT account_type_id
        FROM account_types
        ORDER BY account_type_id
    )
    WHERE ROWNUM = 1;

    SELECT currency_id
    INTO l_currency_id
    FROM (
        SELECT currency_id
        FROM currencies
        ORDER BY currency_id
    )
    WHERE ROWNUM = 1;

    ---------------------------------------------------------------------------
    -- Prepare guaranteed unknown identifiers
    ---------------------------------------------------------------------------
    SELECT NVL(MAX(customer_id), 0) + 1000000
    INTO l_unknown_customer_id
    FROM customers;

    SELECT NVL(MAX(branch_id), 0) + 1000000
    INTO l_unknown_branch_id
    FROM branches;

    SELECT NVL(MAX(account_type_id), 0) + 1000000
    INTO l_unknown_type_id
    FROM account_types;

    SELECT NVL(MAX(currency_id), 0) + 1000000
    INTO l_unknown_currency_id
    FROM currencies;

    SELECT NVL(MAX(account_id), 0) + 1000000
    INTO l_unknown_account_id
    FROM accounts;

    ---------------------------------------------------------------------------
    -- A. Package and API health
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        '--- A. PACKAGE AND API HEALTH ---'
    );

    SELECT COUNT(*)
    INTO l_count
    FROM user_objects
    WHERE object_name = 'PKG_ACCOUNT_MANAGEMENT'
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
    WHERE object_name = 'PKG_ACCOUNT_MANAGEMENT'
      AND procedure_name IN (
          'OPEN_ACCOUNT',
          'UPDATE_ACCOUNT_STATUS',
          'GET_ACCOUNT_INFO',
          'GET_AVAILABLE_BALANCE'
      );

    assert_number(
        'Four public operations are exposed',
        4,
        l_count
    );

    ---------------------------------------------------------------------------
    -- B. Account opening success
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- B. ACCOUNT OPENING SUCCESS ---'
    );

    pkg_account_management.open_account(
        p_customer_id     => l_customer_id,
        p_branch_id       => l_branch_id,
        p_account_type_id => l_account_type_id,
        p_currency_id     => l_currency_id,
        p_initial_balance => 123.45,
        p_created_by      => '  TEST_SUITE  ',
        p_account_id      => l_account_id,
        p_account_number  => l_account_number,
        p_iban            => l_iban
    );

    record_result(
        'OPEN_ACCOUNT returns all generated identifiers',
        l_account_id IS NOT NULL
        AND l_account_number IS NOT NULL
        AND l_iban IS NOT NULL,
        'Account ID, account number, or IBAN is NULL'
    );

    record_result(
        'Generated account number follows project format',
        REGEXP_LIKE(
            l_account_number,
            '^AC[0-9]{8}-[0-9]+$'
        ),
        'Actual account number=' ||
        NVL(l_account_number, 'NULL')
    );

    record_result(
        'Generated IBAN follows project format',
        REGEXP_LIKE(
            l_iban,
            '^TR[0-9]{18}$'
        ),
        'Actual IBAN=' || NVL(l_iban, 'NULL')
    );

    SELECT balance,
           status,
           created_by
    INTO l_balance,
         l_status,
         l_created_by
    FROM accounts
    WHERE account_id = l_account_id;

    record_result(
        'Initial balance and ACTIVE status are stored',
        l_balance = 123.45
        AND l_status = 'ACTIVE',
        'Balance=' || TO_CHAR(l_balance) ||
        ', Status=' || l_status
    );

    assert_text(
        'CREATED_BY is trimmed and stored',
        'TEST_SUITE',
        l_created_by
    );

    SELECT COUNT(*)
    INTO l_count
    FROM audit_logs
    WHERE entity_id = TO_CHAR(l_account_id)
      AND action_type = 'INSERT'
      AND operation_name =
          'PKG_ACCOUNT_MANAGEMENT.OPEN_ACCOUNT';

    assert_number(
        'Account opening creates one audit row',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- C. NULL initial balance behavior
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- C. NULL INITIAL BALANCE BEHAVIOR ---'
    );

    pkg_account_management.open_account(
        p_customer_id     => l_customer_id,
        p_branch_id       => l_branch_id,
        p_account_type_id => l_account_type_id,
        p_currency_id     => l_currency_id,
        p_initial_balance => NULL,
        p_created_by      => NULL,
        p_account_id      => l_zero_account_id,
        p_account_number  => l_zero_account_number,
        p_iban            => l_zero_iban
    );

    SELECT balance,
           status,
           created_by
    INTO l_balance,
         l_status,
         l_created_by
    FROM accounts
    WHERE account_id = l_zero_account_id;

    record_result(
        'NULL initial balance defaults to zero',
        l_balance = 0,
        'Actual balance=' || TO_CHAR(l_balance)
    );

    assert_text(
        'Account opened with NULL balance is ACTIVE',
        'ACTIVE',
        l_status
    );

    assert_text(
        'NULL CREATED_BY defaults to session user',
        USER,
        l_created_by
    );

    ---------------------------------------------------------------------------
    -- D. OPEN_ACCOUNT validation errors
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- D. OPEN_ACCOUNT VALIDATION ERRORS ---'
    );

    BEGIN
        pkg_account_management.open_account(
            NULL,
            l_branch_id,
            l_account_type_id,
            l_currency_id,
            0,
            NULL,
            l_account_id,
            l_account_number,
            l_iban
        );

        record_result(
            'NULL customer ID is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'NULL customer ID raises ORA-20210',
                -20210,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.open_account(
            l_customer_id,
            NULL,
            l_account_type_id,
            l_currency_id,
            0,
            NULL,
            l_account_id,
            l_account_number,
            l_iban
        );

        record_result(
            'NULL branch ID is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'NULL branch ID raises ORA-20211',
                -20211,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.open_account(
            l_customer_id,
            l_branch_id,
            NULL,
            l_currency_id,
            0,
            NULL,
            l_account_id,
            l_account_number,
            l_iban
        );

        record_result(
            'NULL account type ID is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'NULL account type ID raises ORA-20212',
                -20212,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.open_account(
            l_customer_id,
            l_branch_id,
            l_account_type_id,
            NULL,
            0,
            NULL,
            l_account_id,
            l_account_number,
            l_iban
        );

        record_result(
            'NULL currency ID is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'NULL currency ID raises ORA-20213',
                -20213,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.open_account(
            l_customer_id,
            l_branch_id,
            l_account_type_id,
            l_currency_id,
            -1,
            NULL,
            l_account_id,
            l_account_number,
            l_iban
        );

        record_result(
            'Negative initial balance is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Negative initial balance raises ORA-20214',
                -20214,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.open_account(
            l_unknown_customer_id,
            l_branch_id,
            l_account_type_id,
            l_currency_id,
            0,
            NULL,
            l_account_id,
            l_account_number,
            l_iban
        );

        record_result(
            'Unknown customer is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Unknown customer raises ORA-20215',
                -20215,
                SQLCODE,
                SQLERRM
            );
    END;


    SAVEPOINT inactive_customer_test;

    UPDATE customers
    SET status = 'BLOCKED'
    WHERE customer_id = l_customer_id;

    BEGIN
        pkg_account_management.open_account(
            l_customer_id,
            l_branch_id,
            l_account_type_id,
            l_currency_id,
            0,
            NULL,
            l_account_id,
            l_account_number,
            l_iban
        );

        record_result(
            'Inactive customer is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Inactive customer raises ORA-20216',
                -20216,
                SQLCODE,
                SQLERRM
            );
    END;

    ROLLBACK TO inactive_customer_test;


    BEGIN
        pkg_account_management.open_account(
            l_customer_id,
            l_unknown_branch_id,
            l_account_type_id,
            l_currency_id,
            0,
            NULL,
            l_account_id,
            l_account_number,
            l_iban
        );

        record_result(
            'Unknown branch is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Unknown branch raises ORA-20217',
                -20217,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.open_account(
            l_customer_id,
            l_branch_id,
            l_unknown_type_id,
            l_currency_id,
            0,
            NULL,
            l_account_id,
            l_account_number,
            l_iban
        );

        record_result(
            'Unknown account type is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Unknown account type raises ORA-20218',
                -20218,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.open_account(
            l_customer_id,
            l_branch_id,
            l_account_type_id,
            l_unknown_currency_id,
            0,
            NULL,
            l_account_id,
            l_account_number,
            l_iban
        );

        record_result(
            'Unknown currency is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Unknown currency raises ORA-20219',
                -20219,
                SQLCODE,
                SQLERRM
            );
    END;

    ---------------------------------------------------------------------------
    -- E. Status update success
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- E. ACCOUNT STATUS UPDATE SUCCESS ---'
    );

    pkg_account_management.update_account_status(
        p_account_id => l_account_id,
        p_new_status => ' blocked ',
        p_updated_by => '  TEST_SUITE  '
    );

    SELECT status,
           updated_by
    INTO l_status,
         l_updated_by
    FROM accounts
    WHERE account_id = l_account_id;

    assert_text(
        'Status input is normalized to BLOCKED',
        'BLOCKED',
        l_status
    );

    assert_text(
        'UPDATED_BY is trimmed and stored',
        'TEST_SUITE',
        l_updated_by
    );

    SELECT COUNT(*)
    INTO l_count
    FROM audit_logs
    WHERE entity_id = TO_CHAR(l_account_id)
      AND action_type = 'UPDATE'
      AND operation_name =
          'PKG_ACCOUNT_MANAGEMENT.UPDATE_ACCOUNT_STATUS';

    assert_number(
        'Status update creates one audit row',
        1,
        l_count
    );

    pkg_account_management.update_account_status(
        p_account_id => l_account_id,
        p_new_status => 'ACTIVE',
        p_updated_by => NULL
    );

    SELECT status,
           updated_by
    INTO l_status,
         l_updated_by
    FROM accounts
    WHERE account_id = l_account_id;

    assert_text(
        'BLOCKED account can return to ACTIVE',
        'ACTIVE',
        l_status
    );

    assert_text(
        'NULL UPDATED_BY defaults to session user',
        USER,
        l_updated_by
    );

    ---------------------------------------------------------------------------
    -- F. Status validation errors
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- F. ACCOUNT STATUS VALIDATION ERRORS ---'
    );

    BEGIN
        pkg_account_management.update_account_status(
            NULL,
            'ACTIVE',
            NULL
        );

        record_result(
            'NULL account ID is rejected by status procedure',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'NULL account ID raises ORA-20220',
                -20220,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.update_account_status(
            l_unknown_account_id,
            'ACTIVE',
            NULL
        );

        record_result(
            'Unknown account is rejected by status procedure',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Unknown account raises ORA-20221',
                -20221,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.update_account_status(
            l_account_id,
            NULL,
            NULL
        );

        record_result(
            'NULL status is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'NULL status raises ORA-20222',
                -20222,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.update_account_status(
            l_account_id,
            'INVALID',
            NULL
        );

        record_result(
            'Invalid status is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Invalid status raises ORA-20222',
                -20222,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.update_account_status(
            l_account_id,
            'ACTIVE',
            NULL
        );

        record_result(
            'Same status is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Same status raises ORA-20223',
                -20223,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.update_account_status(
            l_account_id,
            'CLOSED',
            NULL
        );

        record_result(
            'Non-zero balance account closure is rejected',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Non-zero balance closure raises ORA-20225',
                -20225,
                SQLCODE,
                SQLERRM
            );
    END;

    ---------------------------------------------------------------------------
    -- G. Successful account closure
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- G. SUCCESSFUL ACCOUNT CLOSURE ---'
    );

    pkg_account_management.update_account_status(
        p_account_id => l_zero_account_id,
        p_new_status => 'CLOSED',
        p_updated_by => 'TEST_SUITE'
    );

    SELECT status,
           closing_date
    INTO l_status,
         l_closing_date
    FROM accounts
    WHERE account_id = l_zero_account_id;

    record_result(
        'Zero-balance account can be closed',
        l_status = 'CLOSED'
        AND l_closing_date = TRUNC(SYSDATE),
        'Status=' || l_status ||
        ', Closing date=' ||
        NVL(TO_CHAR(l_closing_date, 'YYYY-MM-DD'), 'NULL')
    );

    BEGIN
        pkg_account_management.update_account_status(
            l_zero_account_id,
            'ACTIVE',
            NULL
        );

        record_result(
            'Closed account cannot be reopened',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Closed account transition raises ORA-20224',
                -20224,
                SQLCODE,
                SQLERRM
            );
    END;

    ---------------------------------------------------------------------------
    -- H. Account information retrieval
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- H. ACCOUNT INFORMATION RETRIEVAL ---'
    );

    pkg_account_management.get_account_info(
        p_account_id => l_account_id,
        p_result     => l_result_cursor
    );

    record_result(
        'Valid account opens a result cursor',
        l_result_cursor%ISOPEN,
        'Result cursor is not open'
    );

    IF l_result_cursor%ISOPEN THEN
        CLOSE l_result_cursor;
    END IF;


    BEGIN
        pkg_account_management.get_account_info(
            NULL,
            l_result_cursor
        );

        record_result(
            'NULL account ID is rejected by information procedure',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'NULL account ID raises ORA-20230',
                -20230,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        pkg_account_management.get_account_info(
            l_unknown_account_id,
            l_result_cursor
        );

        record_result(
            'Unknown account is rejected by information procedure',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Unknown account raises ORA-20231',
                -20231,
                SQLCODE,
                SQLERRM
            );
    END;

    ---------------------------------------------------------------------------
    -- I. Available balance retrieval
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- I. AVAILABLE BALANCE RETRIEVAL ---'
    );

    l_balance :=
        pkg_account_management.get_available_balance(
            l_account_id
        );

    record_result(
        'GET_AVAILABLE_BALANCE returns stored balance',
        l_balance = 123.45,
        'Actual balance=' || TO_CHAR(l_balance)
    );


    BEGIN
        l_balance :=
            pkg_account_management.get_available_balance(NULL);

        record_result(
            'NULL account ID is rejected by balance function',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'NULL account ID raises ORA-20232',
                -20232,
                SQLCODE,
                SQLERRM
            );
    END;


    BEGIN
        l_balance :=
            pkg_account_management.get_available_balance(
                l_unknown_account_id
            );

        record_result(
            'Unknown account is rejected by balance function',
            FALSE,
            'No exception was raised'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Unknown account raises ORA-20233',
                -20233,
                SQLCODE,
                SQLERRM
            );
    END;

    ---------------------------------------------------------------------------
    -- J. Error-log integration
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- J. ERROR-LOG INTEGRATION ---'
    );

    SELECT COUNT(*)
    INTO l_count
    FROM error_logs
    WHERE logged_at >= l_test_started_at
      AND session_id = l_session_id
      AND operation_name IN (
          'PKG_ACCOUNT_MANAGEMENT.OPEN_ACCOUNT',
          'PKG_ACCOUNT_MANAGEMENT.UPDATE_ACCOUNT_STATUS',
          'PKG_ACCOUNT_MANAGEMENT.GET_ACCOUNT_INFO',
          'GET_AVAILABLE_BALANCE'
      )
      AND error_code BETWEEN -20233 AND -20210;

    record_result(
        'Expected package failures are recorded in ERROR_LOGS',
        l_count >= 20,
        'Expected at least 20 rows, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- K. Caller rollback and cleanup
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- K. CLEANUP ---'
    );

    ROLLBACK TO suite_start;

    SELECT COUNT(*)
    INTO l_count
    FROM accounts
    WHERE account_id IN (
        l_account_id,
        l_zero_account_id
    );

    assert_number(
        'Caller rollback removes created accounts',
        0,
        l_count
    );

    SELECT COUNT(*)
    INTO l_count
    FROM audit_logs
    WHERE entity_id IN (
        TO_CHAR(l_account_id),
        TO_CHAR(l_zero_account_id)
    )
      AND operation_name IN (
          'PKG_ACCOUNT_MANAGEMENT.OPEN_ACCOUNT',
          'PKG_ACCOUNT_MANAGEMENT.UPDATE_ACCOUNT_STATUS'
      );

    assert_number(
        'Caller rollback removes generated audit rows',
        0,
        l_count
    );

    SELECT status
    INTO l_status
    FROM customers
    WHERE customer_id = l_customer_id;

    assert_text(
        'Customer status remains unchanged after testing',
        l_original_customer_status,
        l_status
    );

    cleanup_test_error_logs;

    SELECT COUNT(*)
    INTO l_count
    FROM error_logs
    WHERE logged_at >= l_test_started_at
      AND session_id = l_session_id
      AND operation_name IN (
          'PKG_ACCOUNT_MANAGEMENT.OPEN_ACCOUNT',
          'PKG_ACCOUNT_MANAGEMENT.UPDATE_ACCOUNT_STATUS',
          'PKG_ACCOUNT_MANAGEMENT.GET_ACCOUNT_INFO',
          'GET_AVAILABLE_BALANCE'
      )
      AND error_code BETWEEN -20233 AND -20210;

    assert_number(
        'Test-generated error logs are removed',
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
        'PKG_ACCOUNT_MANAGEMENT TEST SUMMARY'
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

        l_fail_count := l_fail_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] Test preparation -> Required active customer or reference data was not found.'
        );

        BEGIN
            cleanup_test_error_logs;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        DBMS_OUTPUT.PUT_LINE(
            'PASSED=' || l_pass_count ||
            ' FAILED=' || l_fail_count ||
            ' TOTAL=' || (l_pass_count + l_fail_count)
        );

        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=FAIL');

    WHEN OTHERS THEN
        ROLLBACK;

        IF l_result_cursor%ISOPEN THEN
            CLOSE l_result_cursor;
        END IF;

        l_fail_count := l_fail_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] Unexpected suite-level error -> SQLCODE=' ||
            SQLCODE || ', SQLERRM=' || SQLERRM
        );

        DBMS_OUTPUT.PUT_LINE(
            DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );

        BEGIN
            cleanup_test_error_logs;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(
                    '[FAIL] Emergency error-log cleanup failed -> SQLCODE=' ||
                    SQLCODE || ', SQLERRM=' || SQLERRM
                );
        END;

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
    'PKG_ACCOUNT_MANAGEMENT',
    'PKG_AUDIT',
    'PKG_ERROR_LOG'
)
ORDER BY
    name,
    sequence;