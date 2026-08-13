-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / PL/SQL Tests / Trigger Tests
-- Script       : 02_UPDATE_AUDIT_TRIGGERS_Test.sql
-- Purpose      : Validate update-metadata behavior for BRANCHES and
--                EXCHANGE_RATES
-- Scope        : TRG_BRANCHES_AUDIT, TRG_EXCHANGE_RATES_AUDIT
-- Safety       : Existing rows are updated only inside a savepoint and all
--                changes are rolled back before the suite finishes.
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
PROMPT UPDATE-AUDIT TRIGGERS - REGRESSION TEST SUITE
PROMPT ================================================================================
PROMPT

DECLARE
    l_branch_id                 branches.branch_id%TYPE;
    l_rate_id                   exchange_rates.rate_id%TYPE;

    l_branch_original_updated_at branches.updated_at%TYPE;
    l_branch_original_updated_by branches.updated_by%TYPE;
    l_rate_original_updated_at   exchange_rates.updated_at%TYPE;
    l_rate_original_updated_by   exchange_rates.updated_by%TYPE;

    l_updated_at                TIMESTAMP;
    l_updated_by                VARCHAR2(4000);
    l_test_started_at           TIMESTAMP := SYSTIMESTAMP;

    l_count                     PLS_INTEGER;
    l_pass_count                PLS_INTEGER := 0;
    l_fail_count                PLS_INTEGER := 0;

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

