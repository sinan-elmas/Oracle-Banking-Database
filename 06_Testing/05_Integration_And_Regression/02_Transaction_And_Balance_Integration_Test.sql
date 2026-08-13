-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Integration and Regression
-- Script       : 02_Transaction_And_Balance_Integration_Test.sql
-- Purpose      : Validate the end-to-end deposit, transfer, withdrawal,
--                balance-reconciliation, and transaction-retrieval workflow
-- Scope        : PKG_TRANSACTION_MANAGEMENT
--                PKG_ACCOUNT_MANAGEMENT
--                ACCOUNTS
--                TRANSACTIONS
--                TRANSACTION_STATUS_HISTORY
-- Safety       : All transaction rows and account-balance changes are rolled
--                back at the end of the suite
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
PROMPT TRANSACTION AND BALANCE INTEGRATION TEST
PROMPT ================================================================================
PROMPT

DECLARE
    ---------------------------------------------------------------------------
    -- Suite state
    ---------------------------------------------------------------------------
    l_pass_count             PLS_INTEGER := 0;
    l_fail_count             PLS_INTEGER := 0;
    l_count                  PLS_INTEGER;

    ---------------------------------------------------------------------------
    -- Accounts and balances
    ---------------------------------------------------------------------------
    l_source_account_id      accounts.account_id%TYPE;
    l_target_account_id      accounts.account_id%TYPE;
    l_currency_id            accounts.currency_id%TYPE;

    l_source_initial_balance accounts.balance%TYPE;
    l_target_initial_balance accounts.balance%TYPE;
    l_source_actual_balance  accounts.balance%TYPE;
    l_target_actual_balance  accounts.balance%TYPE;
    l_source_api_balance     accounts.balance%TYPE;
    l_target_api_balance     accounts.balance%TYPE;

    ---------------------------------------------------------------------------
    -- Channels
    ---------------------------------------------------------------------------
    l_branch_channel_id      transaction_channels.channel_id%TYPE;
    l_mobile_channel_id      transaction_channels.channel_id%TYPE;
    l_atm_channel_id         transaction_channels.channel_id%TYPE;

    ---------------------------------------------------------------------------
    -- Generated transactions
    ---------------------------------------------------------------------------
    l_deposit_id             transactions.transaction_id%TYPE;
    l_deposit_reference      transactions.reference_number%TYPE;
    l_transfer_id            transactions.transaction_id%TYPE;
    l_transfer_reference     transactions.reference_number%TYPE;
    l_withdraw_id            transactions.transaction_id%TYPE;
    l_withdraw_reference     transactions.reference_number%TYPE;

    ---------------------------------------------------------------------------
    -- Cursor variables
    ---------------------------------------------------------------------------
    l_result                 SYS_REFCURSOR;

    l_info_transaction_id    transactions.transaction_id%TYPE;
    l_info_reference_number transactions.reference_number%TYPE;
    l_info_transaction_type transaction_types.type_name%TYPE;
    l_info_channel_name      transaction_channels.channel_name%TYPE;
    l_info_source_id         transactions.source_account_id%TYPE;
    l_info_source_number     accounts.account_number%TYPE;
    l_info_source_iban       accounts.iban%TYPE;
    l_info_target_id         transactions.target_account_id%TYPE;
    l_info_target_number     accounts.account_number%TYPE;
    l_info_target_iban       accounts.iban%TYPE;
    l_info_currency_id       transactions.currency_id%TYPE;
    l_info_currency_code     currencies.currency_code%TYPE;
    l_info_amount            transactions.amount%TYPE;
    l_info_status            transactions.status%TYPE;
    l_info_transaction_date  transactions.transaction_date%TYPE;
    l_info_description       transactions.description%TYPE;

    l_hist_transaction_id    transactions.transaction_id%TYPE;
    l_hist_reference_number transactions.reference_number%TYPE;
    l_hist_transaction_type transaction_types.type_name%TYPE;
    l_hist_channel_name      transaction_channels.channel_name%TYPE;
    l_hist_direction         VARCHAR2(20);
    l_hist_source_id         transactions.source_account_id%TYPE;
    l_hist_target_id         transactions.target_account_id%TYPE;
    l_hist_currency_code     currencies.currency_code%TYPE;
    l_hist_amount            transactions.amount%TYPE;
    l_hist_status            transactions.status%TYPE;
    l_hist_transaction_date  transactions.transaction_date%TYPE;
    l_hist_description       transactions.description%TYPE;

    ---------------------------------------------------------------------------
    -- Helpers
    ---------------------------------------------------------------------------
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
                    WHEN p_details IS NOT NULL
                    THEN ' -> ' || p_details
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

