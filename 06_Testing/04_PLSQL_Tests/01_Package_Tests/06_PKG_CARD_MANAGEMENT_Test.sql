-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / PL/SQL Tests / Package Tests
-- Script       : 06_PKG_CARD_MANAGEMENT_Test.sql
-- Purpose      : Validate all public operations of PKG_CARD_MANAGEMENT
-- Scope        : ISSUE_CARD, ACTIVATE_CARD, BLOCK_CARD, CLOSE_CARD,
--                GET_CARD_INFO, GET_ACCOUNT_CARDS
-- Safety       : Business-data changes are rolled back after each test section
-- Note         : CARD_SEQ gaps are expected because Oracle sequences do not roll back
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

VARIABLE g_card_test_started_at VARCHAR2(30)
VARIABLE g_card_test_session_id NUMBER

BEGIN
    :g_card_test_started_at := TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF6');
    :g_card_test_session_id := TO_NUMBER(SYS_CONTEXT('USERENV', 'SESSIONID'));
END;
/

PROMPT
PROMPT ================================================================================
PROMPT PKG_CARD_MANAGEMENT - COMPLETE REGRESSION TEST SUITE
PROMPT ================================================================================
PROMPT

PROMPT -------------------------------------------------------------------------------
PROMPT 0. PACKAGE AND API HEALTH
PROMPT -------------------------------------------------------------------------------

SELECT object_name,
       object_type,
       status
  FROM user_objects
 WHERE object_name = 'PKG_CARD_MANAGEMENT'
   AND object_type IN ('PACKAGE', 'PACKAGE BODY')
 ORDER BY object_type;

SELECT procedure_name
  FROM user_procedures
 WHERE object_name = 'PKG_CARD_MANAGEMENT'
   AND procedure_name IN (
       'ISSUE_CARD',
       'ACTIVATE_CARD',
       'BLOCK_CARD',
       'CLOSE_CARD',
       'GET_CARD_INFO',
       'GET_ACCOUNT_CARDS'
   )
 ORDER BY procedure_name;


PROMPT
PROMPT ================================================================================
PROMPT SECTION 1: ISSUE_CARD
PROMPT ================================================================================
PROMPT

