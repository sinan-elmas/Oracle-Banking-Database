-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / PL/SQL Tests / Package Tests
-- Script       : 07_PKG_EXCHANGE_RATE_MANAGEMENT_Test.sql
-- Purpose      : Regression validation for PKG_EXCHANGE_RATE_MANAGEMENT
-- Safety       : Business test data is rolled back; autonomous test error logs
--                are removed after verification.
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

VARIABLE g_rate_test_session_id NUMBER

BEGIN
    :g_rate_test_session_id := TO_NUMBER(SYS_CONTEXT('USERENV', 'SESSIONID'));

    DELETE FROM error_logs
     WHERE session_id = :g_rate_test_session_id
       AND operation_name IN (
           'PKG_EXCHANGE_RATE_MANAGEMENT.ADD_EXCHANGE_RATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.UPDATE_EXCHANGE_RATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.GET_LATEST_RATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.GET_RATE_BY_DATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.CONVERT_AMOUNT'
       )
       AND error_code BETWEEN -20658 AND -20600;
    COMMIT;
END;
/

PROMPT
PROMPT ================================================================================
PROMPT PKG_EXCHANGE_RATE_MANAGEMENT - REGRESSION TEST SUITE
PROMPT ================================================================================
PROMPT
PROMPT --- A. PACKAGE AND API HEALTH ---

SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name = 'PKG_EXCHANGE_RATE_MANAGEMENT'
   AND object_type IN ('PACKAGE','PACKAGE BODY')
 ORDER BY object_type;

SELECT procedure_name
  FROM user_procedures
 WHERE object_name = 'PKG_EXCHANGE_RATE_MANAGEMENT'
   AND procedure_name IS NOT NULL
 ORDER BY procedure_name;

DECLARE
    ------------------------------------------------------------------------
    -- Reusable currency data
    ------------------------------------------------------------------------
    v_currency_id        currencies.currency_id%TYPE;
    v_base_currency_id   currencies.currency_id%TYPE;
    v_third_currency_id  currencies.currency_id%TYPE;

    ------------------------------------------------------------------------
    -- Test rate data
    ------------------------------------------------------------------------
    v_rate_id            exchange_rates.rate_id%TYPE;
    v_second_rate_id     exchange_rates.rate_id%TYPE;
    v_test_date          exchange_rates.rate_date%TYPE;
    v_second_test_date   exchange_rates.rate_date%TYPE;

    v_buy_rate           exchange_rates.buy_rate%TYPE;
    v_sell_rate          exchange_rates.sell_rate%TYPE;
    v_updated_at         exchange_rates.updated_at%TYPE;
    v_updated_by         exchange_rates.updated_by%TYPE;
    v_created_by         exchange_rates.created_by%TYPE;

    ------------------------------------------------------------------------
    -- Conversion results
    ------------------------------------------------------------------------
    v_actual_amount      NUMBER;
    v_expected_amount    NUMBER;

    ------------------------------------------------------------------------
    -- Ref cursor and output variables
    ------------------------------------------------------------------------
    v_cursor             SYS_REFCURSOR;

    v_rc_rate_id         exchange_rates.rate_id%TYPE;
    v_rc_currency_id     exchange_rates.currency_id%TYPE;
    v_rc_currency_code   currencies.currency_code%TYPE;
    v_rc_base_id         exchange_rates.base_currency_id%TYPE;
    v_rc_base_code       currencies.currency_code%TYPE;
    v_rc_buy_rate        exchange_rates.buy_rate%TYPE;
    v_rc_sell_rate       exchange_rates.sell_rate%TYPE;
    v_rc_rate_date       exchange_rates.rate_date%TYPE;
    v_rc_created_at      exchange_rates.created_at%TYPE;
    v_rc_created_by      exchange_rates.created_by%TYPE;
    v_rc_updated_at      exchange_rates.updated_at%TYPE;
    v_rc_updated_by      exchange_rates.updated_by%TYPE;

    ------------------------------------------------------------------------
    -- Test counters
    ------------------------------------------------------------------------
    v_count              PLS_INTEGER;
    v_total_tests        PLS_INTEGER := 0;
    v_passed_tests       PLS_INTEGER := 0;
    v_failed_tests       PLS_INTEGER := 0;

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
        p_expected IN NUMBER,
        p_tolerance IN NUMBER DEFAULT 0.000001
    ) IS
    BEGIN
        IF (p_actual IS NULL AND p_expected IS NULL)
           OR (
               p_actual IS NOT NULL
               AND p_expected IS NOT NULL
               AND ABS(p_actual - p_expected) <= p_tolerance
           )
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
    -- Adds one reusable test rate.
    ------------------------------------------------------------------------
    PROCEDURE create_test_rate(
        p_rate_date IN  DATE,
        p_buy_rate  IN  NUMBER,
        p_sell_rate IN  NUMBER,
        p_rate_id   OUT NUMBER
    ) IS
    BEGIN
        pkg_exchange_rate_management.add_exchange_rate(
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_base_currency_id,
            p_buy_rate         => p_buy_rate,
            p_sell_rate        => p_sell_rate,
            p_rate_date        => p_rate_date,
            p_created_by       => 'PKG_RATE_TEST',
            p_rate_id          => p_rate_id
        );
    END create_test_rate;