BEGIN
    SAVEPOINT integration_start;

    ---------------------------------------------------------------------------
    -- A. Integration prerequisites
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- A. INTEGRATION PREREQUISITES ---');

    SELECT COUNT(*)
      INTO l_count
      FROM user_objects
     WHERE object_name IN (
           'PKG_TRANSACTION_MANAGEMENT',
           'PKG_ACCOUNT_MANAGEMENT'
       )
       AND object_type IN ('PACKAGE', 'PACKAGE BODY')
       AND status = 'VALID';

    assert_number(
        'Transaction and account package specifications/bodies are VALID',
        4,
        l_count
    );

    SELECT source_account_id,
           target_account_id,
           currency_id,
           source_balance,
           target_balance
      INTO l_source_account_id,
           l_target_account_id,
           l_currency_id,
           l_source_initial_balance,
           l_target_initial_balance
      FROM (
            SELECT a1.account_id AS source_account_id,
                   a2.account_id AS target_account_id,
                   a1.currency_id,
                   a1.balance AS source_balance,
                   a2.balance AS target_balance
              FROM accounts a1
              JOIN accounts a2
                ON a2.currency_id = a1.currency_id
               AND a2.account_id <> a1.account_id
             WHERE a1.status = 'ACTIVE'
               AND a2.status = 'ACTIVE'
             ORDER BY a1.account_id, a2.account_id
           )
     WHERE ROWNUM = 1;

    SELECT channel_id
      INTO l_branch_channel_id
      FROM transaction_channels
     WHERE UPPER(TRIM(channel_name)) = 'BRANCH';

    SELECT channel_id
      INTO l_mobile_channel_id
      FROM transaction_channels
     WHERE UPPER(TRIM(channel_name)) = 'MOBILE';

    SELECT channel_id
      INTO l_atm_channel_id
      FROM transaction_channels
     WHERE UPPER(TRIM(channel_name)) = 'ATM';

    DBMS_OUTPUT.PUT_LINE('Source account        : ' || l_source_account_id);
    DBMS_OUTPUT.PUT_LINE('Target account        : ' || l_target_account_id);
    DBMS_OUTPUT.PUT_LINE('Currency ID           : ' || l_currency_id);
    DBMS_OUTPUT.PUT_LINE('Initial source balance: ' || l_source_initial_balance);
    DBMS_OUTPUT.PUT_LINE('Initial target balance: ' || l_target_initial_balance);

    ---------------------------------------------------------------------------
    -- B. Deposit
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- B. DEPOSIT WORKFLOW ---');

    pkg_transaction_management.deposit_funds(
        p_account_id       => l_source_account_id,
        p_amount           => 100,
        p_channel_id       => l_branch_channel_id,
        p_description      => 'Integration deposit',
        p_transaction_id   => l_deposit_id,
        p_reference_number => l_deposit_reference
    );

    SELECT balance
      INTO l_source_actual_balance
      FROM accounts
     WHERE account_id = l_source_account_id;

    assert_number(
        'Deposit increases source balance by 100',
        l_source_initial_balance + 100,
        l_source_actual_balance
    );

    SELECT COUNT(*)
      INTO l_count
      FROM transactions t
      JOIN transaction_types tt
        ON tt.transaction_type_id = t.transaction_type_id
     WHERE t.transaction_id = l_deposit_id
       AND t.source_account_id = l_source_account_id
       AND t.target_account_id IS NULL
       AND t.currency_id = l_currency_id
       AND t.amount = 100
       AND t.status = 'SUCCESS'
       AND t.reference_number = l_deposit_reference
       AND t.description = 'Integration deposit'
       AND UPPER(TRIM(tt.type_name)) = 'DEPOSIT';

    assert_number(
        'Deposit transaction row matches the balance operation',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- C. Transfer
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- C. TRANSFER WORKFLOW ---');

    pkg_transaction_management.transfer_funds(
        p_source_account_id => l_source_account_id,
        p_target_account_id => l_target_account_id,
        p_amount            => 40,
        p_channel_id        => l_mobile_channel_id,
        p_description       => 'Integration transfer',
        p_transaction_id    => l_transfer_id,
        p_reference_number  => l_transfer_reference
    );

    SELECT balance
      INTO l_source_actual_balance
      FROM accounts
     WHERE account_id = l_source_account_id;

    SELECT balance
      INTO l_target_actual_balance
      FROM accounts
     WHERE account_id = l_target_account_id;

    record_result(
        'Transfer debits source and credits target by 40',
        l_source_actual_balance = l_source_initial_balance + 60
        AND l_target_actual_balance = l_target_initial_balance + 40,
        'Source=' || l_source_actual_balance ||
        ', Target=' || l_target_actual_balance
    );

    SELECT COUNT(*)
      INTO l_count
      FROM transactions t
      JOIN transaction_types tt
        ON tt.transaction_type_id = t.transaction_type_id
     WHERE t.transaction_id = l_transfer_id
       AND t.source_account_id = l_source_account_id
       AND t.target_account_id = l_target_account_id
       AND t.currency_id = l_currency_id
       AND t.amount = 40
       AND t.status = 'SUCCESS'
       AND t.reference_number = l_transfer_reference
       AND t.description = 'Integration transfer'
       AND UPPER(TRIM(tt.type_name)) = 'TRANSFER';

    assert_number(
        'Transfer transaction row matches both account movements',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- D. Withdrawal
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- D. WITHDRAWAL WORKFLOW ---');

    pkg_transaction_management.withdraw_funds(
        p_account_id       => l_source_account_id,
        p_amount           => 15,
        p_channel_id       => l_atm_channel_id,
        p_description      => 'Integration withdrawal',
        p_transaction_id   => l_withdraw_id,
        p_reference_number => l_withdraw_reference
    );

    SELECT balance
      INTO l_source_actual_balance
      FROM accounts
     WHERE account_id = l_source_account_id;

    assert_number(
        'Withdrawal decreases source balance by 15',
        l_source_initial_balance + 45,
        l_source_actual_balance
    );

    SELECT COUNT(*)
      INTO l_count
      FROM transactions t
      JOIN transaction_types tt
        ON tt.transaction_type_id = t.transaction_type_id
     WHERE t.transaction_id = l_withdraw_id
       AND t.source_account_id = l_source_account_id
       AND t.target_account_id IS NULL
       AND t.currency_id = l_currency_id
       AND t.amount = 15
       AND t.status = 'SUCCESS'
       AND t.reference_number = l_withdraw_reference
       AND t.description = 'Integration withdrawal'
       AND UPPER(TRIM(tt.type_name)) = 'WITHDRAWAL';

    assert_number(
        'Withdrawal transaction row matches the balance operation',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- E. Balance reconciliation
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- E. BALANCE RECONCILIATION ---');

    SELECT balance
      INTO l_source_actual_balance
      FROM accounts
     WHERE account_id = l_source_account_id;

    SELECT balance
      INTO l_target_actual_balance
      FROM accounts
     WHERE account_id = l_target_account_id;

    l_source_api_balance :=
        pkg_account_management.get_available_balance(
            l_source_account_id
        );

    l_target_api_balance :=
        pkg_account_management.get_available_balance(
            l_target_account_id
        );

    assert_number(
        'Source balance reconciles: initial + deposit - transfer - withdrawal',
        l_source_initial_balance + 100 - 40 - 15,
        l_source_actual_balance
    );

    assert_number(
        'Target balance reconciles: initial + transfer',
        l_target_initial_balance + 40,
        l_target_actual_balance
    );

    record_result(
        'Account API balances match stored balances',
        l_source_api_balance = l_source_actual_balance
        AND l_target_api_balance = l_target_actual_balance,
        'Source API=' || l_source_api_balance ||
        ', Source table=' || l_source_actual_balance ||
        ', Target API=' || l_target_api_balance ||
        ', Target table=' || l_target_actual_balance
    );

    SELECT COUNT(*)
      INTO l_count
      FROM transactions
     WHERE transaction_id IN (
           l_deposit_id,
           l_transfer_id,
           l_withdraw_id
       )
       AND status = 'SUCCESS';

    assert_number(
        'All three workflow transactions have SUCCESS status',
        3,
        l_count
    );

    ---------------------------------------------------------------------------
    -- F. Transaction retrieval integration
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) || '--- F. TRANSACTION RETRIEVAL INTEGRATION ---'
    );

    pkg_transaction_management.get_transaction_info(
        p_transaction_id => l_transfer_id,
        p_result         => l_result
    );

    FETCH l_result INTO
        l_info_transaction_id,
        l_info_reference_number,
        l_info_transaction_type,
        l_info_channel_name,
        l_info_source_id,
        l_info_source_number,
        l_info_source_iban,
        l_info_target_id,
        l_info_target_number,
        l_info_target_iban,
        l_info_currency_id,
        l_info_currency_code,
        l_info_amount,
        l_info_status,
        l_info_transaction_date,
        l_info_description;

    record_result(
        'GET_TRANSACTION_INFO returns the integrated transfer correctly',
        l_info_transaction_id = l_transfer_id
        AND l_info_reference_number = l_transfer_reference
        AND UPPER(TRIM(l_info_transaction_type)) = 'TRANSFER'
        AND l_info_source_id = l_source_account_id
        AND l_info_target_id = l_target_account_id
        AND l_info_currency_id = l_currency_id
        AND l_info_amount = 40
        AND l_info_status = 'SUCCESS'
        AND l_info_description = 'Integration transfer',
        'Returned transfer information does not match.'
    );

    CLOSE l_result;

    pkg_transaction_management.get_account_transactions(
        p_account_id => l_source_account_id,
        p_result     => l_result
    );

    l_count := 0;

    LOOP
        FETCH l_result INTO
            l_hist_transaction_id,
            l_hist_reference_number,
            l_hist_transaction_type,
            l_hist_channel_name,
            l_hist_direction,
            l_hist_source_id,
            l_hist_target_id,
            l_hist_currency_code,
            l_hist_amount,
            l_hist_status,
            l_hist_transaction_date,
            l_hist_description;

        EXIT WHEN l_result%NOTFOUND;

        IF l_hist_transaction_id IN (
            l_deposit_id,
            l_transfer_id,
            l_withdraw_id
        ) THEN
            l_count := l_count + 1;
        END IF;
    END LOOP;

    CLOSE l_result;

    assert_number(
        'Source account history contains all three workflow transactions',
        3,
        l_count
    );

    pkg_transaction_management.get_account_transactions(
        p_account_id => l_target_account_id,
        p_result     => l_result
    );

    l_count := 0;

    LOOP
        FETCH l_result INTO
            l_hist_transaction_id,
            l_hist_reference_number,
            l_hist_transaction_type,
            l_hist_channel_name,
            l_hist_direction,
            l_hist_source_id,
            l_hist_target_id,
            l_hist_currency_code,
            l_hist_amount,
            l_hist_status,
            l_hist_transaction_date,
            l_hist_description;

        EXIT WHEN l_result%NOTFOUND;

        IF l_hist_transaction_id = l_transfer_id THEN
            l_count := l_count + 1;
        END IF;
    END LOOP;

    CLOSE l_result;

    assert_number(
        'Target account history contains the incoming transfer',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- G. Status-history interaction
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) || '--- G. STATUS-HISTORY INTERACTION ---'
    );

    SELECT COUNT(*)
      INTO l_count
      FROM transaction_status_history
     WHERE transaction_id IN (
           l_deposit_id,
           l_transfer_id,
           l_withdraw_id
       );

    assert_number(
        'Initial SUCCESS inserts do not create status-change history rows',
        0,
        l_count
    );

    ---------------------------------------------------------------------------
    -- H. Rollback and residue verification
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) || '--- H. ROLLBACK AND RESIDUE VERIFICATION ---'
    );

    ROLLBACK TO integration_start;

    SELECT COUNT(*)
      INTO l_count
      FROM transactions
     WHERE transaction_id IN (
           l_deposit_id,
           l_transfer_id,
           l_withdraw_id
       );

    assert_number(
        'All workflow transaction rows are removed by rollback',
        0,
        l_count
    );

    SELECT balance
      INTO l_source_actual_balance
      FROM accounts
     WHERE account_id = l_source_account_id;

    SELECT balance
      INTO l_target_actual_balance
      FROM accounts
     WHERE account_id = l_target_account_id;

    record_result(
        'Both account balances are restored by rollback',
        l_source_actual_balance = l_source_initial_balance
        AND l_target_actual_balance = l_target_initial_balance,
        'Source expected=' || l_source_initial_balance ||
        ', Source actual=' || l_source_actual_balance ||
        ', Target expected=' || l_target_initial_balance ||
        ', Target actual=' || l_target_actual_balance
    );

    SELECT COUNT(*)
      INTO l_count
      FROM transaction_status_history
     WHERE transaction_id IN (
           l_deposit_id,
           l_transfer_id,
           l_withdraw_id
       );

    assert_number(
        'No transaction status-history residue remains',
        0,
        l_count
    );

    ---------------------------------------------------------------------------
    -- I. Final summary
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '================================================================================'
    );
    DBMS_OUTPUT.PUT_LINE(
        'TRANSACTION AND BALANCE INTEGRATION TEST SUMMARY'
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
        IF l_result%ISOPEN THEN
            CLOSE l_result;
        END IF;

        ROLLBACK;

        l_fail_count := l_fail_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] Test preparation -> Required active same-currency accounts or transaction channels were not found.'
        );
        DBMS_OUTPUT.PUT_LINE(
            'PASSED=' || l_pass_count ||
            ' FAILED=' || l_fail_count ||
            ' TOTAL=' || (l_pass_count + l_fail_count)
        );
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=FAIL');

    WHEN OTHERS THEN
        IF l_result%ISOPEN THEN
            CLOSE l_result;
        END IF;

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
PROMPT PACKAGE AND TRIGGER COMPILATION ERROR CHECK
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
    'PKG_TRANSACTION_MANAGEMENT',
    'PKG_ACCOUNT_MANAGEMENT',
    'TRG_TRANSACTION_STATUS_HISTORY'
)
ORDER BY
    name,
    sequence;