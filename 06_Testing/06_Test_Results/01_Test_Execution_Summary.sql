-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Test Results
-- Script       : 01_Test_Execution_Summary.sql
-- Purpose      : Verify final package, package body, trigger, and compilation
--                health for the tested PL/SQL layer
-- Environment  : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- Safety       : Read-only
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT
PROMPT ================================================================================
PROMPT ORACLE BANKING DATABASE - TEST EXECUTION HEALTH SUMMARY
PROMPT ================================================================================
PROMPT

DECLARE
    l_pass_count PLS_INTEGER := 0;
    l_fail_count PLS_INTEGER := 0;
    l_actual     PLS_INTEGER;

    PROCEDURE check_equal (
        p_check_name IN VARCHAR2,
        p_expected   IN PLS_INTEGER,
        p_actual     IN PLS_INTEGER
    ) IS
    BEGIN
        IF p_actual = p_expected THEN
            l_pass_count := l_pass_count + 1;
            DBMS_OUTPUT.PUT_LINE('[PASS] ' || p_check_name ||
                ' | Expected=' || p_expected || ' Actual=' || p_actual);
        ELSE
            l_fail_count := l_fail_count + 1;
            DBMS_OUTPUT.PUT_LINE('[FAIL] ' || p_check_name ||
                ' | Expected=' || p_expected || ' Actual=' || p_actual);
        END IF;
    END;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- A. PACKAGE HEALTH ---');

    SELECT COUNT(*) INTO l_actual
    FROM user_objects
    WHERE object_type = 'PACKAGE'
      AND object_name IN (
        'PKG_ERROR_LOG','PKG_AUDIT','PKG_CUSTOMER_MANAGEMENT',
        'PKG_ACCOUNT_MANAGEMENT','PKG_BENEFICIARY_MANAGEMENT',
        'PKG_CARD_MANAGEMENT','PKG_EXCHANGE_RATE_MANAGEMENT',
        'PKG_TRANSACTION_MANAGEMENT','PKG_LOG_MAINTENANCE');
    check_equal('Project package specifications exist', 9, l_actual);

    SELECT COUNT(*) INTO l_actual
    FROM user_objects
    WHERE object_type = 'PACKAGE' AND status = 'VALID'
      AND object_name IN (
        'PKG_ERROR_LOG','PKG_AUDIT','PKG_CUSTOMER_MANAGEMENT',
        'PKG_ACCOUNT_MANAGEMENT','PKG_BENEFICIARY_MANAGEMENT',
        'PKG_CARD_MANAGEMENT','PKG_EXCHANGE_RATE_MANAGEMENT',
        'PKG_TRANSACTION_MANAGEMENT','PKG_LOG_MAINTENANCE');
    check_equal('Project package specifications are VALID', 9, l_actual);

    SELECT COUNT(*) INTO l_actual
    FROM user_objects
    WHERE object_type = 'PACKAGE BODY'
      AND object_name IN (
        'PKG_ERROR_LOG','PKG_AUDIT','PKG_CUSTOMER_MANAGEMENT',
        'PKG_ACCOUNT_MANAGEMENT','PKG_BENEFICIARY_MANAGEMENT',
        'PKG_CARD_MANAGEMENT','PKG_EXCHANGE_RATE_MANAGEMENT',
        'PKG_TRANSACTION_MANAGEMENT','PKG_LOG_MAINTENANCE');
    check_equal('Project package bodies exist', 9, l_actual);

    SELECT COUNT(*) INTO l_actual
    FROM user_objects
    WHERE object_type = 'PACKAGE BODY' AND status = 'VALID'
      AND object_name IN (
        'PKG_ERROR_LOG','PKG_AUDIT','PKG_CUSTOMER_MANAGEMENT',
        'PKG_ACCOUNT_MANAGEMENT','PKG_BENEFICIARY_MANAGEMENT',
        'PKG_CARD_MANAGEMENT','PKG_EXCHANGE_RATE_MANAGEMENT',
        'PKG_TRANSACTION_MANAGEMENT','PKG_LOG_MAINTENANCE');
    check_equal('Project package bodies are VALID', 9, l_actual);

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- B. TRIGGER HEALTH ---');

    SELECT COUNT(*) INTO l_actual
    FROM user_triggers
    WHERE trigger_name IN (
        'TRG_CUSTOMERS_NO_DELETE','TRG_ACCOUNTS_NO_DELETE',
        'TRG_TRANSACTIONS_NO_DELETE','TRG_BRANCHES_AUDIT',
        'TRG_EXCHANGE_RATES_AUDIT','TRG_TRANSACTION_STATUS_HISTORY',
        'TRG_SCHEMA_DDL_AUDIT');
    check_equal('Project triggers exist', 7, l_actual);

    SELECT COUNT(*) INTO l_actual
    FROM user_objects
    WHERE object_type = 'TRIGGER' AND status = 'VALID'
      AND object_name IN (
        'TRG_CUSTOMERS_NO_DELETE','TRG_ACCOUNTS_NO_DELETE',
        'TRG_TRANSACTIONS_NO_DELETE','TRG_BRANCHES_AUDIT',
        'TRG_EXCHANGE_RATES_AUDIT','TRG_TRANSACTION_STATUS_HISTORY',
        'TRG_SCHEMA_DDL_AUDIT');
    check_equal('Project triggers are VALID', 7, l_actual);

    SELECT COUNT(*) INTO l_actual
    FROM user_triggers
    WHERE status = 'ENABLED'
      AND trigger_name IN (
        'TRG_CUSTOMERS_NO_DELETE','TRG_ACCOUNTS_NO_DELETE',
        'TRG_TRANSACTIONS_NO_DELETE','TRG_BRANCHES_AUDIT',
        'TRG_EXCHANGE_RATES_AUDIT','TRG_TRANSACTION_STATUS_HISTORY',
        'TRG_SCHEMA_DDL_AUDIT');
    check_equal('Project triggers are ENABLED', 7, l_actual);

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- C. COMPILATION ERROR HEALTH ---');

    SELECT COUNT(*) INTO l_actual
    FROM user_errors
    WHERE name IN (
        'PKG_ERROR_LOG','PKG_AUDIT','PKG_CUSTOMER_MANAGEMENT',
        'PKG_ACCOUNT_MANAGEMENT','PKG_BENEFICIARY_MANAGEMENT',
        'PKG_CARD_MANAGEMENT','PKG_EXCHANGE_RATE_MANAGEMENT',
        'PKG_TRANSACTION_MANAGEMENT','PKG_LOG_MAINTENANCE',
        'TRG_CUSTOMERS_NO_DELETE','TRG_ACCOUNTS_NO_DELETE',
        'TRG_TRANSACTIONS_NO_DELETE','TRG_BRANCHES_AUDIT',
        'TRG_EXCHANGE_RATES_AUDIT','TRG_TRANSACTION_STATUS_HISTORY',
        'TRG_SCHEMA_DDL_AUDIT');
    check_equal('Compilation errors for tested PL/SQL objects', 0, l_actual);

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- D. PACKAGE SPECIFICATION/BODY CONSISTENCY ---');

    SELECT COUNT(*) INTO l_actual
    FROM (
        SELECT object_name
        FROM user_objects
        WHERE object_type IN ('PACKAGE','PACKAGE BODY')
          AND object_name IN (
            'PKG_ERROR_LOG','PKG_AUDIT','PKG_CUSTOMER_MANAGEMENT',
            'PKG_ACCOUNT_MANAGEMENT','PKG_BENEFICIARY_MANAGEMENT',
            'PKG_CARD_MANAGEMENT','PKG_EXCHANGE_RATE_MANAGEMENT',
            'PKG_TRANSACTION_MANAGEMENT','PKG_LOG_MAINTENANCE')
        GROUP BY object_name
        HAVING COUNT(DISTINCT object_type) = 2
    );
    check_equal('Packages have matching specification and body', 9, l_actual);

    DBMS_OUTPUT.PUT_LINE(CHR(10) ||
        '================================================================================');
    DBMS_OUTPUT.PUT_LINE('TEST EXECUTION HEALTH SUMMARY');
    DBMS_OUTPUT.PUT_LINE('PASSED=' || l_pass_count ||
        ' FAILED=' || l_fail_count ||
        ' TOTAL=' || (l_pass_count + l_fail_count));
    IF l_fail_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=PASS');
    ELSE
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=FAIL');
    END IF;
    DBMS_OUTPUT.PUT_LINE(
        '================================================================================');