BEGIN
    SAVEPOINT suite_start;

    ---------------------------------------------------------------------------
    -- A. Trigger health
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- A. TRIGGER HEALTH ---');

    SELECT COUNT(*)
      INTO l_count
      FROM user_triggers
     WHERE trigger_name IN (
           'TRG_BRANCHES_AUDIT',
           'TRG_EXCHANGE_RATES_AUDIT'
       )
       AND status = 'ENABLED';

    record_result(
        'Both update-audit triggers are ENABLED',
        l_count = 2,
        'Expected=2, Actual=' || l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM user_objects
     WHERE object_name IN (
           'TRG_BRANCHES_AUDIT',
           'TRG_EXCHANGE_RATES_AUDIT'
       )
       AND object_type = 'TRIGGER'
       AND status = 'VALID';

    record_result(
        'Both update-audit triggers are VALID',
        l_count = 2,
        'Expected=2, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- Test preparation
    ---------------------------------------------------------------------------
    SELECT branch_id,
           updated_at,
           updated_by
      INTO l_branch_id,
           l_branch_original_updated_at,
           l_branch_original_updated_by
      FROM (
            SELECT branch_id,
                   updated_at,
                   updated_by
              FROM branches
             ORDER BY branch_id
           )
     WHERE ROWNUM = 1;

    SELECT rate_id,
           updated_at,
           updated_by
      INTO l_rate_id,
           l_rate_original_updated_at,
           l_rate_original_updated_by
      FROM (
            SELECT rate_id,
                   updated_at,
                   updated_by
              FROM exchange_rates
             ORDER BY rate_id
           )
     WHERE ROWNUM = 1;

    DBMS_OUTPUT.PUT_LINE('Branch ID        : ' || l_branch_id);
    DBMS_OUTPUT.PUT_LINE('Exchange Rate ID : ' || l_rate_id);

    ---------------------------------------------------------------------------
    -- B. TRG_BRANCHES_AUDIT
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- B. TRG_BRANCHES_AUDIT ---');

    l_test_started_at := SYSTIMESTAMP;

    UPDATE branches
       SET updated_at = DATE '2000-01-01',
           updated_by = 'EXPLICIT_TEST_USER'
     WHERE branch_id = l_branch_id;

    SELECT CAST(updated_at AS TIMESTAMP),
           updated_by
      INTO l_updated_at,
           l_updated_by
      FROM branches
     WHERE branch_id = l_branch_id;

    record_result(
        'Branch trigger replaces supplied UPDATED_AT',
        l_updated_at >= l_test_started_at - INTERVAL '5' SECOND,
        'Actual UPDATED_AT=' ||
        NVL(TO_CHAR(l_updated_at, 'YYYY-MM-DD HH24:MI:SS.FF6'), 'NULL')
    );

    record_result(
        'Branch trigger always sets UPDATED_BY to current USER',
        l_updated_by = USER,
        'Expected=' || USER ||
        ', Actual=' || NVL(l_updated_by, 'NULL')
    );

    ---------------------------------------------------------------------------
    -- C. TRG_EXCHANGE_RATES_AUDIT - explicit updater preservation
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- C. TRG_EXCHANGE_RATES_AUDIT - EXPLICIT UPDATED_BY ---'
    );

    l_test_started_at := SYSTIMESTAMP;

    UPDATE exchange_rates
       SET updated_at = DATE '2000-01-01',
           updated_by = 'EXPLICIT_TEST_USER'
     WHERE rate_id = l_rate_id;

    SELECT CAST(updated_at AS TIMESTAMP),
           updated_by
      INTO l_updated_at,
           l_updated_by
      FROM exchange_rates
     WHERE rate_id = l_rate_id;

    record_result(
        'Exchange-rate trigger replaces supplied UPDATED_AT',
        l_updated_at >= l_test_started_at - INTERVAL '5' SECOND,
        'Actual UPDATED_AT=' ||
        NVL(TO_CHAR(l_updated_at, 'YYYY-MM-DD HH24:MI:SS.FF6'), 'NULL')
    );

    record_result(
        'Exchange-rate trigger preserves explicit UPDATED_BY',
        l_updated_by = 'EXPLICIT_TEST_USER',
        'Expected=EXPLICIT_TEST_USER, Actual=' ||
        NVL(l_updated_by, 'NULL')
    );

    ---------------------------------------------------------------------------
    -- D. TRG_EXCHANGE_RATES_AUDIT - NULL updater fallback
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- D. TRG_EXCHANGE_RATES_AUDIT - NULL UPDATED_BY FALLBACK ---'
    );

    l_test_started_at := SYSTIMESTAMP;

    UPDATE exchange_rates
       SET updated_at = DATE '2000-01-01',
           updated_by = NULL
     WHERE rate_id = l_rate_id;

    SELECT CAST(updated_at AS TIMESTAMP),
           updated_by
      INTO l_updated_at,
           l_updated_by
      FROM exchange_rates
     WHERE rate_id = l_rate_id;

    record_result(
        'Exchange-rate trigger refreshes UPDATED_AT on every update',
        l_updated_at >= l_test_started_at - INTERVAL '5' SECOND,
        'Actual UPDATED_AT=' ||
        NVL(TO_CHAR(l_updated_at, 'YYYY-MM-DD HH24:MI:SS.FF6'), 'NULL')
    );

    record_result(
        'NULL exchange-rate UPDATED_BY defaults to current USER',
        l_updated_by = USER,
        'Expected=' || USER ||
        ', Actual=' || NVL(l_updated_by, 'NULL')
    );

    ---------------------------------------------------------------------------
    -- E. Rollback verification
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- E. ROLLBACK VERIFICATION ---');

    ROLLBACK TO suite_start;

    SELECT COUNT(*)
      INTO l_count
      FROM branches
     WHERE branch_id = l_branch_id
       AND (
            (updated_at = l_branch_original_updated_at)
            OR (updated_at IS NULL AND l_branch_original_updated_at IS NULL)
       )
       AND (
            (updated_by = l_branch_original_updated_by)
            OR (updated_by IS NULL AND l_branch_original_updated_by IS NULL)
       );

    record_result(
        'Branch metadata is restored after rollback',
        l_count = 1,
        'Expected=1, Actual=' || l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM exchange_rates
     WHERE rate_id = l_rate_id
       AND (
            (updated_at = l_rate_original_updated_at)
            OR (updated_at IS NULL AND l_rate_original_updated_at IS NULL)
       )
       AND (
            (updated_by = l_rate_original_updated_by)
            OR (updated_by IS NULL AND l_rate_original_updated_by IS NULL)
       );

    record_result(
        'Exchange-rate metadata is restored after rollback',
        l_count = 1,
        'Expected=1, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- Final summary
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '================================================================================'
    );
    DBMS_OUTPUT.PUT_LINE('UPDATE-AUDIT TRIGGERS TEST SUMMARY');
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
            '[FAIL] Test preparation -> Required BRANCHES or EXCHANGE_RATES row was not found.'
        );
        DBMS_OUTPUT.PUT_LINE(
            'PASSED=' || l_pass_count ||
            ' FAILED=' || l_fail_count ||
            ' TOTAL=' || (l_pass_count + l_fail_count)
        );
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=FAIL');

    WHEN OTHERS THEN
        ROLLBACK;

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
PROMPT TRIGGER COMPILATION ERROR CHECK
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
    'TRG_BRANCHES_AUDIT',
    'TRG_EXCHANGE_RATES_AUDIT'
)
ORDER BY
    name,
    sequence;