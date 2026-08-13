-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Integration and Regression
-- Script       : 01_Customer_Account_Card_Integration_Test.sql
-- Purpose      : Validate the end-to-end Customer -> Account -> Card workflow
--                across the project's management packages
-- Scope        : PKG_CUSTOMER_MANAGEMENT
--                PKG_ACCOUNT_MANAGEMENT
--                PKG_CARD_MANAGEMENT
--                AUDIT_LOGS
-- Safety       : All business DML and audit rows participate in the caller
--                transaction and are rolled back at the end of the suite.
--                Sequence / identity gaps are expected and are not treated
--                as test residue.
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
PROMPT CUSTOMER - ACCOUNT - CARD INTEGRATION TEST
PROMPT ================================================================================
PROMPT

DECLARE
    ---------------------------------------------------------------------------
    -- Suite state
    ---------------------------------------------------------------------------
    l_pass_count       PLS_INTEGER := 0;
    l_fail_count       PLS_INTEGER := 0;
    l_count            PLS_INTEGER;

    ---------------------------------------------------------------------------
    -- Reference data
    ---------------------------------------------------------------------------
    l_branch_id        branches.branch_id%TYPE;
    l_account_type_id  account_types.account_type_id%TYPE;
    l_currency_id      currencies.currency_id%TYPE;
    l_card_type_id     card_types.card_type_id%TYPE;

    ---------------------------------------------------------------------------
    -- Customer values
    ---------------------------------------------------------------------------
    l_customer_id      customers.customer_id%TYPE;
    l_customer_no      customers.customer_no%TYPE;
    l_national_id      individual_customers.national_id%TYPE;

    ---------------------------------------------------------------------------
    -- Account values
    ---------------------------------------------------------------------------
    l_account_id       accounts.account_id%TYPE;
    l_account_number   accounts.account_number%TYPE;
    l_iban             accounts.iban%TYPE;

    ---------------------------------------------------------------------------
    -- Card values
    ---------------------------------------------------------------------------
    l_card_id          cards.card_id%TYPE;
    l_card_number      cards.card_number%TYPE;

    ---------------------------------------------------------------------------
    -- Helpers
    ---------------------------------------------------------------------------
    PROCEDURE pass (
        p_test_name IN VARCHAR2
    ) IS
    BEGIN
        l_pass_count := l_pass_count + 1;
        DBMS_OUTPUT.PUT_LINE('[PASS] ' || p_test_name);
    END pass;

    PROCEDURE fail (
        p_test_name IN VARCHAR2,
        p_details   IN VARCHAR2
    ) IS
    BEGIN
        l_fail_count := l_fail_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] ' || p_test_name || ' -> ' || p_details
        );
    END fail;

    PROCEDURE assert_number (
        p_test_name IN VARCHAR2,
        p_expected  IN NUMBER,
        p_actual    IN NUMBER
    ) IS
    BEGIN
        IF NVL(p_expected, -999999999999999) =
           NVL(p_actual,   -999999999999999)
        THEN
            pass(p_test_name);
        ELSE
            fail(
                p_test_name,
                'Expected=' || NVL(TO_CHAR(p_expected), 'NULL') ||
                ', Actual=' || NVL(TO_CHAR(p_actual), 'NULL')
            );
        END IF;
    END assert_number;

    PROCEDURE assert_true (
        p_test_name IN VARCHAR2,
        p_condition IN BOOLEAN,
        p_details   IN VARCHAR2
    ) IS
    BEGIN
        IF p_condition THEN
            pass(p_test_name);
        ELSE
            fail(p_test_name, p_details);
        END IF;
    END assert_true;

    FUNCTION random_digits (
        p_length IN PLS_INTEGER
    ) RETURN VARCHAR2
    IS
        l_value VARCHAR2(100);
    BEGIN
        l_value := '';

        FOR i IN 1 .. p_length LOOP
            l_value :=
                l_value ||
                TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(0, 10)));
        END LOOP;

        RETURN l_value;
    END random_digits;

    FUNCTION new_national_id
        RETURN individual_customers.national_id%TYPE
    IS
        l_value individual_customers.national_id%TYPE;
        l_found PLS_INTEGER;
    BEGIN
        LOOP
            l_value := random_digits(11);

            SELECT COUNT(*)
              INTO l_found
              FROM individual_customers
             WHERE national_id = l_value;

            EXIT WHEN l_found = 0;
        END LOOP;

        RETURN l_value;
    END new_national_id;