END;
/

PROMPT
PROMPT ================================================================================
PROMPT INVALID TESTED OBJECT DETAILS
PROMPT ================================================================================

COLUMN object_name FORMAT A40
COLUMN object_type FORMAT A20
COLUMN status FORMAT A10

SELECT object_name, object_type, status
FROM user_objects
WHERE object_name IN (
    'PKG_ERROR_LOG','PKG_AUDIT','PKG_CUSTOMER_MANAGEMENT',
    'PKG_ACCOUNT_MANAGEMENT','PKG_BENEFICIARY_MANAGEMENT',
    'PKG_CARD_MANAGEMENT','PKG_EXCHANGE_RATE_MANAGEMENT',
    'PKG_TRANSACTION_MANAGEMENT','PKG_LOG_MAINTENANCE',
    'TRG_CUSTOMERS_NO_DELETE','TRG_ACCOUNTS_NO_DELETE',
    'TRG_TRANSACTIONS_NO_DELETE','TRG_BRANCHES_AUDIT',
    'TRG_EXCHANGE_RATES_AUDIT','TRG_TRANSACTION_STATUS_HISTORY',
    'TRG_SCHEMA_DDL_AUDIT')
AND status <> 'VALID'
ORDER BY object_type, object_name;

PROMPT
PROMPT ================================================================================
PROMPT DISABLED TESTED TRIGGER DETAILS
PROMPT ================================================================================

