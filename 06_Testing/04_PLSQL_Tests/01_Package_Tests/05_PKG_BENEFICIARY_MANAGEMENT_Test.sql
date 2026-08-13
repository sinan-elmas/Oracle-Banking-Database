-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / PL/SQL Tests / Package Tests
-- Script       : 05_PKG_BENEFICIARY_MANAGEMENT_Test.sql
-- Purpose      : Validate beneficiary registration, nickname maintenance,
--                removal, retrieval, audit integration, error handling,
--                and caller-controlled transaction behavior
-- Scope        : PKG_BENEFICIARY_MANAGEMENT
-- Safety       : Business-data changes are rolled back after testing
-- Environment  : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET DEFINE OFF;
SET VERIFY OFF;
SET FEEDBACK ON;

PROMPT ============================================================
PROMPT PKG_BENEFICIARY_MANAGEMENT - COMPLETE TEST SUITE
PROMPT ============================================================
PROMPT
PROMPT Run with SQL Developer Run Script (F5).
PROMPT Beneficiary and audit test rows are rolled back.
PROMPT Identity sequence gaps are normal because identity values are not rolled back.
PROMPT ============================================================

DECLARE
    ------------------------------------------------------------------------
    -- Suite state
    ------------------------------------------------------------------------
    v_test_started_at          TIMESTAMP := SYSTIMESTAMP;
    v_session_id               NUMBER :=
        TO_NUMBER(SYS_CONTEXT('USERENV', 'SESSIONID'));

    ------------------------------------------------------------------------
    -- Reusable test data
    ------------------------------------------------------------------------
    v_customer_id              customers.customer_id%TYPE;
    v_customer_own_account_id  accounts.account_id%TYPE;
    v_beneficiary_account_id   accounts.account_id%TYPE;
    v_inactive_customer_id     customers.customer_id%TYPE;
    v_inactive_account_id      accounts.account_id%TYPE;
    v_empty_customer_id        customers.customer_id%TYPE;

    v_beneficiary_id           beneficiaries.beneficiary_id%TYPE;
    v_second_beneficiary_id    beneficiaries.beneficiary_id%TYPE;

    v_nickname                 beneficiaries.nickname%TYPE;
    v_created_by               beneficiaries.created_by%TYPE;
    v_updated_by               beneficiaries.updated_by%TYPE;
    v_updated_at               beneficiaries.updated_at%TYPE;

    v_count                    PLS_INTEGER;
    v_cursor                   SYS_REFCURSOR;

    ------------------------------------------------------------------------
    -- Cursor output variables
    ------------------------------------------------------------------------
    v_rc_beneficiary_id        beneficiaries.beneficiary_id%TYPE;
    v_rc_customer_id           beneficiaries.customer_id%TYPE;
    v_rc_account_id            beneficiaries.beneficiary_account_id%TYPE;
    v_rc_nickname              beneficiaries.nickname%TYPE;
    v_rc_account_number        accounts.account_number%TYPE;
    v_rc_iban                  accounts.iban%TYPE;
    v_rc_account_status        accounts.status%TYPE;
    v_rc_created_at            beneficiaries.created_at%TYPE;
    v_rc_created_by            beneficiaries.created_by%TYPE;
    v_rc_updated_at            beneficiaries.updated_at%TYPE;
    v_rc_updated_by            beneficiaries.updated_by%TYPE;

    ------------------------------------------------------------------------
    -- Test counters
    ------------------------------------------------------------------------
    v_total_tests              PLS_INTEGER := 0;
    v_passed_tests             PLS_INTEGER := 0;
    v_failed_tests             PLS_INTEGER := 0;

    ------------------------------------------------------------------------
    -- Output helpers
    ------------------------------------------------------------------------
    PROCEDURE print_header(p_title IN VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE(p_title);
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    END print_header;

    PROCEDURE pass_test(p_name IN VARCHAR2) IS
    BEGIN
        v_total_tests  := v_total_tests + 1;
        v_passed_tests := v_passed_tests + 1;
        DBMS_OUTPUT.PUT_LINE('[PASS] ' || p_name);
    END pass_test;

    PROCEDURE fail_test(
        p_name    IN VARCHAR2,
        p_details IN VARCHAR2
    ) IS
    BEGIN
        v_total_tests  := v_total_tests + 1;
        v_failed_tests := v_failed_tests + 1;
        DBMS_OUTPUT.PUT_LINE('[FAIL] ' || p_name || ' -> ' || p_details);
    END fail_test;

    PROCEDURE assert_true(
        p_name      IN VARCHAR2,
        p_condition IN BOOLEAN,
        p_details   IN VARCHAR2 DEFAULT 'Condition evaluated to FALSE.'
    ) IS
    BEGIN
        IF p_condition THEN
            pass_test(p_name);
        ELSE
            fail_test(p_name, p_details);
        END IF;
    END assert_true;

    PROCEDURE assert_equal_number(
        p_name     IN VARCHAR2,
        p_actual   IN NUMBER,
        p_expected IN NUMBER
    ) IS
    BEGIN
        IF p_actual = p_expected
           OR (p_actual IS NULL AND p_expected IS NULL)
        THEN
            pass_test(p_name);
        ELSE
            fail_test(
                p_name,
                'Expected=' || NVL(TO_CHAR(p_expected), 'NULL') ||
                ', Actual=' || NVL(TO_CHAR(p_actual), 'NULL')
            );
        END IF;
    END assert_equal_number;

    PROCEDURE assert_equal_text(
        p_name     IN VARCHAR2,
        p_actual   IN VARCHAR2,
        p_expected IN VARCHAR2
    ) IS
    BEGIN
        IF p_actual = p_expected
           OR (p_actual IS NULL AND p_expected IS NULL)
        THEN
            pass_test(p_name);
        ELSE
            fail_test(
                p_name,
                'Expected=' || NVL(p_expected, 'NULL') ||
                ', Actual=' || NVL(p_actual, 'NULL')
            );
        END IF;
    END assert_equal_text;

    PROCEDURE assert_expected_error(
        p_name          IN VARCHAR2,
        p_expected_code IN NUMBER,
        p_actual_code   IN NUMBER,
        p_actual_msg    IN VARCHAR2
    ) IS
    BEGIN
        IF p_actual_code = p_expected_code THEN
            pass_test(
                p_name || ' (' || p_expected_code || ': ' ||
                SUBSTR(p_actual_msg, 1, 180) || ')'
            );
        ELSE
            fail_test(
                p_name,
                'Expected SQLCODE=' || p_expected_code ||
                ', Actual SQLCODE=' || p_actual_code ||
                ', Message=' || SUBSTR(p_actual_msg, 1, 300)
            );
        END IF;
    END assert_expected_error;

    ------------------------------------------------------------------------
    -- Adds one test beneficiary using the selected reusable data.
    ------------------------------------------------------------------------
    PROCEDURE create_test_beneficiary(
        p_nickname       IN  beneficiaries.nickname%TYPE,
        p_beneficiary_id OUT beneficiaries.beneficiary_id%TYPE
    ) IS
    BEGIN
        pkg_beneficiary_management.add_beneficiary(
            p_customer_id            => v_customer_id,
            p_beneficiary_account_id => v_beneficiary_account_id,
            p_nickname               => p_nickname,
            p_created_by             => 'PKG_BENEF_TEST',
            p_beneficiary_id         => p_beneficiary_id
        );
    END create_test_beneficiary;

BEGIN
    ------------------------------------------------------------------------
    -- 0. Package and API health
    ------------------------------------------------------------------------
    print_header('0. Package and API health');

    SELECT COUNT(*)
      INTO v_count
      FROM user_objects
     WHERE object_name = 'PKG_BENEFICIARY_MANAGEMENT'
       AND object_type IN ('PACKAGE', 'PACKAGE BODY')
       AND status = 'VALID';

    assert_equal_number(
        'Package specification and body are VALID',
        v_count,
        2
    );

    SELECT COUNT(*)
      INTO v_count
      FROM user_procedures
     WHERE object_name = 'PKG_BENEFICIARY_MANAGEMENT'
       AND procedure_name IN (
           'ADD_BENEFICIARY',
           'UPDATE_BENEFICIARY_NICKNAME',
           'REMOVE_BENEFICIARY',
           'GET_BENEFICIARY_INFO',
           'GET_CUSTOMER_BENEFICIARIES'
       );

    assert_equal_number(
        'Five public procedures are exposed',
        v_count,
        5
    );

    ------------------------------------------------------------------------
    -- Select an active customer who owns at least one active account, and
    -- another active account owned by a different customer.
    ------------------------------------------------------------------------
    SELECT customer_id,
           own_account_id,
           beneficiary_account_id
      INTO v_customer_id,
           v_customer_own_account_id,
           v_beneficiary_account_id
      FROM (
            SELECT c.customer_id,
                   a1.account_id AS own_account_id,
                   a2.account_id AS beneficiary_account_id
              FROM customers c
              JOIN accounts a1
                ON a1.customer_id = c.customer_id
               AND UPPER(TRIM(a1.status)) = 'ACTIVE'
              JOIN accounts a2
                ON a2.customer_id <> c.customer_id
               AND UPPER(TRIM(a2.status)) = 'ACTIVE'
             WHERE UPPER(TRIM(c.status)) = 'ACTIVE'
               AND NOT EXISTS (
                       SELECT 1
                         FROM beneficiaries b
                        WHERE b.customer_id = c.customer_id
                          AND b.beneficiary_account_id = a2.account_id
                   )
             ORDER BY c.customer_id, a1.account_id, a2.account_id
           )
     WHERE ROWNUM = 1;

    ------------------------------------------------------------------------
    -- Optional inactive customer
    ------------------------------------------------------------------------
    BEGIN
        SELECT customer_id
          INTO v_inactive_customer_id
          FROM (
                SELECT customer_id
                  FROM customers
                 WHERE UPPER(TRIM(status)) <> 'ACTIVE'
                 ORDER BY customer_id
               )
         WHERE ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_inactive_customer_id := NULL;
    END;

    ------------------------------------------------------------------------
    -- Optional inactive account owned by another customer
    ------------------------------------------------------------------------
    BEGIN
        SELECT account_id
          INTO v_inactive_account_id
          FROM (
                SELECT account_id
                  FROM accounts
                 WHERE UPPER(TRIM(status)) <> 'ACTIVE'
                   AND customer_id <> v_customer_id
                 ORDER BY account_id
               )
         WHERE ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_inactive_account_id := NULL;
    END;

    ------------------------------------------------------------------------
    -- Optional customer with no beneficiaries
    ------------------------------------------------------------------------
    BEGIN
        SELECT customer_id
          INTO v_empty_customer_id
          FROM (
                SELECT c.customer_id
                  FROM customers c
                 WHERE NOT EXISTS (
                           SELECT 1
                             FROM beneficiaries b
                            WHERE b.customer_id = c.customer_id
                       )
                 ORDER BY c.customer_id
               )
         WHERE ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_empty_customer_id := NULL;
    END;

    DBMS_OUTPUT.PUT_LINE('Selected customer               : ' || v_customer_id);
    DBMS_OUTPUT.PUT_LINE('Customer own account            : ' || v_customer_own_account_id);
    DBMS_OUTPUT.PUT_LINE('Beneficiary account             : ' || v_beneficiary_account_id);
    DBMS_OUTPUT.PUT_LINE(
        'Inactive customer               : ' ||
        NVL(TO_CHAR(v_inactive_customer_id), 'NONE')
    );
    DBMS_OUTPUT.PUT_LINE(
        'Inactive beneficiary account    : ' ||
        NVL(TO_CHAR(v_inactive_account_id), 'NONE')
    );

    SAVEPOINT beneficiary_suite_start;

    ------------------------------------------------------------------------
    -- 1. Successful ADD_BENEFICIARY
    ------------------------------------------------------------------------
    print_header('1. Successful ADD_BENEFICIARY');

    create_test_beneficiary(
        p_nickname       => 'Main Beneficiary',
        p_beneficiary_id => v_beneficiary_id
    );

    assert_true(
        'ADD_BENEFICIARY returns BENEFICIARY_ID',
        v_beneficiary_id IS NOT NULL
    );

    SELECT nickname,
           created_by
      INTO v_nickname,
           v_created_by
      FROM beneficiaries
     WHERE beneficiary_id = v_beneficiary_id;

    assert_equal_text(
        'Nickname is stored correctly',
        v_nickname,
        'Main Beneficiary'
    );

    assert_equal_text(
        'CREATED_BY is stored correctly',
        v_created_by,
        'PKG_BENEF_TEST'
    );

    SELECT COUNT(*)
      INTO v_count
      FROM beneficiaries
     WHERE beneficiary_id = v_beneficiary_id
       AND customer_id = v_customer_id
       AND beneficiary_account_id = v_beneficiary_account_id;

    assert_equal_number(
        'Beneficiary row is created correctly',
        v_count,
        1
    );

    SELECT COUNT(*)
      INTO v_count
      FROM audit_logs
     WHERE entity_name = 'BENEFICIARIES'
       AND entity_id = TO_CHAR(v_beneficiary_id)
       AND action_type = 'INSERT'
       AND operation_name = 'ADD_BENEFICIARY';

    assert_equal_number(
        'ADD_BENEFICIARY creates one audit record',
        v_count,
        1
    );

    ------------------------------------------------------------------------
    -- 2. ADD_BENEFICIARY validation tests
    ------------------------------------------------------------------------
    print_header('2. ADD_BENEFICIARY validation tests');

    BEGIN
        pkg_beneficiary_management.add_beneficiary(
            p_customer_id            => NULL,
            p_beneficiary_account_id => v_beneficiary_account_id,
            p_nickname               => 'Test',
            p_created_by             => 'PKG_BENEF_TEST',
            p_beneficiary_id         => v_second_beneficiary_id
        );
        fail_test('Rejects NULL customer ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Rejects NULL customer ID',
                -20500,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_beneficiary_management.add_beneficiary(
            p_customer_id            => v_customer_id,
            p_beneficiary_account_id => NULL,
            p_nickname               => 'Test',
            p_created_by             => 'PKG_BENEF_TEST',
            p_beneficiary_id         => v_second_beneficiary_id
        );
        fail_test('Rejects NULL beneficiary account ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Rejects NULL beneficiary account ID',
                -20501,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_beneficiary_management.add_beneficiary(
            p_customer_id            => -999999,
            p_beneficiary_account_id => v_beneficiary_account_id,
            p_nickname               => 'Test',
            p_created_by             => 'PKG_BENEF_TEST',
            p_beneficiary_id         => v_second_beneficiary_id
        );
        fail_test('Rejects unknown customer', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Rejects unknown customer',
                -20502,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_beneficiary_management.add_beneficiary(
            p_customer_id            => v_customer_id,
            p_beneficiary_account_id => -999999,
            p_nickname               => 'Test',
            p_created_by             => 'PKG_BENEF_TEST',
            p_beneficiary_id         => v_second_beneficiary_id
        );
        fail_test('Rejects unknown beneficiary account', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Rejects unknown beneficiary account',
                -20504,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_beneficiary_management.add_beneficiary(
            p_customer_id            => v_customer_id,
            p_beneficiary_account_id => v_customer_own_account_id,
            p_nickname               => 'Own Account',
            p_created_by             => 'PKG_BENEF_TEST',
            p_beneficiary_id         => v_second_beneficiary_id
        );
        fail_test('Rejects customer own account', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Rejects customer own account',
                -20506,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_beneficiary_management.add_beneficiary(
            p_customer_id            => v_customer_id,
            p_beneficiary_account_id => v_beneficiary_account_id,
            p_nickname               => 'Duplicate',
            p_created_by             => 'PKG_BENEF_TEST',
            p_beneficiary_id         => v_second_beneficiary_id
        );
        fail_test('Rejects duplicate beneficiary', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Rejects duplicate beneficiary',
                -20507,
                SQLCODE,
                SQLERRM
            );
    END;

    IF v_inactive_customer_id IS NOT NULL THEN
        BEGIN
            pkg_beneficiary_management.add_beneficiary(
                p_customer_id            => v_inactive_customer_id,
                p_beneficiary_account_id => v_beneficiary_account_id,
                p_nickname               => 'Inactive Customer',
                p_created_by             => 'PKG_BENEF_TEST',
                p_beneficiary_id         => v_second_beneficiary_id
            );
            fail_test('Rejects inactive customer', 'No error was raised.');
        EXCEPTION
            WHEN OTHERS THEN
                assert_expected_error(
                    'Rejects inactive customer',
                    -20503,
                    SQLCODE,
                    SQLERRM
                );
        END;
    ELSE
        DBMS_OUTPUT.PUT_LINE('[SKIP] No inactive customer was found.');
    END IF;

    IF v_inactive_account_id IS NOT NULL THEN
        BEGIN
            pkg_beneficiary_management.add_beneficiary(
                p_customer_id            => v_customer_id,
                p_beneficiary_account_id => v_inactive_account_id,
                p_nickname               => 'Inactive Account',
                p_created_by             => 'PKG_BENEF_TEST',
                p_beneficiary_id         => v_second_beneficiary_id
            );
            fail_test('Rejects inactive beneficiary account', 'No error was raised.');
        EXCEPTION
            WHEN OTHERS THEN
                assert_expected_error(
                    'Rejects inactive beneficiary account',
                    -20505,
                    SQLCODE,
                    SQLERRM
                );
        END;
    ELSE
        DBMS_OUTPUT.PUT_LINE('[SKIP] No inactive beneficiary account was found.');
    END IF;

    ------------------------------------------------------------------------
    -- 3. NULL nickname and CREATED_BY fallback
    ------------------------------------------------------------------------
    print_header('3. NULL nickname and CREATED_BY fallback');

    ROLLBACK TO beneficiary_suite_start;
    SAVEPOINT null_values_test;

    pkg_beneficiary_management.add_beneficiary(
        p_customer_id            => v_customer_id,
        p_beneficiary_account_id => v_beneficiary_account_id,
        p_nickname               => '   ',
        p_created_by             => NULL,
        p_beneficiary_id         => v_beneficiary_id
    );

    SELECT nickname,
           created_by
      INTO v_nickname,
           v_created_by
      FROM beneficiaries
     WHERE beneficiary_id = v_beneficiary_id;

    assert_true(
        'Blank nickname is stored as NULL',
        v_nickname IS NULL
    );

    assert_equal_text(
        'NULL CREATED_BY falls back to USER',
        v_created_by,
        USER
    );

    ROLLBACK TO null_values_test;

    ------------------------------------------------------------------------
    -- 4. UPDATE_BENEFICIARY_NICKNAME
    ------------------------------------------------------------------------
    print_header('4. UPDATE_BENEFICIARY_NICKNAME');

    SAVEPOINT update_test;

    create_test_beneficiary(
        p_nickname       => 'Old Nickname',
        p_beneficiary_id => v_beneficiary_id
    );

    pkg_beneficiary_management.update_beneficiary_nickname(
        p_beneficiary_id => v_beneficiary_id,
        p_nickname       => 'New Nickname',
        p_updated_by     => 'BENEF_UPDATE_TEST'
    );

    SELECT nickname,
           updated_at,
           updated_by
      INTO v_nickname,
           v_updated_at,
           v_updated_by
      FROM beneficiaries
     WHERE beneficiary_id = v_beneficiary_id;

    assert_equal_text(
        'Nickname is updated',
        v_nickname,
        'New Nickname'
    );

    assert_true(
        'Nickname update populates UPDATED_AT',
        v_updated_at IS NOT NULL
    );

    assert_equal_text(
        'Nickname update stores UPDATED_BY',
        v_updated_by,
        'BENEF_UPDATE_TEST'
    );

    SELECT COUNT(*)
      INTO v_count
      FROM audit_logs
     WHERE entity_name = 'BENEFICIARIES'
       AND entity_id = TO_CHAR(v_beneficiary_id)
       AND action_type = 'UPDATE'
       AND operation_name = 'UPDATE_BENEFICIARY_NICKNAME';

    assert_equal_number(
        'Nickname update creates one audit record',
        v_count,
        1
    );

    BEGIN
        pkg_beneficiary_management.update_beneficiary_nickname(
            p_beneficiary_id => NULL,
            p_nickname       => 'Test',
            p_updated_by     => 'BENEF_UPDATE_TEST'
        );
        fail_test('Nickname update rejects NULL beneficiary ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Nickname update rejects NULL beneficiary ID',
                -20510,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_beneficiary_management.update_beneficiary_nickname(
            p_beneficiary_id => -999999,
            p_nickname       => 'Test',
            p_updated_by     => 'BENEF_UPDATE_TEST'
        );
        fail_test('Nickname update rejects unknown beneficiary', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Nickname update rejects unknown beneficiary',
                -20511,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_beneficiary_management.update_beneficiary_nickname(
            p_beneficiary_id => v_beneficiary_id,
            p_nickname       => 'New Nickname',
            p_updated_by     => 'BENEF_UPDATE_TEST'
        );
        fail_test('Nickname update rejects same nickname', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Nickname update rejects same nickname',
                -20512,
                SQLCODE,
                SQLERRM
            );
    END;

    ROLLBACK TO update_test;

    ------------------------------------------------------------------------
    -- 5. GET_BENEFICIARY_INFO
    ------------------------------------------------------------------------
    print_header('5. GET_BENEFICIARY_INFO');

    SAVEPOINT info_test;

    create_test_beneficiary(
        p_nickname       => 'Information Test',
        p_beneficiary_id => v_beneficiary_id
    );

    pkg_beneficiary_management.get_beneficiary_info(
        p_beneficiary_id => v_beneficiary_id,
        p_result         => v_cursor
    );

    FETCH v_cursor
     INTO v_rc_beneficiary_id,
          v_rc_customer_id,
          v_rc_account_id,
          v_rc_nickname,
          v_rc_account_number,
          v_rc_iban,
          v_rc_account_status,
          v_rc_created_at,
          v_rc_created_by,
          v_rc_updated_at,
          v_rc_updated_by;

    assert_true(
        'GET_BENEFICIARY_INFO returns one row',
        v_cursor%FOUND
    );

    assert_equal_number(
        'GET_BENEFICIARY_INFO returns correct beneficiary ID',
        v_rc_beneficiary_id,
        v_beneficiary_id
    );

    assert_equal_number(
        'GET_BENEFICIARY_INFO returns correct customer ID',
        v_rc_customer_id,
        v_customer_id
    );

    assert_equal_number(
        'GET_BENEFICIARY_INFO returns correct account ID',
        v_rc_account_id,
        v_beneficiary_account_id
    );

    assert_equal_text(
        'GET_BENEFICIARY_INFO returns correct nickname',
        v_rc_nickname,
        'Information Test'
    );

    assert_true(
        'GET_BENEFICIARY_INFO returns account number',
        v_rc_account_number IS NOT NULL
    );

    assert_true(
        'GET_BENEFICIARY_INFO returns IBAN',
        v_rc_iban IS NOT NULL
    );

    FETCH v_cursor
     INTO v_rc_beneficiary_id,
          v_rc_customer_id,
          v_rc_account_id,
          v_rc_nickname,
          v_rc_account_number,
          v_rc_iban,
          v_rc_account_status,
          v_rc_created_at,
          v_rc_created_by,
          v_rc_updated_at,
          v_rc_updated_by;

    assert_true(
        'GET_BENEFICIARY_INFO returns only one row',
        v_cursor%NOTFOUND
    );

    CLOSE v_cursor;

    BEGIN
        pkg_beneficiary_management.get_beneficiary_info(
            p_beneficiary_id => NULL,
            p_result         => v_cursor
        );
        fail_test('GET_BENEFICIARY_INFO rejects NULL ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'GET_BENEFICIARY_INFO rejects NULL ID',
                -20530,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_beneficiary_management.get_beneficiary_info(
            p_beneficiary_id => -999999,
            p_result         => v_cursor
        );
        fail_test('GET_BENEFICIARY_INFO rejects unknown ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'GET_BENEFICIARY_INFO rejects unknown ID',
                -20531,
                SQLCODE,
                SQLERRM
            );
    END;

    ROLLBACK TO info_test;

    ------------------------------------------------------------------------
    -- 6. GET_CUSTOMER_BENEFICIARIES
    ------------------------------------------------------------------------
    print_header('6. GET_CUSTOMER_BENEFICIARIES');

    SAVEPOINT customer_list_test;

    create_test_beneficiary(
        p_nickname       => 'List Test',
        p_beneficiary_id => v_beneficiary_id
    );

    pkg_beneficiary_management.get_customer_beneficiaries(
        p_customer_id => v_customer_id,
        p_result      => v_cursor
    );

    v_count := 0;

    LOOP
        FETCH v_cursor
         INTO v_rc_beneficiary_id,
              v_rc_customer_id,
              v_rc_account_id,
              v_rc_nickname,
              v_rc_account_number,
              v_rc_iban,
              v_rc_account_status,
              v_rc_created_at,
              v_rc_created_by,
              v_rc_updated_at,
              v_rc_updated_by;

        EXIT WHEN v_cursor%NOTFOUND;

        v_count := v_count + 1;

        IF v_rc_customer_id <> v_customer_id THEN
            fail_test(
                'Customer list returns only requested customer',
                'Unexpected CUSTOMER_ID=' || v_rc_customer_id
            );
        END IF;
    END LOOP;

    CLOSE v_cursor;

    assert_true(
        'GET_CUSTOMER_BENEFICIARIES returns at least the test row',
        v_count >= 1,
        'Returned row count=' || v_count
    );

    IF v_empty_customer_id IS NOT NULL THEN
        pkg_beneficiary_management.get_customer_beneficiaries(
            p_customer_id => v_empty_customer_id,
            p_result      => v_cursor
        );

        FETCH v_cursor
         INTO v_rc_beneficiary_id,
              v_rc_customer_id,
              v_rc_account_id,
              v_rc_nickname,
              v_rc_account_number,
              v_rc_iban,
              v_rc_account_status,
              v_rc_created_at,
              v_rc_created_by,
              v_rc_updated_at,
              v_rc_updated_by;

        assert_true(
            'Customer without beneficiaries returns empty cursor',
            v_cursor%NOTFOUND
        );

        CLOSE v_cursor;
    ELSE
        DBMS_OUTPUT.PUT_LINE('[SKIP] No customer without beneficiaries was found.');
    END IF;

    BEGIN
        pkg_beneficiary_management.get_customer_beneficiaries(
            p_customer_id => NULL,
            p_result      => v_cursor
        );
        fail_test('Customer list rejects NULL customer ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Customer list rejects NULL customer ID',
                -20540,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_beneficiary_management.get_customer_beneficiaries(
            p_customer_id => -999999,
            p_result      => v_cursor
        );
        fail_test('Customer list rejects unknown customer', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Customer list rejects unknown customer',
                -20541,
                SQLCODE,
                SQLERRM
            );
    END;

    ROLLBACK TO customer_list_test;

    ------------------------------------------------------------------------
    -- 7. REMOVE_BENEFICIARY
    ------------------------------------------------------------------------
    print_header('7. REMOVE_BENEFICIARY');

    SAVEPOINT remove_test;

    create_test_beneficiary(
        p_nickname       => 'Remove Test',
        p_beneficiary_id => v_beneficiary_id
    );

    pkg_beneficiary_management.remove_beneficiary(
        p_beneficiary_id => v_beneficiary_id,
        p_removed_by     => 'BENEF_REMOVE_TEST'
    );

    SELECT COUNT(*)
      INTO v_count
      FROM beneficiaries
     WHERE beneficiary_id = v_beneficiary_id;

    assert_equal_number(
        'REMOVE_BENEFICIARY deletes the row',
        v_count,
        0
    );

    SELECT COUNT(*)
      INTO v_count
      FROM audit_logs
     WHERE entity_name = 'BENEFICIARIES'
       AND entity_id = TO_CHAR(v_beneficiary_id)
       AND action_type = 'DELETE'
       AND operation_name = 'REMOVE_BENEFICIARY';

    assert_equal_number(
        'REMOVE_BENEFICIARY creates one audit record',
        v_count,
        1
    );

    BEGIN
        pkg_beneficiary_management.remove_beneficiary(
            p_beneficiary_id => NULL,
            p_removed_by     => 'BENEF_REMOVE_TEST'
        );
        fail_test('REMOVE_BENEFICIARY rejects NULL ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'REMOVE_BENEFICIARY rejects NULL ID',
                -20520,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_beneficiary_management.remove_beneficiary(
            p_beneficiary_id => -999999,
            p_removed_by     => 'BENEF_REMOVE_TEST'
        );
        fail_test('REMOVE_BENEFICIARY rejects unknown ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'REMOVE_BENEFICIARY rejects unknown ID',
                -20521,
                SQLCODE,
                SQLERRM
            );
    END;

    ROLLBACK TO remove_test;

    ------------------------------------------------------------------------
    -- 8. Error-log integration
    ------------------------------------------------------------------------
    print_header('8. Error-log integration');

    SELECT COUNT(*)
      INTO v_count
      FROM error_logs
     WHERE logged_at >= v_test_started_at
       AND session_id = v_session_id
       AND operation_name IN (
           'PKG_BENEFICIARY_MANAGEMENT.ADD_BENEFICIARY',
           'PKG_BENEFICIARY_MANAGEMENT.UPDATE_BENEFICIARY_NICKNAME',
           'PKG_BENEFICIARY_MANAGEMENT.REMOVE_BENEFICIARY',
           'PKG_BENEFICIARY_MANAGEMENT.GET_BENEFICIARY_INFO',
           'PKG_BENEFICIARY_MANAGEMENT.GET_CUSTOMER_BENEFICIARIES'
       )
       AND error_code BETWEEN -20541 AND -20500;

    assert_true(
        'Expected package failures are recorded in ERROR_LOGS',
        v_count >= 15,
        'Expected at least 15 rows, Actual=' || v_count
    );

    ------------------------------------------------------------------------
    -- 9. Cleanup verification
    ------------------------------------------------------------------------
    print_header('9. Cleanup verification');

    ROLLBACK TO beneficiary_suite_start;

    SELECT COUNT(*)
      INTO v_count
      FROM beneficiaries
     WHERE created_by = 'PKG_BENEF_TEST'
       AND created_at >= SYSTIMESTAMP - INTERVAL '20' MINUTE;

    assert_equal_number(
        'All beneficiary test rows were rolled back',
        v_count,
        0
    );

    DELETE FROM error_logs
     WHERE logged_at >= v_test_started_at
       AND session_id = v_session_id
       AND operation_name IN (
           'PKG_BENEFICIARY_MANAGEMENT.ADD_BENEFICIARY',
           'PKG_BENEFICIARY_MANAGEMENT.UPDATE_BENEFICIARY_NICKNAME',
           'PKG_BENEFICIARY_MANAGEMENT.REMOVE_BENEFICIARY',
           'PKG_BENEFICIARY_MANAGEMENT.GET_BENEFICIARY_INFO',
           'PKG_BENEFICIARY_MANAGEMENT.GET_CUSTOMER_BENEFICIARIES'
       )
       AND error_code BETWEEN -20541 AND -20500;

    COMMIT;

    SELECT COUNT(*)
      INTO v_count
      FROM error_logs
     WHERE logged_at >= v_test_started_at
       AND session_id = v_session_id
       AND operation_name IN (
           'PKG_BENEFICIARY_MANAGEMENT.ADD_BENEFICIARY',
           'PKG_BENEFICIARY_MANAGEMENT.UPDATE_BENEFICIARY_NICKNAME',
           'PKG_BENEFICIARY_MANAGEMENT.REMOVE_BENEFICIARY',
           'PKG_BENEFICIARY_MANAGEMENT.GET_BENEFICIARY_INFO',
           'PKG_BENEFICIARY_MANAGEMENT.GET_CUSTOMER_BENEFICIARIES'
       )
       AND error_code BETWEEN -20541 AND -20500;

    assert_equal_number(
        'Test-generated error logs were removed',
        v_count,
        0
    );

    ------------------------------------------------------------------------
    -- Summary
    ------------------------------------------------------------------------
    print_header('TEST SUMMARY');

    DBMS_OUTPUT.PUT_LINE('Total tests  : ' || v_total_tests);
    DBMS_OUTPUT.PUT_LINE('Passed tests : ' || v_passed_tests);
    DBMS_OUTPUT.PUT_LINE('Failed tests : ' || v_failed_tests);

    IF v_failed_tests = 0 THEN
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=PASS');
    ELSE
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=FAIL');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        IF v_cursor%ISOPEN THEN
            CLOSE v_cursor;
        END IF;

        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            '[FATAL] Suitable active customer/account test data could not be found.'
        );
        DBMS_OUTPUT.PUT_LINE(SQLCODE || ': ' || SQLERRM);

    WHEN OTHERS THEN
        IF v_cursor%ISOPEN THEN
            CLOSE v_cursor;
        END IF;

        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('[FATAL] Test suite stopped unexpectedly.');
        DBMS_OUTPUT.PUT_LINE(SQLCODE || ': ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END;
/

PROMPT
PROMPT ================================================================================
PROMPT PACKAGE COMPILATION ERROR CHECK
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
WHERE name IN (
    'PKG_BENEFICIARY_MANAGEMENT',
    'PKG_AUDIT',
    'PKG_ERROR_LOG'
)
ORDER BY
    name,
    sequence;