BEGIN
    ---------------------------------------------------------------------------
    -- A. Integration prerequisites
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- A. INTEGRATION PREREQUISITES ---');

    SELECT COUNT(*)
      INTO l_count
      FROM user_objects
     WHERE object_name IN (
           'PKG_CUSTOMER_MANAGEMENT',
           'PKG_ACCOUNT_MANAGEMENT',
           'PKG_CARD_MANAGEMENT'
       )
       AND object_type IN ('PACKAGE', 'PACKAGE BODY')
       AND status = 'VALID';

    assert_number(
        'All three package specifications and bodies are VALID',
        6,
        l_count
    );

    SELECT MIN(branch_id)
      INTO l_branch_id
      FROM branches;

    SELECT MIN(account_type_id)
      INTO l_account_type_id
      FROM account_types;

    SELECT MIN(currency_id)
      INTO l_currency_id
      FROM currencies;

    SELECT MIN(card_type_id)
      INTO l_card_type_id
      FROM card_types;

    assert_true(
        'Required reference data is available',
        l_branch_id IS NOT NULL
        AND l_account_type_id IS NOT NULL
        AND l_currency_id IS NOT NULL
        AND l_card_type_id IS NOT NULL,
        'BRANCHES, ACCOUNT_TYPES, CURRENCIES, or CARD_TYPES has no usable row.'
    );

    IF l_branch_id IS NULL
       OR l_account_type_id IS NULL
       OR l_currency_id IS NULL
       OR l_card_type_id IS NULL
    THEN
        RAISE_APPLICATION_ERROR(
            -20990,
            'Required integration-test reference data was not found.'
        );
    END IF;

    DBMS_RANDOM.SEED(
        TO_NUMBER(TO_CHAR(SYSTIMESTAMP, 'FF6'))
    );

    l_national_id := new_national_id;

    DBMS_OUTPUT.PUT_LINE('Branch ID       : ' || l_branch_id);
    DBMS_OUTPUT.PUT_LINE('Account Type ID : ' || l_account_type_id);
    DBMS_OUTPUT.PUT_LINE('Currency ID     : ' || l_currency_id);
    DBMS_OUTPUT.PUT_LINE('Card Type ID    : ' || l_card_type_id);

    SAVEPOINT integration_start;

    ---------------------------------------------------------------------------
    -- B. Create customer
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) || '--- B. CREATE INDIVIDUAL CUSTOMER ---'
    );

    pkg_customer_management.create_individual_customer(
        p_first_name  => 'Integration',
        p_last_name   => 'Customer',
        p_national_id => l_national_id,
        p_birth_date  => DATE '1990-01-01',
        p_customer_id => l_customer_id,
        p_customer_no => l_customer_no
    );

    assert_true(
        'Customer package returns generated identifiers',
        l_customer_id IS NOT NULL
        AND l_customer_no IS NOT NULL,
        'CUSTOMER_ID or CUSTOMER_NO is NULL.'
    );

    SELECT COUNT(*)
      INTO l_count
      FROM customers c
      JOIN individual_customers ic
        ON ic.customer_id = c.customer_id
     WHERE c.customer_id = l_customer_id
       AND c.customer_no = l_customer_no
       AND c.customer_type = 'I'
       AND c.status = 'ACTIVE'
       AND ic.first_name = 'Integration'
       AND ic.last_name = 'Customer'
       AND ic.national_id = l_national_id
       AND ic.birth_date = DATE '1990-01-01';

    assert_number(
        'Customer is persisted correctly across customer tables',
        1,
        l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM audit_logs
     WHERE entity_name = 'CUSTOMERS'
       AND entity_id = TO_CHAR(l_customer_id)
       AND action_type = 'INSERT'
       AND operation_name = 'Create Individual Customer';

    assert_number(
        'Customer creation produces its audit row',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- C. Open account for the newly created customer
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) || '--- C. OPEN ACCOUNT FOR NEW CUSTOMER ---'
    );

    pkg_account_management.open_account(
        p_customer_id     => l_customer_id,
        p_branch_id       => l_branch_id,
        p_account_type_id => l_account_type_id,
        p_currency_id     => l_currency_id,
        p_initial_balance => 0,
        p_created_by      => 'INTEGRATION_TEST',
        p_account_id      => l_account_id,
        p_account_number  => l_account_number,
        p_iban            => l_iban
    );

    assert_true(
        'Account package returns all generated identifiers',
        l_account_id IS NOT NULL
        AND l_account_number IS NOT NULL
        AND l_iban IS NOT NULL,
        'ACCOUNT_ID, ACCOUNT_NUMBER, or IBAN is NULL.'
    );

    SELECT COUNT(*)
      INTO l_count
      FROM accounts
     WHERE account_id = l_account_id
       AND customer_id = l_customer_id
       AND branch_id = l_branch_id
       AND account_type_id = l_account_type_id
       AND currency_id = l_currency_id
       AND account_number = l_account_number
       AND iban = l_iban
       AND balance = 0
       AND status = 'ACTIVE'
       AND created_by = 'INTEGRATION_TEST';

    assert_number(
        'New account is linked to the newly created customer',
        1,
        l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM audit_logs
     WHERE entity_name = 'ACCOUNTS'
       AND entity_id = TO_CHAR(l_account_id)
       AND action_type = 'INSERT'
       AND operation_name = 'PKG_ACCOUNT_MANAGEMENT.OPEN_ACCOUNT';

    assert_number(
        'Account opening produces its audit row',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- D. Issue card for the newly opened account
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) || '--- D. ISSUE CARD FOR NEW ACCOUNT ---'
    );

    pkg_card_management.issue_card(
        p_account_id   => l_account_id,
        p_card_type_id => l_card_type_id,
        p_created_by   => 'INTEGRATION_TEST',
        p_card_id      => l_card_id,
        p_card_number  => l_card_number
    );

    assert_true(
        'Card package returns generated identifiers',
        l_card_id IS NOT NULL
        AND l_card_number IS NOT NULL,
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
       AND created_by = 'INTEGRATION_TEST';

    assert_number(
        'New card is linked to the newly opened account',
        1,
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
        'Card issuance produces its audit row',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- E. End-to-end relationship verification
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) || '--- E. END-TO-END RELATIONSHIP VERIFICATION ---'
    );

    SELECT COUNT(*)
      INTO l_count
      FROM customers c
      JOIN individual_customers ic
        ON ic.customer_id = c.customer_id
      JOIN accounts a
        ON a.customer_id = c.customer_id
      JOIN cards ca
        ON ca.account_id = a.account_id
     WHERE c.customer_id = l_customer_id
       AND c.customer_no = l_customer_no
       AND ic.national_id = l_national_id
       AND a.account_id = l_account_id
       AND a.account_number = l_account_number
       AND ca.card_id = l_card_id
       AND ca.card_number = l_card_number;

    assert_number(
        'Customer -> Account -> Card relationship resolves as one chain',
        1,
        l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM audit_logs
     WHERE (
            entity_name = 'CUSTOMERS'
            AND entity_id = TO_CHAR(l_customer_id)
            AND action_type = 'INSERT'
            AND operation_name = 'Create Individual Customer'
           )
        OR (
            entity_name = 'ACCOUNTS'
            AND entity_id = TO_CHAR(l_account_id)
            AND action_type = 'INSERT'
            AND operation_name = 'PKG_ACCOUNT_MANAGEMENT.OPEN_ACCOUNT'
           )
        OR (
            entity_name = 'CARDS'
            AND entity_id = TO_CHAR(l_card_id)
            AND action_type = 'INSERT'
            AND operation_name = 'ISSUE_CARD'
           );

    assert_number(
        'Complete workflow produces three expected audit rows',
        3,
        l_count
    );

    DBMS_OUTPUT.PUT_LINE('Generated Customer ID : ' || l_customer_id);
    DBMS_OUTPUT.PUT_LINE('Generated Account ID  : ' || l_account_id);
    DBMS_OUTPUT.PUT_LINE('Generated Card ID     : ' || l_card_id);

    ---------------------------------------------------------------------------
    -- F. Rollback and residue verification
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) || '--- F. ROLLBACK AND RESIDUE VERIFICATION ---'
    );

    ROLLBACK TO integration_start;

    SELECT COUNT(*)
      INTO l_count
      FROM customers
     WHERE customer_id = l_customer_id;

    assert_number(
        'Generated customer is removed by caller rollback',
        0,
        l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM individual_customers
     WHERE customer_id = l_customer_id;

    assert_number(
        'Generated individual-customer row is removed by caller rollback',
        0,
        l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM accounts
     WHERE account_id = l_account_id;

    assert_number(
        'Generated account is removed by caller rollback',
        0,
        l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM cards
     WHERE card_id = l_card_id;

    assert_number(
        'Generated card is removed by caller rollback',
        0,
        l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM audit_logs
     WHERE (
            entity_name = 'CUSTOMERS'
            AND entity_id = TO_CHAR(l_customer_id)
           )
        OR (
            entity_name = 'ACCOUNTS'
            AND entity_id = TO_CHAR(l_account_id)
           )
        OR (
            entity_name = 'CARDS'
            AND entity_id = TO_CHAR(l_card_id)
           );

    assert_number(
        'Workflow audit rows are removed by caller rollback',
        0,
        l_count
    );

    ---------------------------------------------------------------------------
    -- G. Final summary
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '================================================================================'
    );
    DBMS_OUTPUT.PUT_LINE(
        'CUSTOMER - ACCOUNT - CARD INTEGRATION TEST SUMMARY'
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
    WHEN OTHERS THEN
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
    'PKG_CUSTOMER_MANAGEMENT',
    'PKG_ACCOUNT_MANAGEMENT',
    'PKG_CARD_MANAGEMENT'
)
ORDER BY
    name,
    sequence;