DECLARE
    v_account_id          accounts.account_id%TYPE;
    v_card_type_id        card_types.card_type_id%TYPE;
    v_inactive_account_id accounts.account_id%TYPE;

    v_card_id             cards.card_id%TYPE;
    v_card_number         cards.card_number%TYPE;
    v_second_card_id      cards.card_id%TYPE;
    v_second_card_number  cards.card_number%TYPE;

    v_db_account_id       cards.account_id%TYPE;
    v_db_card_type_id     cards.card_type_id%TYPE;
    v_db_card_number      cards.card_number%TYPE;
    v_db_expiry_date      cards.expiry_date%TYPE;
    v_db_status           cards.status%TYPE;
    v_db_created_at       cards.created_at%TYPE;
    v_db_created_by       cards.created_by%TYPE;

    v_count               PLS_INTEGER;
    v_total_tests         PLS_INTEGER := 0;
    v_passed_tests        PLS_INTEGER := 0;
    v_failed_tests        PLS_INTEGER := 0;

    PROCEDURE header(p_title IN VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE(p_title);
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    END;

    PROCEDURE pass(p_name IN VARCHAR2) IS
    BEGIN
        v_total_tests := v_total_tests + 1;
        v_passed_tests := v_passed_tests + 1;
        DBMS_OUTPUT.PUT_LINE('[PASS] ' || p_name);
    END;

    PROCEDURE fail(p_name IN VARCHAR2, p_details IN VARCHAR2) IS
    BEGIN
        v_total_tests := v_total_tests + 1;
        v_failed_tests := v_failed_tests + 1;
        DBMS_OUTPUT.PUT_LINE('[FAIL] ' || p_name || ' -> ' || p_details);
    END;

    PROCEDURE assert_true(
        p_name IN VARCHAR2,
        p_condition IN BOOLEAN,
        p_details IN VARCHAR2 DEFAULT 'Condition evaluated to FALSE.'
    ) IS
    BEGIN
        IF p_condition THEN
            pass(p_name);
        ELSE
            fail(p_name, p_details);
        END IF;
    END;

    PROCEDURE assert_number(
        p_name IN VARCHAR2,
        p_actual IN NUMBER,
        p_expected IN NUMBER
    ) IS
    BEGIN
        IF p_actual = p_expected
           OR (p_actual IS NULL AND p_expected IS NULL)
        THEN
            pass(p_name);
        ELSE
            fail(
                p_name,
                'Expected=' || NVL(TO_CHAR(p_expected), 'NULL') ||
                ', Actual=' || NVL(TO_CHAR(p_actual), 'NULL')
            );
        END IF;
    END;

    PROCEDURE assert_text(
        p_name IN VARCHAR2,
        p_actual IN VARCHAR2,
        p_expected IN VARCHAR2
    ) IS
    BEGIN
        IF p_actual = p_expected
           OR (p_actual IS NULL AND p_expected IS NULL)
        THEN
            pass(p_name);
        ELSE
            fail(
                p_name,
                'Expected=' || NVL(p_expected, 'NULL') ||
                ', Actual=' || NVL(p_actual, 'NULL')
            );
        END IF;
    END;

    PROCEDURE expected_error(
        p_name IN VARCHAR2,
        p_expected_code IN NUMBER,
        p_actual_code IN NUMBER,
        p_actual_message IN VARCHAR2
    ) IS
    BEGIN
        IF p_actual_code = p_expected_code THEN
            pass(
                p_name || ' (' || p_expected_code || ': ' ||
                SUBSTR(p_actual_message, 1, 180) || ')'
            );
        ELSE
            fail(
                p_name,
                'Expected SQLCODE=' || p_expected_code ||
                ', Actual SQLCODE=' || p_actual_code ||
                ', Message=' || SUBSTR(p_actual_message, 1, 300)
            );
        END IF;
    END;

BEGIN
    SELECT account_id
      INTO v_account_id
      FROM (
            SELECT account_id
              FROM accounts
             WHERE UPPER(TRIM(status)) = 'ACTIVE'
             ORDER BY account_id
           )
     WHERE ROWNUM = 1;

    SELECT card_type_id
      INTO v_card_type_id
      FROM (
            SELECT card_type_id
              FROM card_types
             ORDER BY card_type_id
           )
     WHERE ROWNUM = 1;

    BEGIN
        SELECT account_id
          INTO v_inactive_account_id
          FROM (
                SELECT account_id
                  FROM accounts
                 WHERE UPPER(TRIM(status)) <> 'ACTIVE'
                 ORDER BY account_id
               )
         WHERE ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_inactive_account_id := NULL;
    END;

    DBMS_OUTPUT.PUT_LINE('Selected active account : ' || v_account_id);
    DBMS_OUTPUT.PUT_LINE('Selected card type      : ' || v_card_type_id);

    SAVEPOINT suite_start;

    ------------------------------------------------------------------------
    -- 1. Successful ISSUE_CARD
    ------------------------------------------------------------------------
    header('1. Successful ISSUE_CARD');

    pkg_card_management.issue_card(
        p_account_id   => v_account_id,
        p_card_type_id => v_card_type_id,
        p_created_by   => 'PKG_CARD_TEST',
        p_card_id      => v_card_id,
        p_card_number  => v_card_number
    );

    assert_true(
        'ISSUE_CARD returns CARD_ID',
        v_card_id IS NOT NULL
    );

    assert_true(
        'ISSUE_CARD returns CARD_NUMBER',
        v_card_number IS NOT NULL
    );

    SELECT account_id,
           card_type_id,
           card_number,
           expiry_date,
           status,
           created_at,
           created_by
      INTO v_db_account_id,
           v_db_card_type_id,
           v_db_card_number,
           v_db_expiry_date,
           v_db_status,
           v_db_created_at,
           v_db_created_by
      FROM cards
     WHERE card_id = v_card_id;

    assert_number('Stored ACCOUNT_ID is correct', v_db_account_id, v_account_id);
    assert_number('Stored CARD_TYPE_ID is correct', v_db_card_type_id, v_card_type_id);
    assert_text('Stored CARD_NUMBER matches output', v_db_card_number, v_card_number);
    assert_text('New card status is ACTIVE', v_db_status, 'ACTIVE');
    assert_text('CREATED_BY is stored correctly', v_db_created_by, 'PKG_CARD_TEST');

    assert_true(
        'CREATED_AT is populated',
        v_db_created_at IS NOT NULL
    );

    assert_true(
        'CARD_NUMBER contains exactly 16 digits',
        LENGTH(v_card_number) = 16
        AND REGEXP_LIKE(v_card_number, '^[0-9]{16}$'),
        'CARD_NUMBER=' || NVL(v_card_number, 'NULL')
    );

    assert_true(
        'CARD_NUMBER starts with 4000',
        SUBSTR(v_card_number, 1, 4) = '4000',
        'CARD_NUMBER=' || NVL(v_card_number, 'NULL')
    );

    assert_true(
        'EXPIRY_DATE is five years later',
        v_db_expiry_date BETWEEN ADD_MONTHS(TRUNC(SYSDATE), 60) - 1
                             AND ADD_MONTHS(TRUNC(SYSDATE), 60) + 1,
        'EXPIRY_DATE=' || TO_CHAR(v_db_expiry_date, 'YYYY-MM-DD')
    );

    SELECT COUNT(*)
      INTO v_count
      FROM cards
     WHERE card_number = v_card_number;

    assert_number('Generated CARD_NUMBER is unique', v_count, 1);

    ------------------------------------------------------------------------
    -- 2. Audit verification
    ------------------------------------------------------------------------
    header('2. Audit verification');

    SELECT COUNT(*)
      INTO v_count
      FROM audit_logs
     WHERE entity_name = 'CARDS'
       AND entity_id = TO_CHAR(v_card_id)
       AND action_type = 'INSERT'
       AND operation_name = 'ISSUE_CARD';

    assert_number('ISSUE_CARD creates an audit record', v_count, 1);

    ROLLBACK TO suite_start;

    ------------------------------------------------------------------------
    -- 3. Validation tests
    ------------------------------------------------------------------------
    header('3. Validation tests');

    BEGIN
        pkg_card_management.issue_card(
            p_account_id   => NULL,
            p_card_type_id => v_card_type_id,
            p_created_by   => 'PKG_CARD_TEST',
            p_card_id      => v_card_id,
            p_card_number  => v_card_number
        );
        fail('Rejects NULL account ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            expected_error('Rejects NULL account ID', -20410, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_card_management.issue_card(
            p_account_id   => v_account_id,
            p_card_type_id => NULL,
            p_created_by   => 'PKG_CARD_TEST',
            p_card_id      => v_card_id,
            p_card_number  => v_card_number
        );
        fail('Rejects NULL card type ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            expected_error('Rejects NULL card type ID', -20411, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_card_management.issue_card(
            p_account_id   => -999999,
            p_card_type_id => v_card_type_id,
            p_created_by   => 'PKG_CARD_TEST',
            p_card_id      => v_card_id,
            p_card_number  => v_card_number
        );
        fail('Rejects unknown account', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            expected_error('Rejects unknown account', -20412, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_card_management.issue_card(
            p_account_id   => v_account_id,
            p_card_type_id => -999999,
            p_created_by   => 'PKG_CARD_TEST',
            p_card_id      => v_card_id,
            p_card_number  => v_card_number
        );
        fail('Rejects unknown card type', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            expected_error('Rejects unknown card type', -20414, SQLCODE, SQLERRM);
    END;

    ------------------------------------------------------------------------
    -- 4. NULL CREATED_BY fallback
    ------------------------------------------------------------------------
    header('4. NULL CREATED_BY fallback');

    SAVEPOINT created_by_test;

    pkg_card_management.issue_card(
        p_account_id   => v_account_id,
        p_card_type_id => v_card_type_id,
        p_created_by   => NULL,
        p_card_id      => v_card_id,
        p_card_number  => v_card_number
    );

    SELECT created_by
      INTO v_db_created_by
      FROM cards
     WHERE card_id = v_card_id;

    assert_text('NULL CREATED_BY falls back to USER', v_db_created_by, USER);

    ROLLBACK TO created_by_test;

    ------------------------------------------------------------------------
    -- 5. Consecutive issuance
    ------------------------------------------------------------------------
    header('5. Consecutive issuance');

    SAVEPOINT repeated_test;

    pkg_card_management.issue_card(
        p_account_id   => v_account_id,
        p_card_type_id => v_card_type_id,
        p_created_by   => 'PKG_CARD_TEST',
        p_card_id      => v_card_id,
        p_card_number  => v_card_number
    );

    pkg_card_management.issue_card(
        p_account_id   => v_account_id,
        p_card_type_id => v_card_type_id,
        p_created_by   => 'PKG_CARD_TEST',
        p_card_id      => v_second_card_id,
        p_card_number  => v_second_card_number
    );

    assert_true(
        'Consecutive CARD_ID values are different',
        v_card_id <> v_second_card_id
    );

    assert_true(
        'Consecutive CARD_NUMBER values are different',
        v_card_number <> v_second_card_number
    );

    SELECT COUNT(*)
      INTO v_count
      FROM cards
     WHERE card_id IN (v_card_id, v_second_card_id);

    assert_number('Both issued cards exist before rollback', v_count, 2);

    ROLLBACK TO repeated_test;

    ------------------------------------------------------------------------
    -- 6. Optional inactive account test
    ------------------------------------------------------------------------
    header('6. Optional inactive account test');

    IF v_inactive_account_id IS NOT NULL THEN
        BEGIN
            pkg_card_management.issue_card(
                p_account_id   => v_inactive_account_id,
                p_card_type_id => v_card_type_id,
                p_created_by   => 'PKG_CARD_TEST',
                p_card_id      => v_card_id,
                p_card_number  => v_card_number
            );
            fail('Rejects inactive account', 'No error was raised.');
        EXCEPTION
            WHEN OTHERS THEN
                expected_error('Rejects inactive account', -20413, SQLCODE, SQLERRM);
        END;
    ELSE
        DBMS_OUTPUT.PUT_LINE('[SKIP] No inactive account was found.');
    END IF;

    ------------------------------------------------------------------------
    -- 7. Cleanup verification
    ------------------------------------------------------------------------
    header('7. Cleanup verification');

    ROLLBACK TO suite_start;

    SELECT COUNT(*)
      INTO v_count
      FROM cards
     WHERE created_by = 'PKG_CARD_TEST'
       AND created_at >= SYSTIMESTAMP - INTERVAL '10' MINUTE;

    assert_number('Test cards were rolled back', v_count, 0);

    ------------------------------------------------------------------------
    -- Summary
    ------------------------------------------------------------------------
    header('TEST SUMMARY');
    DBMS_OUTPUT.PUT_LINE('Total tests  : ' || v_total_tests);
    DBMS_OUTPUT.PUT_LINE('Passed tests : ' || v_passed_tests);
    DBMS_OUTPUT.PUT_LINE('Failed tests : ' || v_failed_tests);

    IF v_failed_tests = 0 THEN
        DBMS_OUTPUT.PUT_LINE('RESULT       : ALL TESTS PASSED');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULT       : SOME TESTS FAILED');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('[FATAL] Active account or card type was not found.');
        DBMS_OUTPUT.PUT_LINE(SQLCODE || ': ' || SQLERRM);

    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('[FATAL] Test suite stopped unexpectedly.');
        DBMS_OUTPUT.PUT_LINE(SQLCODE || ': ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END;
/

PROMPT
PROMPT ================================================================================
PROMPT SECTION 2: ACTIVATE_CARD
PROMPT ================================================================================
PROMPT

DECLARE
    ------------------------------------------------------------------------
    -- Reusable test data
    ------------------------------------------------------------------------
    v_account_id          accounts.account_id%TYPE;
    v_card_type_id        card_types.card_type_id%TYPE;

    v_card_id             cards.card_id%TYPE;
    v_card_number         cards.card_number%TYPE;

    v_status              cards.status%TYPE;
    v_updated_at          cards.updated_at%TYPE;
    v_updated_by          cards.updated_by%TYPE;
    v_original_account_status accounts.status%TYPE;

    v_count               PLS_INTEGER;
    v_total_tests         PLS_INTEGER := 0;
    v_passed_tests        PLS_INTEGER := 0;
    v_failed_tests        PLS_INTEGER := 0;

    ------------------------------------------------------------------------
    -- Output and assertion helpers
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
    -- Creates a new test card, then changes it to the requested status.
    ------------------------------------------------------------------------
    PROCEDURE create_test_card(
        p_status      IN cards.status%TYPE,
        p_card_id     OUT cards.card_id%TYPE,
        p_card_number OUT cards.card_number%TYPE
    ) IS
    BEGIN
        pkg_card_management.issue_card(
            p_account_id   => v_account_id,
            p_card_type_id => v_card_type_id,
            p_created_by   => 'PKG_CARD_TEST',
            p_card_id      => p_card_id,
            p_card_number  => p_card_number
        );

        UPDATE cards
           SET status     = p_status,
               updated_at = NULL,
               updated_by = NULL
         WHERE card_id = p_card_id;
    END create_test_card;

BEGIN
    ------------------------------------------------------------------------
    -- Select reusable master data
    ------------------------------------------------------------------------
    SELECT account_id,
           status
      INTO v_account_id,
           v_original_account_status
      FROM (
            SELECT account_id,
                   status
              FROM accounts
             WHERE UPPER(TRIM(status)) = 'ACTIVE'
             ORDER BY account_id
           )
     WHERE ROWNUM = 1;

    SELECT card_type_id
      INTO v_card_type_id
      FROM (
            SELECT card_type_id
              FROM card_types
             ORDER BY card_type_id
           )
     WHERE ROWNUM = 1;

    DBMS_OUTPUT.PUT_LINE('Selected active account : ' || v_account_id);
    DBMS_OUTPUT.PUT_LINE('Selected card type      : ' || v_card_type_id);

    SAVEPOINT activate_card_suite_start;

    ------------------------------------------------------------------------
    -- 1. Successful BLOCKED -> ACTIVE transition
    ------------------------------------------------------------------------
    print_header('1. Successful BLOCKED to ACTIVE transition');

    create_test_card(
        p_status      => 'BLOCKED',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    pkg_card_management.activate_card(
        p_card_id    => v_card_id,
        p_updated_by => 'ACTIVATE_TEST'
    );

    SELECT status,
           updated_at,
           updated_by
      INTO v_status,
           v_updated_at,
           v_updated_by
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text(
        'BLOCKED card becomes ACTIVE',
        v_status,
        'ACTIVE'
    );

    assert_true(
        'UPDATED_AT is populated',
        v_updated_at IS NOT NULL
    );

    assert_equal_text(
        'UPDATED_BY is stored correctly',
        v_updated_by,
        'ACTIVATE_TEST'
    );

    ------------------------------------------------------------------------
    -- 2. Audit verification
    ------------------------------------------------------------------------
    print_header('2. Audit verification');

    SELECT COUNT(*)
      INTO v_count
      FROM audit_logs
     WHERE entity_name = 'CARDS'
       AND entity_id = TO_CHAR(v_card_id)
       AND action_type = 'UPDATE'
       AND operation_name = 'ACTIVATE_CARD';

    assert_equal_number(
        'ACTIVATE_CARD creates one audit record',
        v_count,
        1
    );

    ------------------------------------------------------------------------
    -- 3. NULL UPDATED_BY fallback
    ------------------------------------------------------------------------
    print_header('3. NULL UPDATED_BY fallback');

    ROLLBACK TO activate_card_suite_start;
    SAVEPOINT null_updated_by_test;

    create_test_card(
        p_status      => 'BLOCKED',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    pkg_card_management.activate_card(
        p_card_id    => v_card_id,
        p_updated_by => NULL
    );

    SELECT status,
           updated_by
      INTO v_status,
           v_updated_by
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text(
        'Card is activated when UPDATED_BY is NULL',
        v_status,
        'ACTIVE'
    );

    assert_equal_text(
        'NULL UPDATED_BY falls back to USER',
        v_updated_by,
        USER
    );

    ROLLBACK TO null_updated_by_test;

    ------------------------------------------------------------------------
    -- 4. NULL CARD_ID validation
    ------------------------------------------------------------------------
    print_header('4. NULL CARD_ID validation');

    BEGIN
        pkg_card_management.activate_card(
            p_card_id    => NULL,
            p_updated_by => 'ACTIVATE_TEST'
        );

        fail_test(
            'ACTIVATE_CARD rejects NULL card ID',
            'No error was raised.'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'ACTIVATE_CARD rejects NULL card ID',
                -20420,
                SQLCODE,
                SQLERRM
            );
    END;

    ------------------------------------------------------------------------
    -- 5. Unknown card validation
    ------------------------------------------------------------------------
    print_header('5. Unknown card validation');

    BEGIN
        pkg_card_management.activate_card(
            p_card_id    => -999999,
            p_updated_by => 'ACTIVATE_TEST'
        );

        fail_test(
            'ACTIVATE_CARD rejects unknown card',
            'No error was raised.'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'ACTIVATE_CARD rejects unknown card',
                -20421,
                SQLCODE,
                SQLERRM
            );
    END;

    ------------------------------------------------------------------------
    -- 6. Already ACTIVE validation
    ------------------------------------------------------------------------
    print_header('6. Already ACTIVE validation');

    ROLLBACK TO activate_card_suite_start;
    SAVEPOINT active_card_test;

    create_test_card(
        p_status      => 'ACTIVE',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    BEGIN
        pkg_card_management.activate_card(
            p_card_id    => v_card_id,
            p_updated_by => 'ACTIVATE_TEST'
        );

        fail_test(
            'ACTIVATE_CARD rejects already active card',
            'No error was raised.'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'ACTIVATE_CARD rejects already active card',
                -20422,
                SQLCODE,
                SQLERRM
            );
    END;

    SELECT status
      INTO v_status
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text(
        'Already active card remains ACTIVE after rejection',
        v_status,
        'ACTIVE'
    );

    ROLLBACK TO active_card_test;

    ------------------------------------------------------------------------
    -- 7. CLOSED card validation
    ------------------------------------------------------------------------
    print_header('7. CLOSED card validation');

    SAVEPOINT closed_card_test;

    create_test_card(
        p_status      => 'CLOSED',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    BEGIN
        pkg_card_management.activate_card(
            p_card_id    => v_card_id,
            p_updated_by => 'ACTIVATE_TEST'
        );

        fail_test(
            'ACTIVATE_CARD rejects closed card',
            'No error was raised.'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'ACTIVATE_CARD rejects closed card',
                -20423,
                SQLCODE,
                SQLERRM
            );
    END;

    SELECT status
      INTO v_status
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text(
        'Closed card remains CLOSED after rejection',
        v_status,
        'CLOSED'
    );

    ROLLBACK TO closed_card_test;

    ------------------------------------------------------------------------
    -- 8. Inactive linked account validation
    ------------------------------------------------------------------------
    print_header('8. Inactive linked account validation');

    SAVEPOINT inactive_account_test;

    create_test_card(
        p_status      => 'BLOCKED',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    UPDATE accounts
       SET status = 'CLOSED'
     WHERE account_id = v_account_id;

    BEGIN
        pkg_card_management.activate_card(
            p_card_id    => v_card_id,
            p_updated_by => 'ACTIVATE_TEST'
        );

        fail_test(
            'ACTIVATE_CARD rejects card linked to inactive account',
            'No error was raised.'
        );
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'ACTIVATE_CARD rejects card linked to inactive account',
                -20426,
                SQLCODE,
                SQLERRM
            );
    END;

    SELECT status
      INTO v_status
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text(
        'Card remains BLOCKED when linked account is inactive',
        v_status,
        'BLOCKED'
    );

    ROLLBACK TO inactive_account_test;

    ------------------------------------------------------------------------
    -- 9. No audit record on rejected operation
    ------------------------------------------------------------------------
    print_header('9. Audit behavior on rejected operation');

    SAVEPOINT rejected_audit_test;

    create_test_card(
        p_status      => 'ACTIVE',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    BEGIN
        pkg_card_management.activate_card(
            p_card_id    => v_card_id,
            p_updated_by => 'ACTIVATE_TEST'
        );
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;

    SELECT COUNT(*)
      INTO v_count
      FROM audit_logs
     WHERE entity_name = 'CARDS'
       AND entity_id = TO_CHAR(v_card_id)
       AND action_type = 'UPDATE'
       AND operation_name = 'ACTIVATE_CARD';

    assert_equal_number(
        'Rejected activation creates no success audit record',
        v_count,
        0
    );

    ROLLBACK TO rejected_audit_test;

    ------------------------------------------------------------------------
    -- 10. Cleanup verification
    ------------------------------------------------------------------------
    print_header('10. Cleanup verification');

    ROLLBACK TO activate_card_suite_start;

    SELECT COUNT(*)
      INTO v_count
      FROM cards
     WHERE created_by = 'PKG_CARD_TEST'
       AND created_at >= SYSTIMESTAMP - INTERVAL '10' MINUTE;

    assert_equal_number(
        'All ACTIVATE_CARD test cards were rolled back',
        v_count,
        0
    );

    SELECT status
      INTO v_status
      FROM accounts
     WHERE account_id = v_account_id;

    assert_equal_text(
        'Test account status was restored',
        v_status,
        v_original_account_status
    );

    ------------------------------------------------------------------------
    -- Summary
    ------------------------------------------------------------------------
    print_header('TEST SUMMARY');

    DBMS_OUTPUT.PUT_LINE('Total tests  : ' || v_total_tests);
    DBMS_OUTPUT.PUT_LINE('Passed tests : ' || v_passed_tests);
    DBMS_OUTPUT.PUT_LINE('Failed tests : ' || v_failed_tests);

    IF v_failed_tests = 0 THEN
        DBMS_OUTPUT.PUT_LINE('RESULT       : ALL TESTS PASSED');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULT       : SOME TESTS FAILED');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            '[FATAL] Required active account or card type could not be found.'
        );
        DBMS_OUTPUT.PUT_LINE(SQLCODE || ': ' || SQLERRM);

    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('[FATAL] Test suite stopped unexpectedly.');
        DBMS_OUTPUT.PUT_LINE(SQLCODE || ': ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END;
/

PROMPT
PROMPT ================================================================================
PROMPT SECTION 3: BLOCK_CARD, CLOSE_CARD, GET_CARD_INFO, GET_ACCOUNT_CARDS
PROMPT ================================================================================
PROMPT

DECLARE
    ------------------------------------------------------------------------
    -- Reusable master data
    ------------------------------------------------------------------------
    v_account_id          accounts.account_id%TYPE;
    v_empty_account_id    accounts.account_id%TYPE;
    v_card_type_id        card_types.card_type_id%TYPE;

    ------------------------------------------------------------------------
    -- Reusable card values
    ------------------------------------------------------------------------
    v_card_id             cards.card_id%TYPE;
    v_card_number         cards.card_number%TYPE;
    v_second_card_id      cards.card_id%TYPE;
    v_second_card_number  cards.card_number%TYPE;

    ------------------------------------------------------------------------
    -- Retrieved values
    ------------------------------------------------------------------------
    v_status              cards.status%TYPE;
    v_updated_at          cards.updated_at%TYPE;
    v_updated_by          cards.updated_by%TYPE;
    v_count               PLS_INTEGER;

    ------------------------------------------------------------------------
    -- Ref cursor values
    ------------------------------------------------------------------------
    v_cursor              SYS_REFCURSOR;
    v_rc_card_id          cards.card_id%TYPE;
    v_rc_account_id       cards.account_id%TYPE;
    v_rc_card_type_id     cards.card_type_id%TYPE;
    v_rc_card_type_name   card_types.type_name%TYPE;
    v_rc_card_number      cards.card_number%TYPE;
    v_rc_expiry_date      cards.expiry_date%TYPE;
    v_rc_status           cards.status%TYPE;
    v_rc_created_at       cards.created_at%TYPE;
    v_rc_created_by       cards.created_by%TYPE;
    v_rc_updated_at       cards.updated_at%TYPE;
    v_rc_updated_by       cards.updated_by%TYPE;

    ------------------------------------------------------------------------
    -- Test counters
    ------------------------------------------------------------------------
    v_total_tests         PLS_INTEGER := 0;
    v_passed_tests        PLS_INTEGER := 0;
    v_failed_tests        PLS_INTEGER := 0;

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
    -- Creates a new card and optionally changes its status.
    ------------------------------------------------------------------------
    PROCEDURE create_test_card(
        p_status      IN cards.status%TYPE,
        p_card_id     OUT cards.card_id%TYPE,
        p_card_number OUT cards.card_number%TYPE
    ) IS
    BEGIN
        pkg_card_management.issue_card(
            p_account_id   => v_account_id,
            p_card_type_id => v_card_type_id,
            p_created_by   => 'PKG_CARD_TEST',
            p_card_id      => p_card_id,
            p_card_number  => p_card_number
        );

        IF p_status <> 'ACTIVE' THEN
            UPDATE cards
               SET status     = p_status,
                   updated_at = NULL,
                   updated_by = NULL
             WHERE card_id = p_card_id;
        END IF;
    END create_test_card;

BEGIN
    ------------------------------------------------------------------------
    -- Locate reusable data
    ------------------------------------------------------------------------
    SELECT account_id
      INTO v_account_id
      FROM (
            SELECT account_id
              FROM accounts
             WHERE UPPER(TRIM(status)) = 'ACTIVE'
             ORDER BY account_id
           )
     WHERE ROWNUM = 1;

    SELECT card_type_id
      INTO v_card_type_id
      FROM (
            SELECT card_type_id
              FROM card_types
             ORDER BY card_type_id
           )
     WHERE ROWNUM = 1;

    BEGIN
        SELECT account_id
          INTO v_empty_account_id
          FROM (
                SELECT a.account_id
                  FROM accounts a
                 WHERE NOT EXISTS (
                           SELECT 1
                             FROM cards c
                            WHERE c.account_id = a.account_id
                       )
                 ORDER BY a.account_id
               )
         WHERE ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_empty_account_id := NULL;
    END;

    DBMS_OUTPUT.PUT_LINE('Selected active account : ' || v_account_id);
    DBMS_OUTPUT.PUT_LINE('Selected card type      : ' || v_card_type_id);
    DBMS_OUTPUT.PUT_LINE(
        'Selected empty account    : ' ||
        NVL(TO_CHAR(v_empty_account_id), 'NONE')
    );

    SAVEPOINT full_suite_start;

    -- ============================================================================
    -- BLOCK_CARD TESTS
    -- ============================================================================

    ------------------------------------------------------------------------
    -- 1. Successful ACTIVE -> BLOCKED transition
    ------------------------------------------------------------------------
    print_header('1. BLOCK_CARD successful transition');

    create_test_card(
        p_status      => 'ACTIVE',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    pkg_card_management.block_card(
        p_card_id    => v_card_id,
        p_updated_by => 'BLOCK_TEST'
    );

    SELECT status,
           updated_at,
           updated_by
      INTO v_status,
           v_updated_at,
           v_updated_by
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text('ACTIVE card becomes BLOCKED', v_status, 'BLOCKED');
    assert_true('BLOCK_CARD populates UPDATED_AT', v_updated_at IS NOT NULL);
    assert_equal_text('BLOCK_CARD stores UPDATED_BY', v_updated_by, 'BLOCK_TEST');

    SELECT COUNT(*)
      INTO v_count
      FROM audit_logs
     WHERE entity_name = 'CARDS'
       AND entity_id = TO_CHAR(v_card_id)
       AND action_type = 'UPDATE'
       AND operation_name = 'BLOCK_CARD';

    assert_equal_number('BLOCK_CARD creates one audit record', v_count, 1);

    ------------------------------------------------------------------------
    -- 2. BLOCK_CARD NULL UPDATED_BY fallback
    ------------------------------------------------------------------------
    print_header('2. BLOCK_CARD NULL UPDATED_BY fallback');

    ROLLBACK TO full_suite_start;
    SAVEPOINT block_null_user_test;

    create_test_card(
        p_status      => 'ACTIVE',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    pkg_card_management.block_card(
        p_card_id    => v_card_id,
        p_updated_by => NULL
    );

    SELECT status,
           updated_by
      INTO v_status,
           v_updated_by
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text('Card is blocked with NULL UPDATED_BY', v_status, 'BLOCKED');
    assert_equal_text('BLOCK_CARD NULL UPDATED_BY uses USER', v_updated_by, USER);

    ROLLBACK TO block_null_user_test;

    ------------------------------------------------------------------------
    -- 3. BLOCK_CARD validation errors
    ------------------------------------------------------------------------
    print_header('3. BLOCK_CARD validation errors');

    BEGIN
        pkg_card_management.block_card(
            p_card_id    => NULL,
            p_updated_by => 'BLOCK_TEST'
        );
        fail_test('BLOCK_CARD rejects NULL card ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'BLOCK_CARD rejects NULL card ID',
                -20430,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_card_management.block_card(
            p_card_id    => -999999,
            p_updated_by => 'BLOCK_TEST'
        );
        fail_test('BLOCK_CARD rejects unknown card', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'BLOCK_CARD rejects unknown card',
                -20431,
                SQLCODE,
                SQLERRM
            );
    END;

    SAVEPOINT already_blocked_test;

    create_test_card(
        p_status      => 'BLOCKED',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    BEGIN
        pkg_card_management.block_card(
            p_card_id    => v_card_id,
            p_updated_by => 'BLOCK_TEST'
        );
        fail_test('BLOCK_CARD rejects already blocked card', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'BLOCK_CARD rejects already blocked card',
                -20432,
                SQLCODE,
                SQLERRM
            );
    END;

    SELECT status
      INTO v_status
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text('Already blocked card remains BLOCKED', v_status, 'BLOCKED');

    ROLLBACK TO already_blocked_test;
    SAVEPOINT block_closed_test;

    create_test_card(
        p_status      => 'CLOSED',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    BEGIN
        pkg_card_management.block_card(
            p_card_id    => v_card_id,
            p_updated_by => 'BLOCK_TEST'
        );
        fail_test('BLOCK_CARD rejects closed card', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'BLOCK_CARD rejects closed card',
                -20433,
                SQLCODE,
                SQLERRM
            );
    END;

    SELECT status
      INTO v_status
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text('Closed card remains CLOSED after block rejection', v_status, 'CLOSED');

    ROLLBACK TO block_closed_test;

    -- ============================================================================
    -- CLOSE_CARD TESTS
    -- ============================================================================

    ------------------------------------------------------------------------
    -- 4. CLOSE_CARD from ACTIVE
    ------------------------------------------------------------------------
    print_header('4. CLOSE_CARD successful ACTIVE to CLOSED transition');

    SAVEPOINT close_active_test;

    create_test_card(
        p_status      => 'ACTIVE',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    pkg_card_management.close_card(
        p_card_id    => v_card_id,
        p_updated_by => 'CLOSE_TEST'
    );

    SELECT status,
           updated_at,
           updated_by
      INTO v_status,
           v_updated_at,
           v_updated_by
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text('ACTIVE card becomes CLOSED', v_status, 'CLOSED');
    assert_true('CLOSE_CARD populates UPDATED_AT', v_updated_at IS NOT NULL);
    assert_equal_text('CLOSE_CARD stores UPDATED_BY', v_updated_by, 'CLOSE_TEST');

    SELECT COUNT(*)
      INTO v_count
      FROM audit_logs
     WHERE entity_name = 'CARDS'
       AND entity_id = TO_CHAR(v_card_id)
       AND action_type = 'UPDATE'
       AND operation_name = 'CLOSE_CARD';

    assert_equal_number('CLOSE_CARD creates one audit record', v_count, 1);

    ROLLBACK TO close_active_test;

    ------------------------------------------------------------------------
    -- 5. CLOSE_CARD from BLOCKED
    ------------------------------------------------------------------------
    print_header('5. CLOSE_CARD successful BLOCKED to CLOSED transition');

    SAVEPOINT close_blocked_test;

    create_test_card(
        p_status      => 'BLOCKED',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    pkg_card_management.close_card(
        p_card_id    => v_card_id,
        p_updated_by => 'CLOSE_TEST'
    );

    SELECT status
      INTO v_status
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text('BLOCKED card becomes CLOSED', v_status, 'CLOSED');

    ROLLBACK TO close_blocked_test;

    ------------------------------------------------------------------------
    -- 6. CLOSE_CARD NULL UPDATED_BY fallback
    ------------------------------------------------------------------------
    print_header('6. CLOSE_CARD NULL UPDATED_BY fallback');

    SAVEPOINT close_null_user_test;

    create_test_card(
        p_status      => 'ACTIVE',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    pkg_card_management.close_card(
        p_card_id    => v_card_id,
        p_updated_by => NULL
    );

    SELECT updated_by
      INTO v_updated_by
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text('CLOSE_CARD NULL UPDATED_BY uses USER', v_updated_by, USER);

    ROLLBACK TO close_null_user_test;

    ------------------------------------------------------------------------
    -- 7. CLOSE_CARD validation errors
    ------------------------------------------------------------------------
    print_header('7. CLOSE_CARD validation errors');

    BEGIN
        pkg_card_management.close_card(
            p_card_id    => NULL,
            p_updated_by => 'CLOSE_TEST'
        );
        fail_test('CLOSE_CARD rejects NULL card ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'CLOSE_CARD rejects NULL card ID',
                -20440,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_card_management.close_card(
            p_card_id    => -999999,
            p_updated_by => 'CLOSE_TEST'
        );
        fail_test('CLOSE_CARD rejects unknown card', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'CLOSE_CARD rejects unknown card',
                -20441,
                SQLCODE,
                SQLERRM
            );
    END;

    SAVEPOINT already_closed_test;

    create_test_card(
        p_status      => 'CLOSED',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    BEGIN
        pkg_card_management.close_card(
            p_card_id    => v_card_id,
            p_updated_by => 'CLOSE_TEST'
        );
        fail_test('CLOSE_CARD rejects already closed card', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'CLOSE_CARD rejects already closed card',
                -20442,
                SQLCODE,
                SQLERRM
            );
    END;

    SELECT status
      INTO v_status
      FROM cards
     WHERE card_id = v_card_id;

    assert_equal_text('Already closed card remains CLOSED', v_status, 'CLOSED');

    ROLLBACK TO already_closed_test;

    -- ============================================================================
    -- GET_CARD_INFO TESTS
    -- ============================================================================

    ------------------------------------------------------------------------
    -- 8. GET_CARD_INFO successful retrieval
    ------------------------------------------------------------------------
    print_header('8. GET_CARD_INFO successful retrieval');

    SAVEPOINT get_card_info_test;

    create_test_card(
        p_status      => 'ACTIVE',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    pkg_card_management.get_card_info(
        p_card_id => v_card_id,
        p_result  => v_cursor
    );

    FETCH v_cursor
     INTO v_rc_card_id,
          v_rc_account_id,
          v_rc_card_type_id,
          v_rc_card_type_name,
          v_rc_card_number,
          v_rc_expiry_date,
          v_rc_status,
          v_rc_created_at,
          v_rc_created_by,
          v_rc_updated_at,
          v_rc_updated_by;

    assert_true('GET_CARD_INFO returns one row', v_cursor%FOUND);
    assert_equal_number('GET_CARD_INFO returns correct CARD_ID', v_rc_card_id, v_card_id);
    assert_equal_number('GET_CARD_INFO returns correct ACCOUNT_ID', v_rc_account_id, v_account_id);
    assert_equal_number('GET_CARD_INFO returns correct CARD_TYPE_ID', v_rc_card_type_id, v_card_type_id);
    assert_equal_text('GET_CARD_INFO returns correct CARD_NUMBER', v_rc_card_number, v_card_number);
    assert_equal_text('GET_CARD_INFO returns ACTIVE status', v_rc_status, 'ACTIVE');
    assert_true('GET_CARD_INFO returns CARD_TYPE_NAME', v_rc_card_type_name IS NOT NULL);
    assert_true('GET_CARD_INFO returns CREATED_AT', v_rc_created_at IS NOT NULL);

    FETCH v_cursor
     INTO v_rc_card_id,
          v_rc_account_id,
          v_rc_card_type_id,
          v_rc_card_type_name,
          v_rc_card_number,
          v_rc_expiry_date,
          v_rc_status,
          v_rc_created_at,
          v_rc_created_by,
          v_rc_updated_at,
          v_rc_updated_by;

    assert_true('GET_CARD_INFO returns only one row', v_cursor%NOTFOUND);

    CLOSE v_cursor;

    ROLLBACK TO get_card_info_test;

    ------------------------------------------------------------------------
    -- 9. GET_CARD_INFO validation errors
    ------------------------------------------------------------------------
    print_header('9. GET_CARD_INFO validation errors');

    BEGIN
        pkg_card_management.get_card_info(
            p_card_id => NULL,
            p_result  => v_cursor
        );
        fail_test('GET_CARD_INFO rejects NULL card ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'GET_CARD_INFO rejects NULL card ID',
                -20450,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_card_management.get_card_info(
            p_card_id => -999999,
            p_result  => v_cursor
        );
        fail_test('GET_CARD_INFO rejects unknown card', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'GET_CARD_INFO rejects unknown card',
                -20451,
                SQLCODE,
                SQLERRM
            );
    END;

    -- ============================================================================
    -- GET_ACCOUNT_CARDS TESTS
    -- ============================================================================

    ------------------------------------------------------------------------
    -- 10. GET_ACCOUNT_CARDS successful retrieval
    ------------------------------------------------------------------------
    print_header('10. GET_ACCOUNT_CARDS successful retrieval');

    SAVEPOINT get_account_cards_test;

    create_test_card(
        p_status      => 'ACTIVE',
        p_card_id     => v_card_id,
        p_card_number => v_card_number
    );

    create_test_card(
        p_status      => 'BLOCKED',
        p_card_id     => v_second_card_id,
        p_card_number => v_second_card_number
    );

    pkg_card_management.get_account_cards(
        p_account_id => v_account_id,
        p_result     => v_cursor
    );

    v_count := 0;

    LOOP
        FETCH v_cursor
         INTO v_rc_card_id,
              v_rc_account_id,
              v_rc_card_type_id,
              v_rc_card_type_name,
              v_rc_card_number,
              v_rc_expiry_date,
              v_rc_status,
              v_rc_created_at,
              v_rc_created_by,
              v_rc_updated_at,
              v_rc_updated_by;

        EXIT WHEN v_cursor%NOTFOUND;

        v_count := v_count + 1;

        IF v_rc_account_id <> v_account_id THEN
            fail_test(
                'GET_ACCOUNT_CARDS only returns requested account',
                'Unexpected ACCOUNT_ID=' || v_rc_account_id
            );
        END IF;
    END LOOP;

    CLOSE v_cursor;

    assert_true(
        'GET_ACCOUNT_CARDS returns at least the two test cards',
        v_count >= 2,
        'Returned row count=' || v_count
    );

    SELECT COUNT(*)
      INTO v_count
      FROM cards
     WHERE account_id = v_account_id
       AND card_id IN (v_card_id, v_second_card_id);

    assert_equal_number(
        'Both test cards belong to selected account',
        v_count,
        2
    );

    ROLLBACK TO get_account_cards_test;

    ------------------------------------------------------------------------
    -- 11. GET_ACCOUNT_CARDS empty result
    ------------------------------------------------------------------------
    print_header('11. GET_ACCOUNT_CARDS empty result');

    IF v_empty_account_id IS NOT NULL THEN
        pkg_card_management.get_account_cards(
            p_account_id => v_empty_account_id,
            p_result     => v_cursor
        );

        FETCH v_cursor
         INTO v_rc_card_id,
              v_rc_account_id,
              v_rc_card_type_id,
              v_rc_card_type_name,
              v_rc_card_number,
              v_rc_expiry_date,
              v_rc_status,
              v_rc_created_at,
              v_rc_created_by,
              v_rc_updated_at,
              v_rc_updated_by;

        assert_true(
            'Existing account without cards returns empty cursor',
            v_cursor%NOTFOUND
        );

        CLOSE v_cursor;
    ELSE
        DBMS_OUTPUT.PUT_LINE('[SKIP] No account without cards was found.');
    END IF;

    ------------------------------------------------------------------------
    -- 12. GET_ACCOUNT_CARDS validation errors
    ------------------------------------------------------------------------
    print_header('12. GET_ACCOUNT_CARDS validation errors');

    BEGIN
        pkg_card_management.get_account_cards(
            p_account_id => NULL,
            p_result     => v_cursor
        );
        fail_test('GET_ACCOUNT_CARDS rejects NULL account ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'GET_ACCOUNT_CARDS rejects NULL account ID',
                -20460,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_card_management.get_account_cards(
            p_account_id => -999999,
            p_result     => v_cursor
        );
        fail_test('GET_ACCOUNT_CARDS rejects unknown account', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'GET_ACCOUNT_CARDS rejects unknown account',
                -20461,
                SQLCODE,
                SQLERRM
            );
    END;

    ------------------------------------------------------------------------
    -- 13. Cleanup verification
    ------------------------------------------------------------------------
    print_header('13. Cleanup verification');

    ROLLBACK TO full_suite_start;

    SELECT COUNT(*)
      INTO v_count
      FROM cards
     WHERE created_by = 'PKG_CARD_TEST'
       AND created_at >= SYSTIMESTAMP - INTERVAL '15' MINUTE;

    assert_equal_number(
        'All test cards were rolled back',
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
        DBMS_OUTPUT.PUT_LINE('RESULT       : ALL TESTS PASSED');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULT       : SOME TESTS FAILED');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        IF v_cursor%ISOPEN THEN
            CLOSE v_cursor;
        END IF;

        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            '[FATAL] Required active account or card type could not be found.'
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
PROMPT ERROR-LOG INTEGRATION AND CLEANUP
PROMPT ================================================================================
PROMPT

DECLARE
    l_count PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO l_count
      FROM error_logs
     WHERE logged_at >= TO_TIMESTAMP(
               :g_card_test_started_at,
               'YYYYMMDDHH24MISSFF6'
           )
       AND session_id = :g_card_test_session_id
       AND operation_name IN (
           'PKG_CARD_MANAGEMENT.ISSUE_CARD',
           'PKG_CARD_MANAGEMENT.ACTIVATE_CARD',
           'PKG_CARD_MANAGEMENT.BLOCK_CARD',
           'PKG_CARD_MANAGEMENT.CLOSE_CARD',
           'PKG_CARD_MANAGEMENT.GET_CARD_INFO',
           'PKG_CARD_MANAGEMENT.GET_ACCOUNT_CARDS'
       )
       AND error_code BETWEEN -20461 AND -20410;

    IF l_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE(
            '[PASS] Expected package failures were recorded in ERROR_LOGS. Count=' ||
            l_count
        );
    ELSE
        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] No expected PKG_CARD_MANAGEMENT error rows were found.'
        );
    END IF;

    DELETE FROM error_logs
     WHERE logged_at >= TO_TIMESTAMP(
               :g_card_test_started_at,
               'YYYYMMDDHH24MISSFF6'
           )
       AND session_id = :g_card_test_session_id
       AND operation_name IN (
           'PKG_CARD_MANAGEMENT.ISSUE_CARD',
           'PKG_CARD_MANAGEMENT.ACTIVATE_CARD',
           'PKG_CARD_MANAGEMENT.BLOCK_CARD',
           'PKG_CARD_MANAGEMENT.CLOSE_CARD',
           'PKG_CARD_MANAGEMENT.GET_CARD_INFO',
           'PKG_CARD_MANAGEMENT.GET_ACCOUNT_CARDS'
       )
       AND error_code BETWEEN -20461 AND -20410;

    COMMIT;

    SELECT COUNT(*)
      INTO l_count
      FROM error_logs
     WHERE logged_at >= TO_TIMESTAMP(
               :g_card_test_started_at,
               'YYYYMMDDHH24MISSFF6'
           )
       AND session_id = :g_card_test_session_id
       AND operation_name IN (
           'PKG_CARD_MANAGEMENT.ISSUE_CARD',
           'PKG_CARD_MANAGEMENT.ACTIVATE_CARD',
           'PKG_CARD_MANAGEMENT.BLOCK_CARD',
           'PKG_CARD_MANAGEMENT.CLOSE_CARD',
           'PKG_CARD_MANAGEMENT.GET_CARD_INFO',
           'PKG_CARD_MANAGEMENT.GET_ACCOUNT_CARDS'
       )
       AND error_code BETWEEN -20461 AND -20410;

    IF l_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE(
            '[PASS] Test-generated ERROR_LOGS rows were removed.'
        );
    ELSE
        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] Test-generated ERROR_LOGS rows remain. Count=' || l_count
        );
    END IF;
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

SELECT name,
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
 ORDER BY name,
          sequence;

PROMPT
PROMPT ================================================================================
PROMPT PKG_CARD_MANAGEMENT COMPLETE TEST SUITE FINISHED
PROMPT Review the summary of each section. Every section must report zero failures.
PROMPT =======================================================================