COLUMN trigger_name FORMAT A40
COLUMN status FORMAT A10

SELECT trigger_name, status
FROM user_triggers
WHERE trigger_name IN (
    'TRG_CUSTOMERS_NO_DELETE','TRG_ACCOUNTS_NO_DELETE',
    'TRG_TRANSACTIONS_NO_DELETE','TRG_BRANCHES_AUDIT',
    'TRG_EXCHANGE_RATES_AUDIT','TRG_TRANSACTION_STATUS_HISTORY',
    'TRG_SCHEMA_DDL_AUDIT')
AND status <> 'ENABLED'
ORDER BY trigger_name;

PROMPT
PROMPT ================================================================================
PROMPT COMPILATION ERROR DETAILS
PROMPT ================================================================================

COLUMN name FORMAT A40
COLUMN type FORMAT A20
COLUMN line FORMAT 999999
COLUMN position FORMAT 999999
COLUMN text FORMAT A120

SELECT name, type, line, position, text
FROM user_errors
WHERE name IN (
    'PKG_ERROR_LOG','PKG_AUDIT','PKG_CUSTOMER_MANAGEMENT',
    'PKG_ACCOUNT_MANAGEMENT','PKG_BENEFICIARY_MANAGEMENT',
    'PKG_CARD_MANAGEMENT','PKG_EXCHANGE_RATE_MANAGEMENT',
    'PKG_TRANSACTION_MANAGEMENT','PKG_LOG_MAINTENANCE',
    'TRG_CUSTOMERS_NO_DELETE','TRG_ACCOUNTS_NO_DELETE',
    'TRG_TRANSACTIONS_NO_DELETE','TRG_BRANCHES_AUDIT',
    'TRG_EXCHANGE_RATES_AUDIT','TRG_TRANSACTION_STATUS_HISTORY',
    'TRG_SCHEMA_DDL_AUDIT')
ORDER BY name, sequence;