BEGIN
    ------------------------------------------------------------------------
    -- Select three existing currencies.
    ------------------------------------------------------------------------
    SELECT currency_id
      INTO v_base_currency_id
      FROM (
            SELECT currency_id
              FROM currencies
             ORDER BY currency_id
           )
     WHERE ROWNUM = 1;

    SELECT currency_id
      INTO v_currency_id
      FROM (
            SELECT currency_id
              FROM currencies
             WHERE currency_id <> v_base_currency_id
             ORDER BY currency_id
           )
     WHERE ROWNUM = 1;

    SELECT currency_id
      INTO v_third_currency_id
      FROM (
            SELECT currency_id
              FROM currencies
             WHERE currency_id NOT IN (
                       v_base_currency_id,
                       v_currency_id
                   )
             ORDER BY currency_id
           )
     WHERE ROWNUM = 1;

    ------------------------------------------------------------------------
    -- Locate two future dates not already used for the test currency pair.
    ------------------------------------------------------------------------
    v_test_date := TRUNC(SYSDATE) + 3650;

    LOOP
        SELECT COUNT(*)
          INTO v_count
          FROM exchange_rates
         WHERE currency_id = v_currency_id
           AND base_currency_id = v_base_currency_id
           AND rate_date = v_test_date;

        EXIT WHEN v_count = 0;
        v_test_date := v_test_date + 1;
    END LOOP;

    v_second_test_date := v_test_date + 1;

    LOOP
        SELECT COUNT(*)
          INTO v_count
          FROM exchange_rates
         WHERE currency_id = v_currency_id
           AND base_currency_id = v_base_currency_id
           AND rate_date = v_second_test_date;

        EXIT WHEN v_count = 0;
        v_second_test_date := v_second_test_date + 1;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Currency ID       : ' || v_currency_id);
    DBMS_OUTPUT.PUT_LINE('Base currency ID  : ' || v_base_currency_id);
    DBMS_OUTPUT.PUT_LINE('Third currency ID : ' || v_third_currency_id);
    DBMS_OUTPUT.PUT_LINE('Test rate date    : ' || TO_CHAR(v_test_date, 'YYYY-MM-DD'));

    SAVEPOINT rate_suite_start;

    ------------------------------------------------------------------------
    -- 1. Successful ADD_EXCHANGE_RATE
    ------------------------------------------------------------------------
    print_header('1. Successful ADD_EXCHANGE_RATE');

    create_test_rate(
        p_rate_date => v_test_date,
        p_buy_rate  => 10.250000,
        p_sell_rate => 10.500000,
        p_rate_id   => v_rate_id
    );

    assert_true(
        'ADD_EXCHANGE_RATE returns RATE_ID',
        v_rate_id IS NOT NULL
    );

    SELECT buy_rate,
           sell_rate,
           created_by
      INTO v_buy_rate,
           v_sell_rate,
           v_created_by
      FROM exchange_rates
     WHERE rate_id = v_rate_id;

    assert_equal_number('BUY_RATE is stored correctly', v_buy_rate, 10.25);
    assert_equal_number('SELL_RATE is stored correctly', v_sell_rate, 10.50);
    assert_equal_text('CREATED_BY is stored correctly', v_created_by, 'PKG_RATE_TEST');

    SELECT COUNT(*)
      INTO v_count
      FROM audit_logs
     WHERE entity_name = 'EXCHANGE_RATES'
       AND entity_id = TO_CHAR(v_rate_id)
       AND action_type = 'INSERT'
       AND operation_name = 'ADD_EXCHANGE_RATE';

    assert_equal_number(
        'ADD_EXCHANGE_RATE creates one audit record',
        v_count,
        1
    );

    ------------------------------------------------------------------------
    -- 2. ADD_EXCHANGE_RATE validation tests
    ------------------------------------------------------------------------
    print_header('2. ADD_EXCHANGE_RATE validation tests');

    BEGIN
        pkg_exchange_rate_management.add_exchange_rate(
            p_currency_id      => NULL,
            p_base_currency_id => v_base_currency_id,
            p_buy_rate         => 1,
            p_sell_rate        => 1.1,
            p_rate_date        => v_second_test_date,
            p_created_by       => 'PKG_RATE_TEST',
            p_rate_id          => v_second_rate_id
        );
        fail_test('Rejects NULL currency ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('Rejects NULL currency ID', -20600, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.add_exchange_rate(
            p_currency_id      => v_currency_id,
            p_base_currency_id => NULL,
            p_buy_rate         => 1,
            p_sell_rate        => 1.1,
            p_rate_date        => v_second_test_date,
            p_created_by       => 'PKG_RATE_TEST',
            p_rate_id          => v_second_rate_id
        );
        fail_test('Rejects NULL base currency ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('Rejects NULL base currency ID', -20601, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.add_exchange_rate(
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_currency_id,
            p_buy_rate         => 1,
            p_sell_rate        => 1.1,
            p_rate_date        => v_second_test_date,
            p_created_by       => 'PKG_RATE_TEST',
            p_rate_id          => v_second_rate_id
        );
        fail_test('Rejects identical currencies', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('Rejects identical currencies', -20602, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.add_exchange_rate(
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_base_currency_id,
            p_buy_rate         => 0,
            p_sell_rate        => 1,
            p_rate_date        => v_second_test_date,
            p_created_by       => 'PKG_RATE_TEST',
            p_rate_id          => v_second_rate_id
        );
        fail_test('Rejects zero buy rate', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('Rejects zero buy rate', -20603, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.add_exchange_rate(
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_base_currency_id,
            p_buy_rate         => 1,
            p_sell_rate        => 0,
            p_rate_date        => v_second_test_date,
            p_created_by       => 'PKG_RATE_TEST',
            p_rate_id          => v_second_rate_id
        );
        fail_test('Rejects zero sell rate', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('Rejects zero sell rate', -20604, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.add_exchange_rate(
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_base_currency_id,
            p_buy_rate         => 2,
            p_sell_rate        => 1,
            p_rate_date        => v_second_test_date,
            p_created_by       => 'PKG_RATE_TEST',
            p_rate_id          => v_second_rate_id
        );
        fail_test('Rejects sell rate below buy rate', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Rejects sell rate below buy rate',
                -20605,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_exchange_rate_management.add_exchange_rate(
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_base_currency_id,
            p_buy_rate         => 1,
            p_sell_rate        => 1.1,
            p_rate_date        => NULL,
            p_created_by       => 'PKG_RATE_TEST',
            p_rate_id          => v_second_rate_id
        );
        fail_test('Rejects NULL rate date', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('Rejects NULL rate date', -20606, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.add_exchange_rate(
            p_currency_id      => -999999,
            p_base_currency_id => v_base_currency_id,
            p_buy_rate         => 1,
            p_sell_rate        => 1.1,
            p_rate_date        => v_second_test_date,
            p_created_by       => 'PKG_RATE_TEST',
            p_rate_id          => v_second_rate_id
        );
        fail_test('Rejects unknown currency', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('Rejects unknown currency', -20607, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.add_exchange_rate(
            p_currency_id      => v_currency_id,
            p_base_currency_id => -999999,
            p_buy_rate         => 1,
            p_sell_rate        => 1.1,
            p_rate_date        => v_second_test_date,
            p_created_by       => 'PKG_RATE_TEST',
            p_rate_id          => v_second_rate_id
        );
        fail_test('Rejects unknown base currency', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Rejects unknown base currency',
                -20608,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_exchange_rate_management.add_exchange_rate(
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_base_currency_id,
            p_buy_rate         => 10.30,
            p_sell_rate        => 10.60,
            p_rate_date        => v_test_date,
            p_created_by       => 'PKG_RATE_TEST',
            p_rate_id          => v_second_rate_id
        );
        fail_test('Rejects duplicate pair and date', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Rejects duplicate pair and date',
                -20609,
                SQLCODE,
                SQLERRM
            );
    END;

    ------------------------------------------------------------------------
    -- 3. CREATED_BY fallback
    ------------------------------------------------------------------------
    print_header('3. CREATED_BY fallback');

    pkg_exchange_rate_management.add_exchange_rate(
        p_currency_id      => v_third_currency_id,
        p_base_currency_id => v_base_currency_id,
        p_buy_rate         => 20,
        p_sell_rate        => 20.25,
        p_rate_date        => v_second_test_date,
        p_created_by       => NULL,
        p_rate_id          => v_second_rate_id
    );

    SELECT created_by
      INTO v_created_by
      FROM exchange_rates
     WHERE rate_id = v_second_rate_id;

    assert_equal_text(
        'NULL CREATED_BY falls back to USER',
        v_created_by,
        USER
    );

    ------------------------------------------------------------------------
    -- 4. UPDATE_EXCHANGE_RATE
    ------------------------------------------------------------------------
    print_header('4. UPDATE_EXCHANGE_RATE');

    pkg_exchange_rate_management.update_exchange_rate(
        p_rate_id    => v_rate_id,
        p_buy_rate   => 11.100000,
        p_sell_rate  => 11.400000,
        p_updated_by => 'RATE_UPDATE_TEST'
    );

    SELECT buy_rate,
           sell_rate,
           updated_at,
           updated_by
      INTO v_buy_rate,
           v_sell_rate,
           v_updated_at,
           v_updated_by
      FROM exchange_rates
     WHERE rate_id = v_rate_id;

    assert_equal_number('UPDATE changes BUY_RATE', v_buy_rate, 11.10);
    assert_equal_number('UPDATE changes SELL_RATE', v_sell_rate, 11.40);
    assert_true('UPDATE populates UPDATED_AT', v_updated_at IS NOT NULL);
    assert_equal_text('UPDATE stores UPDATED_BY', v_updated_by, 'RATE_UPDATE_TEST');

    SELECT COUNT(*)
      INTO v_count
      FROM audit_logs
     WHERE entity_name = 'EXCHANGE_RATES'
       AND entity_id = TO_CHAR(v_rate_id)
       AND action_type = 'UPDATE'
       AND operation_name = 'UPDATE_EXCHANGE_RATE';

    assert_equal_number(
        'UPDATE_EXCHANGE_RATE creates one audit record',
        v_count,
        1
    );

    BEGIN
        pkg_exchange_rate_management.update_exchange_rate(
            p_rate_id    => NULL,
            p_buy_rate   => 1,
            p_sell_rate  => 1.1,
            p_updated_by => 'TEST'
        );
        fail_test('UPDATE rejects NULL rate ID', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('UPDATE rejects NULL rate ID', -20620, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.update_exchange_rate(
            p_rate_id    => v_rate_id,
            p_buy_rate   => 0,
            p_sell_rate  => 1,
            p_updated_by => 'TEST'
        );
        fail_test('UPDATE rejects zero buy rate', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('UPDATE rejects zero buy rate', -20621, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.update_exchange_rate(
            p_rate_id    => v_rate_id,
            p_buy_rate   => 1,
            p_sell_rate  => 0,
            p_updated_by => 'TEST'
        );
        fail_test('UPDATE rejects zero sell rate', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('UPDATE rejects zero sell rate', -20622, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.update_exchange_rate(
            p_rate_id    => v_rate_id,
            p_buy_rate   => 5,
            p_sell_rate  => 4,
            p_updated_by => 'TEST'
        );
        fail_test('UPDATE rejects sell below buy', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('UPDATE rejects sell below buy', -20623, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.update_exchange_rate(
            p_rate_id    => -999999,
            p_buy_rate   => 1,
            p_sell_rate  => 1.1,
            p_updated_by => 'TEST'
        );
        fail_test('UPDATE rejects unknown rate', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('UPDATE rejects unknown rate', -20624, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.update_exchange_rate(
            p_rate_id    => v_rate_id,
            p_buy_rate   => 11.10,
            p_sell_rate  => 11.40,
            p_updated_by => 'TEST'
        );
        fail_test('UPDATE rejects unchanged rates', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('UPDATE rejects unchanged rates', -20625, SQLCODE, SQLERRM);
    END;

    ------------------------------------------------------------------------
    -- 5. GET_LATEST_RATE
    ------------------------------------------------------------------------
    print_header('5. GET_LATEST_RATE');

    pkg_exchange_rate_management.get_latest_rate(
        p_currency_id      => v_currency_id,
        p_base_currency_id => v_base_currency_id,
        p_result           => v_cursor
    );

    FETCH v_cursor
     INTO v_rc_rate_id,
          v_rc_currency_id,
          v_rc_currency_code,
          v_rc_base_id,
          v_rc_base_code,
          v_rc_buy_rate,
          v_rc_sell_rate,
          v_rc_rate_date,
          v_rc_created_at,
          v_rc_created_by,
          v_rc_updated_at,
          v_rc_updated_by;

    assert_true('GET_LATEST_RATE returns one row', v_cursor%FOUND);
    assert_equal_number('Latest RATE_ID is correct', v_rc_rate_id, v_rate_id);
    assert_equal_number('Latest currency ID is correct', v_rc_currency_id, v_currency_id);
    assert_equal_number('Latest base currency ID is correct', v_rc_base_id, v_base_currency_id);
    assert_equal_number('Latest BUY_RATE is correct', v_rc_buy_rate, 11.10);
    assert_equal_number('Latest SELL_RATE is correct', v_rc_sell_rate, 11.40);
    assert_true(
        'Latest RATE_DATE is correct',
        TRUNC(v_rc_rate_date) = TRUNC(v_test_date)
    );

    FETCH v_cursor
     INTO v_rc_rate_id,
          v_rc_currency_id,
          v_rc_currency_code,
          v_rc_base_id,
          v_rc_base_code,
          v_rc_buy_rate,
          v_rc_sell_rate,
          v_rc_rate_date,
          v_rc_created_at,
          v_rc_created_by,
          v_rc_updated_at,
          v_rc_updated_by;

    assert_true('GET_LATEST_RATE returns only one row', v_cursor%NOTFOUND);
    CLOSE v_cursor;

    BEGIN
        pkg_exchange_rate_management.get_latest_rate(
            p_currency_id      => NULL,
            p_base_currency_id => v_base_currency_id,
            p_result           => v_cursor
        );
        fail_test('Latest rate rejects NULL currency', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('Latest rate rejects NULL currency', -20630, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.get_latest_rate(
            p_currency_id      => v_currency_id,
            p_base_currency_id => NULL,
            p_result           => v_cursor
        );
        fail_test('Latest rate rejects NULL base currency', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Latest rate rejects NULL base currency',
                -20631,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        pkg_exchange_rate_management.get_latest_rate(
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_currency_id,
            p_result           => v_cursor
        );
        fail_test('Latest rate rejects identical currencies', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Latest rate rejects identical currencies',
                -20632,
                SQLCODE,
                SQLERRM
            );
    END;

    ------------------------------------------------------------------------
    -- 6. GET_RATE_BY_DATE
    ------------------------------------------------------------------------
    print_header('6. GET_RATE_BY_DATE');

    pkg_exchange_rate_management.get_rate_by_date(
        p_currency_id      => v_currency_id,
        p_base_currency_id => v_base_currency_id,
        p_rate_date        => v_test_date + (15 / 24),
        p_result           => v_cursor
    );

    FETCH v_cursor
     INTO v_rc_rate_id,
          v_rc_currency_id,
          v_rc_currency_code,
          v_rc_base_id,
          v_rc_base_code,
          v_rc_buy_rate,
          v_rc_sell_rate,
          v_rc_rate_date,
          v_rc_created_at,
          v_rc_created_by,
          v_rc_updated_at,
          v_rc_updated_by;

    assert_true('GET_RATE_BY_DATE returns one row', v_cursor%FOUND);
    assert_equal_number('Dated RATE_ID is correct', v_rc_rate_id, v_rate_id);
    assert_true(
        'Time component is ignored for rate date',
        TRUNC(v_rc_rate_date) = TRUNC(v_test_date)
    );

    CLOSE v_cursor;

    BEGIN
        pkg_exchange_rate_management.get_rate_by_date(
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_base_currency_id,
            p_rate_date        => NULL,
            p_result           => v_cursor
        );
        fail_test('Dated rate rejects NULL date', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('Dated rate rejects NULL date', -20643, SQLCODE, SQLERRM);
    END;

    BEGIN
        pkg_exchange_rate_management.get_rate_by_date(
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_base_currency_id,
            p_rate_date        => DATE '1900-01-01',
            p_result           => v_cursor
        );
        fail_test('Dated rate rejects missing date', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('Dated rate rejects missing date', -20646, SQLCODE, SQLERRM);
    END;

    ------------------------------------------------------------------------
    -- 7. CONVERT_AMOUNT
    ------------------------------------------------------------------------
    print_header('7. CONVERT_AMOUNT');

    v_actual_amount :=
        pkg_exchange_rate_management.convert_amount(
            p_amount           => 100,
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_base_currency_id,
            p_rate_type        => 'BUY',
            p_rate_date        => v_test_date
        );

    v_expected_amount := ROUND(100 * 11.10, 2);

    assert_equal_number(
        'BUY conversion is correct',
        v_actual_amount,
        v_expected_amount,
        0.01
    );

    v_actual_amount :=
        pkg_exchange_rate_management.convert_amount(
            p_amount           => 100,
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_base_currency_id,
            p_rate_type        => 'sell',
            p_rate_date        => v_test_date
        );

    v_expected_amount := ROUND(100 * 11.40, 2);

    assert_equal_number(
        'SELL conversion is correct and case-insensitive',
        v_actual_amount,
        v_expected_amount,
        0.01
    );

    v_actual_amount :=
        pkg_exchange_rate_management.convert_amount(
            p_amount           => 10,
            p_currency_id      => v_currency_id,
            p_base_currency_id => v_base_currency_id,
            p_rate_type        => 'SELL',
            p_rate_date        => NULL
        );

    assert_equal_number(
        'Conversion without date uses latest rate',
        v_actual_amount,
        ROUND(10 * 11.40, 2),
        0.01
    );

    BEGIN
        v_actual_amount :=
            pkg_exchange_rate_management.convert_amount(
                p_amount           => 0,
                p_currency_id      => v_currency_id,
                p_base_currency_id => v_base_currency_id,
                p_rate_type        => 'SELL',
                p_rate_date        => v_test_date
            );
        fail_test('Conversion rejects zero amount', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('Conversion rejects zero amount', -20650, SQLCODE, SQLERRM);
    END;

    BEGIN
        v_actual_amount :=
            pkg_exchange_rate_management.convert_amount(
                p_amount           => 100,
                p_currency_id      => NULL,
                p_base_currency_id => v_base_currency_id,
                p_rate_type        => 'SELL',
                p_rate_date        => v_test_date
            );
        fail_test('Conversion rejects NULL currency', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error('Conversion rejects NULL currency', -20651, SQLCODE, SQLERRM);
    END;

    BEGIN
        v_actual_amount :=
            pkg_exchange_rate_management.convert_amount(
                p_amount           => 100,
                p_currency_id      => v_currency_id,
                p_base_currency_id => NULL,
                p_rate_type        => 'SELL',
                p_rate_date        => v_test_date
            );
        fail_test('Conversion rejects NULL base currency', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Conversion rejects NULL base currency',
                -20652,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        v_actual_amount :=
            pkg_exchange_rate_management.convert_amount(
                p_amount           => 100,
                p_currency_id      => v_currency_id,
                p_base_currency_id => v_currency_id,
                p_rate_type        => 'SELL',
                p_rate_date        => v_test_date
            );
        fail_test('Conversion rejects identical currencies', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Conversion rejects identical currencies',
                -20653,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        v_actual_amount :=
            pkg_exchange_rate_management.convert_amount(
                p_amount           => 100,
                p_currency_id      => v_currency_id,
                p_base_currency_id => v_base_currency_id,
                p_rate_type        => 'MID',
                p_rate_date        => v_test_date
            );
        fail_test('Conversion rejects invalid rate type', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Conversion rejects invalid rate type',
                -20654,
                SQLCODE,
                SQLERRM
            );
    END;

    BEGIN
        v_actual_amount :=
            pkg_exchange_rate_management.convert_amount(
                p_amount           => 100,
                p_currency_id      => v_currency_id,
                p_base_currency_id => v_base_currency_id,
                p_rate_type        => 'SELL',
                p_rate_date        => DATE '1900-01-01'
            );
        fail_test('Conversion rejects missing dated rate', 'No error was raised.');
    EXCEPTION
        WHEN OTHERS THEN
            assert_expected_error(
                'Conversion rejects missing dated rate',
                -20658,
                SQLCODE,
                SQLERRM
            );
    END;

    ------------------------------------------------------------------------
    -- 8. Cleanup verification
    ------------------------------------------------------------------------
    print_header('8. Cleanup verification');

    ROLLBACK TO rate_suite_start;

    SELECT COUNT(*)
      INTO v_count
      FROM exchange_rates
     WHERE created_by = 'PKG_RATE_TEST'
       AND created_at >= SYSDATE - (20 / 1440);

    assert_equal_number(
        'All exchange-rate test rows were rolled back',
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
            '[FATAL] At least three currencies are required for this test suite.'
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
     WHERE session_id = :g_rate_test_session_id
       AND operation_name IN (
           'PKG_EXCHANGE_RATE_MANAGEMENT.ADD_EXCHANGE_RATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.UPDATE_EXCHANGE_RATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.GET_LATEST_RATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.GET_RATE_BY_DATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.CONVERT_AMOUNT'
       )
       AND error_code BETWEEN -20658 AND -20600;

    IF l_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] Expected package failures were recorded in ERROR_LOGS. Count=' || l_count);
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] No expected PKG_EXCHANGE_RATE_MANAGEMENT error rows were found.');
    END IF;

    DELETE FROM error_logs
     WHERE session_id = :g_rate_test_session_id
       AND operation_name IN (
           'PKG_EXCHANGE_RATE_MANAGEMENT.ADD_EXCHANGE_RATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.UPDATE_EXCHANGE_RATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.GET_LATEST_RATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.GET_RATE_BY_DATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.CONVERT_AMOUNT'
       )
       AND error_code BETWEEN -20658 AND -20600;
    COMMIT;

    SELECT COUNT(*)
      INTO l_count
      FROM error_logs
     WHERE session_id = :g_rate_test_session_id
       AND operation_name IN (
           'PKG_EXCHANGE_RATE_MANAGEMENT.ADD_EXCHANGE_RATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.UPDATE_EXCHANGE_RATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.GET_LATEST_RATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.GET_RATE_BY_DATE',
           'PKG_EXCHANGE_RATE_MANAGEMENT.CONVERT_AMOUNT'
       )
       AND error_code BETWEEN -20658 AND -20600;

    IF l_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] Test-generated ERROR_LOGS rows were removed.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Test-generated ERROR_LOGS rows remain. Count=' || l_count);
    END IF;
END;
/

PROMPT
PROMPT ================================================================================
PROMPT PACKAGE COMPILATION ERROR CHECK
PROMPT ================================================================================
PROMPT

COLUMN name FORMAT A35
COLUMN type FORMAT A20
COLUMN line FORMAT 999999
COLUMN position FORMAT 999999
COLUMN text FORMAT A120

SELECT name, type, line, position, text
  FROM user_errors
 WHERE name IN (
       'PKG_EXCHANGE_RATE_MANAGEMENT',
       'PKG_AUDIT',
       'PKG_ERROR_LOG'
 )
 ORDER BY name, sequence;

PROMPT
PROMPT ================================================================================
PROMPT PKG_EXCHANGE_RATE_MANAGEMENT TEST SUITE FINISHED
PROMPT ===========