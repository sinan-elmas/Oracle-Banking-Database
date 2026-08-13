-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / PL/SQL Tests / Trigger Tests
-- Script       : 01_NO_DELETE_TRIGGERS_Test.sql
-- Purpose      : Validate the three no-delete protection triggers
-- Scope        : TRG_CUSTOMERS_NO_DELETE
--                TRG_ACCOUNTS_NO_DELETE
--                TRG_TRANSACTIONS_NO_DELETE
-- Environment  : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- Safety       : Uses existing rows only. Any unexpected successful DELETE
--                is restored with a suite-level rollback.
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
SET VERIFY OFF
SET FEEDBACK ON
SET SQLBLANKLINES ON

WHENEVER SQLERROR CONTINUE

PROMPT
PROMPT ================================================================================
PROMPT NO-DELETE TRIGGERS - REGRESSION TEST SUITE
PROMPT ================================================================================
PROMPT

DECLARE
    l_customer_id       customers.customer_id%TYPE;
    l_account_id        accounts.account_id%TYPE;
    l_transaction_id    transactions.transaction_id%TYPE;

    l_count             PLS_INTEGER;
    l_pass_count        PLS_INTEGER := 0;
    l_fail_count        PLS_INTEGER := 0;

    PROCEDURE assert_true (
        p_name      IN VARCHAR2,
        p_condition IN BOOLEAN
    ) IS
    BEGIN
        IF p_condition THEN
            l_pass_count := l_pass_count + 1;
            DBMS_OUTPUT.PUT_LINE('[PASS] ' || p_name);
        ELSE
            l_fail_count := l_fail_count + 1;
            DBMS_OUTPUT.PUT_LINE('[FAIL] ' || p_name);
        END IF;
    END assert_true;

    PROCEDURE test_delete_error (
        p_entity_name   IN VARCHAR2,
        p_expected_code IN PLS_INTEGER,
        p_sql           IN VARCHAR2
    ) IS
        l_actual_code PLS_INTEGER := 0;
    BEGIN
        BEGIN
            EXECUTE IMMEDIATE p_sql;
        EXCEPTION
            WHEN OTHERS THEN
                l_actual_code := SQLCODE;
        END;

        assert_true(
            p_entity_name || ' DELETE raises ORA' ||
            TO_CHAR(ABS(p_expected_code), 'FM00000'),
            l_actual_code = p_expected_code
        );
    END test_delete_error;

BEGIN
    SAVEPOINT suite_start;

    DBMS_OUTPUT.PUT_LINE('--- A. TRIGGER HEALTH ---');

    SELECT COUNT(*)
      INTO l_count
      FROM user_triggers
     WHERE trigger_name IN (
               'TRG_CUSTOMERS_NO_DELETE',
               'TRG_ACCOUNTS_NO_DELETE',
               'TRG_TRANSACTIONS_NO_DELETE'
           )
       AND status = 'ENABLED';

    assert_true(
        'All three no-delete triggers are ENABLED',
        l_count = 3
    );

    SELECT COUNT(*)
      INTO l_count
      FROM user_objects
     WHERE object_type = 'TRIGGER'
       AND object_name IN (
               'TRG_CUSTOMERS_NO_DELETE',
               'TRG_ACCOUNTS_NO_DELETE',
               'TRG_TRANSACTIONS_NO_DELETE'
           )
       AND status = 'VALID';

    assert_true(
        'All three no-delete triggers are VALID',
        l_count = 3
    );

    SELECT MIN(customer_id)
      INTO l_customer_id
      FROM customers;

    SELECT MIN(account_id)
      INTO l_account_id
      FROM accounts;

    SELECT MIN(transaction_id)
      INTO l_transaction_id
      FROM transactions;

    IF l_customer_id IS NULL
       OR l_account_id IS NULL
       OR l_transaction_id IS NULL
    THEN
        RAISE_APPLICATION_ERROR(
            -20990,
            'Required customer, account, or transaction test row was not found.'
        );
    END IF;

    DBMS_OUTPUT.PUT_LINE('Customer ID    : ' || l_customer_id);
    DBMS_OUTPUT.PUT_LINE('Account ID     : ' || l_account_id);
    DBMS_OUTPUT.PUT_LINE('Transaction ID : ' || l_transaction_id);

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- B. TRG_CUSTOMERS_NO_DELETE ---');

    test_delete_error(
        'Customer',
        -20700,
        'DELETE FROM customers WHERE customer_id = ' ||
        TO_CHAR(l_customer_id)
    );

    SELECT COUNT(*)
      INTO l_count
      FROM customers
     WHERE customer_id = l_customer_id;

    assert_true(
        'Customer row remains after rejected DELETE',
        l_count = 1
    );

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- C. TRG_ACCOUNTS_NO_DELETE ---');

    test_delete_error(
        'Account',
        -20701,
        'DELETE FROM accounts WHERE account_id = ' ||
        TO_CHAR(l_account_id)
    );

    SELECT COUNT(*)
      INTO l_count
      FROM accounts
     WHERE account_id = l_account_id;

    assert_true(
        'Account row remains after rejected DELETE',
        l_count = 1
    );

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- D. TRG_TRANSACTIONS_NO_DELETE ---');

    test_delete_error(
        'Transaction',
        -20702,
        'DELETE FROM transactions WHERE transaction_id = ' ||
        TO_CHAR(l_transaction_id)
    );

    SELECT COUNT(*)
      INTO l_count
      FROM transactions
     WHERE transaction_id = l_transaction_id;

    assert_true(
        'Transaction row remains after rejected DELETE',
        l_count = 1
    );

    ROLLBACK TO suite_start;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- E. FINAL VERIFICATION ---');

    SELECT COUNT(*) INTO l_count
    FROM customers
    WHERE customer_id = l_customer_id;

    assert_true(
        'Customer test row still exists after suite rollback',
        l_count = 1
    );

    SELECT COUNT(*) INTO l_count
    FROM accounts
    WHERE account_id = l_account_id;

    assert_true(
        'Account test row still exists after suite rollback',
        l_count = 1
    );

    SELECT COUNT(*) INTO l_count
    FROM transactions
    WHERE transaction_id = l_transaction_id;

    assert_true(
        'Transaction test row still exists after suite rollback',
        l_count = 1
    );

    DBMS_OUTPUT.PUT_LINE(CHR(10) ||
        '================================================================================');
    DBMS_OUTPUT.PUT_LINE('NO-DELETE TRIGGERS TEST SUMMARY');
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
    WHEN OTHERS THEN
        ROLLBACK TO suite_start;

        l_fail_count := l_fail_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] Unexpected suite-level error -> SQLCODE=' ||
            SQLCODE || ' SQLERRM=' || SQLERRM
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
PROMPT TRIGGER COMPILATION ERROR CHECK
PROMPT ================================================================================

COLUMN name     FORMAT A40
COLUMN type     FORMAT A20
COLUMN line     FORMAT 999999
COLUMN position FORMAT 999999
COLUMN text     FORMAT A120

SELECT
    name,
    type,
    line,
    position,
    text
FROM user_errors
WHERE name IN (
    'TRG_CUSTOMERS_NO_DELETE',
    'TRG_ACCOUNTS_NO_DELETE',
    'TRG_TRANSACTIONS_NO_DELETE'
)
ORDER BY
    name,
    sequence;
