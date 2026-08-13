-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / PL/SQL Tests / Package Tests
-- Script       : 08_PKG_TRANSACTION_MANAGEMENT_Test.sql
-- Purpose      : Validate transfers, deposits, withdrawals, transaction
--                retrieval, validation rules, and caller-controlled rollback
-- Scope        : PKG_TRANSACTION_MANAGEMENT
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

PROMPT
PROMPT ================================================================================
PROMPT PKG_TRANSACTION_MANAGEMENT - REGRESSION TEST SUITE
PROMPT ================================================================================
PROMPT

DECLARE
    ---------------------------------------------------------------------------
    -- Test counters
    ---------------------------------------------------------------------------
    l_pass_count              PLS_INTEGER := 0;
    l_fail_count              PLS_INTEGER := 0;
    l_count                   PLS_INTEGER;

    ---------------------------------------------------------------------------
    -- Reference data
    ---------------------------------------------------------------------------
    l_source_account_id       accounts.account_id%TYPE;
    l_target_account_id       accounts.account_id%TYPE;
    l_other_currency_account  accounts.account_id%TYPE;
    l_source_currency_id      accounts.currency_id%TYPE;
    l_source_balance_before   accounts.balance%TYPE;
    l_target_balance_before   accounts.balance%TYPE;
    l_initial_source_balance  accounts.balance%TYPE;
    l_initial_target_balance  accounts.balance%TYPE;
    l_source_balance_after    accounts.balance%TYPE;
    l_target_balance_after    accounts.balance%TYPE;

    l_mobile_channel_id       transaction_channels.channel_id%TYPE;
    l_internet_channel_id     transaction_channels.channel_id%TYPE;
    l_branch_channel_id       transaction_channels.channel_id%TYPE;
    l_atm_channel_id          transaction_channels.channel_id%TYPE;

    l_unknown_account_id      accounts.account_id%TYPE;
    l_unknown_channel_id      transaction_channels.channel_id%TYPE;
    l_unknown_transaction_id  transactions.transaction_id%TYPE;

    ---------------------------------------------------------------------------
    -- Generated transaction values
    ---------------------------------------------------------------------------
    l_transfer_id             transactions.transaction_id%TYPE;
    l_transfer_reference      transactions.reference_number%TYPE;
    l_deposit_id              transactions.transaction_id%TYPE;
    l_deposit_reference       transactions.reference_number%TYPE;
    l_withdraw_id             transactions.transaction_id%TYPE;
    l_withdraw_reference      transactions.reference_number%TYPE;

    ---------------------------------------------------------------------------
    -- Retrieval variables
    ---------------------------------------------------------------------------
    l_result                  SYS_REFCURSOR;

    l_info_transaction_id     transactions.transaction_id%TYPE;
    l_info_reference_number  transactions.reference_number%TYPE;
    l_info_transaction_type  transaction_types.type_name%TYPE;
    l_info_channel_name       transaction_channels.channel_name%TYPE;
    l_info_source_id          transactions.source_account_id%TYPE;
    l_info_source_number      accounts.account_number%TYPE;
    l_info_source_iban        accounts.iban%TYPE;
    l_info_target_id          transactions.target_account_id%TYPE;
    l_info_target_number      accounts.account_number%TYPE;
    l_info_target_iban        accounts.iban%TYPE;
    l_info_currency_id        transactions.currency_id%TYPE;
    l_info_currency_code      currencies.currency_code%TYPE;
    l_info_amount             transactions.amount%TYPE;
    l_info_status             transactions.status%TYPE;
    l_info_transaction_date   transactions.transaction_date%TYPE;
    l_info_description        transactions.description%TYPE;

    l_hist_transaction_id     transactions.transaction_id%TYPE;
    l_hist_reference_number  transactions.reference_number%TYPE;
    l_hist_transaction_type  transaction_types.type_name%TYPE;
    l_hist_channel_name       transaction_channels.channel_name%TYPE;
    l_hist_direction          VARCHAR2(20);
    l_hist_source_id          transactions.source_account_id%TYPE;
    l_hist_target_id          transactions.target_account_id%TYPE;
    l_hist_currency_code      currencies.currency_code%TYPE;
    l_hist_amount             transactions.amount%TYPE;
    l_hist_status             transactions.status%TYPE;
    l_hist_transaction_date   transactions.transaction_date%TYPE;
    l_hist_description        transactions.description%TYPE;

    l_has_other_currency      BOOLEAN := FALSE;

    ---------------------------------------------------------------------------
    -- Helpers
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
                CASE WHEN p_details IS NOT NULL THEN ' -> ' || p_details END
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

BEGIN
    SAVEPOINT suite_start;

    ---------------------------------------------------------------------------
    -- Test preparation
    ---------------------------------------------------------------------------
    SELECT source_account_id,
           target_account_id,
           currency_id,
           source_balance,
           target_balance
    INTO l_source_account_id,
         l_target_account_id,
         l_source_currency_id,
         l_source_balance_before,
         l_target_balance_before
    FROM (
        SELECT
            a1.account_id AS source_account_id,
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
          AND a1.balance >= 100
        ORDER BY a1.balance DESC, a1.account_id, a2.account_id
    )
    WHERE ROWNUM = 1;

    SELECT channel_id
    INTO l_mobile_channel_id
    FROM transaction_channels
    WHERE UPPER(TRIM(channel_name)) = 'MOBILE';

    SELECT channel_id
    INTO l_internet_channel_id
    FROM transaction_channels
    WHERE UPPER(TRIM(channel_name)) = 'INTERNET';

    SELECT channel_id
    INTO l_branch_channel_id
    FROM transaction_channels
    WHERE UPPER(TRIM(channel_name)) = 'BRANCH';

    SELECT channel_id
    INTO l_atm_channel_id
    FROM transaction_channels
    WHERE UPPER(TRIM(channel_name)) = 'ATM';

    SELECT NVL(MAX(account_id), 0) + 1000000
    INTO l_unknown_account_id
    FROM accounts;

    SELECT NVL(MAX(channel_id), 0) + 1000000
    INTO l_unknown_channel_id
    FROM transaction_channels;

    SELECT NVL(MAX(transaction_id), 0) + 1000000
    INTO l_unknown_transaction_id
    FROM transactions;

    BEGIN
        SELECT account_id
        INTO l_other_currency_account
        FROM (
            SELECT account_id
            FROM accounts
            WHERE status = 'ACTIVE'
              AND currency_id <> l_source_currency_id
            ORDER BY account_id
        )
        WHERE ROWNUM = 1;

        l_has_other_currency := TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_has_other_currency := FALSE;
    END;

    l_initial_source_balance := l_source_balance_before;
    l_initial_target_balance := l_target_balance_before;

    DBMS_OUTPUT.PUT_LINE('Source account       : ' || l_source_account_id);
    DBMS_OUTPUT.PUT_LINE('Target account       : ' || l_target_account_id);
    DBMS_OUTPUT.PUT_LINE('Currency ID          : ' || l_source_currency_id);
    DBMS_OUTPUT.PUT_LINE('Source balance       : ' || l_source_balance_before);
    DBMS_OUTPUT.PUT_LINE('Target balance       : ' || l_target_balance_before);

    ---------------------------------------------------------------------------
    -- A. Package and API health
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- A. PACKAGE AND API HEALTH ---');

    SELECT COUNT(*)
    INTO l_count
    FROM user_objects
    WHERE object_name = 'PKG_TRANSACTION_MANAGEMENT'
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
    WHERE object_name = 'PKG_TRANSACTION_MANAGEMENT'
      AND procedure_name IN (
          'TRANSFER_FUNDS',
          'DEPOSIT_FUNDS',
          'WITHDRAW_FUNDS',
          'GET_TRANSACTION_INFO',
          'GET_ACCOUNT_TRANSACTIONS'
      );

    assert_number(
        'Five public procedures are exposed',
        5,
        l_count
    );

    ---------------------------------------------------------------------------
    -- B. Successful TRANSFER_FUNDS
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- B. SUCCESSFUL TRANSFER_FUNDS ---');

    pkg_transaction_management.transfer_funds(
        p_source_account_id => l_source_account_id,
        p_target_account_id => l_target_account_id,
        p_amount            => 10,
        p_channel_id        => l_mobile_channel_id,
        p_description       => '  Regression transfer  ',
        p_transaction_id    => l_transfer_id,
        p_reference_number  => l_transfer_reference
    );

    record_result(
        'TRANSFER_FUNDS returns transaction identifiers',
        l_transfer_id IS NOT NULL AND l_transfer_reference IS NOT NULL,
        'Transaction ID or reference number is NULL'
    );

    record_result(
        'Transfer reference follows project format',
        REGEXP_LIKE(
            l_transfer_reference,
            '^TRX-[0-9]{17}-[0-9A-F]{12}$'
        ),
        'Actual reference=' || NVL(l_transfer_reference, 'NULL')
    );

    SELECT balance
    INTO l_source_balance_after
    FROM accounts
    WHERE account_id = l_source_account_id;

    SELECT balance
    INTO l_target_balance_after
    FROM accounts
    WHERE account_id = l_target_account_id;

    record_result(
        'Transfer debits source and credits target',
        l_source_balance_after = l_source_balance_before - 10
        AND l_target_balance_after = l_target_balance_before + 10,
        'Source=' || l_source_balance_after ||
        ', Target=' || l_target_balance_after
    );

    SELECT COUNT(*)
    INTO l_count
    FROM transactions t
    JOIN transaction_types tt
      ON tt.transaction_type_id = t.transaction_type_id
    WHERE t.transaction_id = l_transfer_id
      AND t.source_account_id = l_source_account_id
      AND t.target_account_id = l_target_account_id
      AND t.currency_id = l_source_currency_id
      AND t.amount = 10
      AND t.status = 'SUCCESS'
      AND t.reference_number = l_transfer_reference
      AND t.description = 'Regression transfer'
      AND UPPER(TRIM(tt.type_name)) = 'TRANSFER';

    assert_number(
        'Transfer transaction row is stored correctly',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- C. TRANSFER_FUNDS validations
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- C. TRANSFER_FUNDS VALIDATIONS ---');

    BEGIN
        pkg_transaction_management.transfer_funds(
            NULL, l_target_account_id, 1, l_mobile_channel_id, NULL,
            l_transfer_id, l_transfer_reference
        );
        record_result('NULL source account is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'NULL source account raises ORA-20310',
            -20310, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.transfer_funds(
            l_source_account_id, NULL, 1, l_mobile_channel_id, NULL,
            l_transfer_id, l_transfer_reference
        );
        record_result('NULL target account is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'NULL target account raises ORA-20311',
            -20311, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.transfer_funds(
            l_source_account_id, l_source_account_id, 1,
            l_mobile_channel_id, NULL, l_transfer_id, l_transfer_reference
        );
        record_result('Same source and target are rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Same source and target raise ORA-20312',
            -20312, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.transfer_funds(
            l_source_account_id, l_target_account_id, 0,
            l_mobile_channel_id, NULL, l_transfer_id, l_transfer_reference
        );
        record_result('Zero transfer amount is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Zero transfer amount raises ORA-20313',
            -20313, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.transfer_funds(
            l_source_account_id, l_target_account_id, 1,
            NULL, NULL, l_transfer_id, l_transfer_reference
        );
        record_result('NULL transfer channel is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'NULL transfer channel raises ORA-20314',
            -20314, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.transfer_funds(
            l_source_account_id, l_target_account_id, 1,
            l_atm_channel_id, NULL, l_transfer_id, l_transfer_reference
        );
        record_result('ATM transfer is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Unsupported transfer channel raises ORA-20315',
            -20315, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.transfer_funds(
            l_unknown_account_id, l_target_account_id, 1,
            l_mobile_channel_id, NULL, l_transfer_id, l_transfer_reference
        );
        record_result('Unknown source account is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Unknown source account raises ORA-20316',
            -20316, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.transfer_funds(
            l_source_account_id, l_unknown_account_id, 1,
            l_mobile_channel_id, NULL, l_transfer_id, l_transfer_reference
        );
        record_result('Unknown target account is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Unknown target account raises ORA-20317',
            -20317, SQLCODE, SQLERRM
        );
    END;

    SAVEPOINT transfer_source_status;

    UPDATE accounts
    SET status = 'BLOCKED'
    WHERE account_id = l_source_account_id;

    BEGIN
        pkg_transaction_management.transfer_funds(
            l_source_account_id, l_target_account_id, 1,
            l_mobile_channel_id, NULL, l_transfer_id, l_transfer_reference
        );
        record_result('Inactive source is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Inactive source raises ORA-20318',
            -20318, SQLCODE, SQLERRM
        );
    END;

    ROLLBACK TO transfer_source_status;

    SAVEPOINT transfer_target_status;

    UPDATE accounts
    SET status = 'BLOCKED'
    WHERE account_id = l_target_account_id;

    BEGIN
        pkg_transaction_management.transfer_funds(
            l_source_account_id, l_target_account_id, 1,
            l_mobile_channel_id, NULL, l_transfer_id, l_transfer_reference
        );
        record_result('Inactive target is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Inactive target raises ORA-20319',
            -20319, SQLCODE, SQLERRM
        );
    END;

    ROLLBACK TO transfer_target_status;

    IF l_has_other_currency THEN
        BEGIN
            pkg_transaction_management.transfer_funds(
                l_source_account_id, l_other_currency_account, 1,
                l_mobile_channel_id, NULL, l_transfer_id, l_transfer_reference
            );
            record_result('Cross-currency transfer is rejected', FALSE, 'No exception');
        EXCEPTION WHEN OTHERS THEN
            assert_expected_error(
                'Cross-currency transfer raises ORA-20320',
                -20320, SQLCODE, SQLERRM
            );
        END;
    ELSE
        DBMS_OUTPUT.PUT_LINE(
            '[SKIP] No active account with a different currency was found.'
        );
    END IF;

    BEGIN
        pkg_transaction_management.transfer_funds(
            l_source_account_id, l_target_account_id,
            l_source_balance_after + 1,
            l_mobile_channel_id, NULL, l_transfer_id, l_transfer_reference
        );
        record_result('Insufficient transfer balance is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Insufficient transfer balance raises ORA-20321',
            -20321, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.transfer_funds(
            l_source_account_id, l_target_account_id, 1,
            l_unknown_channel_id, NULL, l_transfer_id, l_transfer_reference
        );
        record_result('Unknown transfer channel is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Unknown transfer channel raises ORA-20302',
            -20302, SQLCODE, SQLERRM
        );
    END;

    ---------------------------------------------------------------------------
    -- D. Successful DEPOSIT_FUNDS
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- D. SUCCESSFUL DEPOSIT_FUNDS ---');

    SELECT balance
    INTO l_source_balance_before
    FROM accounts
    WHERE account_id = l_source_account_id;

    pkg_transaction_management.deposit_funds(
        p_account_id       => l_source_account_id,
        p_amount           => 20,
        p_channel_id       => l_branch_channel_id,
        p_description      => '  Regression deposit  ',
        p_transaction_id   => l_deposit_id,
        p_reference_number => l_deposit_reference
    );

    SELECT balance
    INTO l_source_balance_after
    FROM accounts
    WHERE account_id = l_source_account_id;

    record_result(
        'Deposit credits the selected account',
        l_source_balance_after = l_source_balance_before + 20,
        'Expected=' || (l_source_balance_before + 20) ||
        ', Actual=' || l_source_balance_after
    );

    SELECT COUNT(*)
    INTO l_count
    FROM transactions t
    JOIN transaction_types tt
      ON tt.transaction_type_id = t.transaction_type_id
    WHERE t.transaction_id = l_deposit_id
      AND t.source_account_id = l_source_account_id
      AND t.target_account_id IS NULL
      AND t.amount = 20
      AND t.status = 'SUCCESS'
      AND t.reference_number = l_deposit_reference
      AND t.description = 'Regression deposit'
      AND UPPER(TRIM(tt.type_name)) = 'DEPOSIT';

    assert_number(
        'Deposit transaction row is stored correctly',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- E. DEPOSIT_FUNDS validations
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- E. DEPOSIT_FUNDS VALIDATIONS ---');

    BEGIN
        pkg_transaction_management.deposit_funds(
            NULL, 1, l_branch_channel_id, NULL,
            l_deposit_id, l_deposit_reference
        );
        record_result('NULL deposit account is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'NULL deposit account raises ORA-20330',
            -20330, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.deposit_funds(
            l_source_account_id, 0, l_branch_channel_id, NULL,
            l_deposit_id, l_deposit_reference
        );
        record_result('Zero deposit amount is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Zero deposit amount raises ORA-20331',
            -20331, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.deposit_funds(
            l_source_account_id, 1, NULL, NULL,
            l_deposit_id, l_deposit_reference
        );
        record_result('NULL deposit channel is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'NULL deposit channel raises ORA-20332',
            -20332, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.deposit_funds(
            l_source_account_id, 1, l_mobile_channel_id, NULL,
            l_deposit_id, l_deposit_reference
        );
        record_result('Mobile deposit is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Unsupported deposit channel raises ORA-20333',
            -20333, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.deposit_funds(
            l_unknown_account_id, 1, l_branch_channel_id, NULL,
            l_deposit_id, l_deposit_reference
        );
        record_result('Unknown deposit account is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Unknown deposit account raises ORA-20334',
            -20334, SQLCODE, SQLERRM
        );
    END;

    SAVEPOINT deposit_status;

    UPDATE accounts
    SET status = 'BLOCKED'
    WHERE account_id = l_source_account_id;

    BEGIN
        pkg_transaction_management.deposit_funds(
            l_source_account_id, 1, l_branch_channel_id, NULL,
            l_deposit_id, l_deposit_reference
        );
        record_result('Inactive deposit account is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Inactive deposit account raises ORA-20335',
            -20335, SQLCODE, SQLERRM
        );
    END;

    ROLLBACK TO deposit_status;

    BEGIN
        pkg_transaction_management.deposit_funds(
            l_source_account_id, 1, l_unknown_channel_id, NULL,
            l_deposit_id, l_deposit_reference
        );
        record_result('Unknown deposit channel is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Unknown deposit channel raises ORA-20302',
            -20302, SQLCODE, SQLERRM
        );
    END;

    ---------------------------------------------------------------------------
    -- F. Successful WITHDRAW_FUNDS
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- F. SUCCESSFUL WITHDRAW_FUNDS ---');

    SELECT balance
    INTO l_source_balance_before
    FROM accounts
    WHERE account_id = l_source_account_id;

    pkg_transaction_management.withdraw_funds(
        p_account_id       => l_source_account_id,
        p_amount           => 5,
        p_channel_id       => l_atm_channel_id,
        p_description      => '  Regression withdrawal  ',
        p_transaction_id   => l_withdraw_id,
        p_reference_number => l_withdraw_reference
    );

    SELECT balance
    INTO l_source_balance_after
    FROM accounts
    WHERE account_id = l_source_account_id;

    record_result(
        'Withdrawal debits the selected account',
        l_source_balance_after = l_source_balance_before - 5,
        'Expected=' || (l_source_balance_before - 5) ||
        ', Actual=' || l_source_balance_after
    );

    SELECT COUNT(*)
    INTO l_count
    FROM transactions t
    JOIN transaction_types tt
      ON tt.transaction_type_id = t.transaction_type_id
    WHERE t.transaction_id = l_withdraw_id
      AND t.source_account_id = l_source_account_id
      AND t.target_account_id IS NULL
      AND t.amount = 5
      AND t.status = 'SUCCESS'
      AND t.reference_number = l_withdraw_reference
      AND t.description = 'Regression withdrawal'
      AND UPPER(TRIM(tt.type_name)) = 'WITHDRAWAL';

    assert_number(
        'Withdrawal transaction row is stored correctly',
        1,
        l_count
    );

    ---------------------------------------------------------------------------
    -- G. WITHDRAW_FUNDS validations
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- G. WITHDRAW_FUNDS VALIDATIONS ---');

    BEGIN
        pkg_transaction_management.withdraw_funds(
            NULL, 1, l_atm_channel_id, NULL,
            l_withdraw_id, l_withdraw_reference
        );
        record_result('NULL withdrawal account is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'NULL withdrawal account raises ORA-20340',
            -20340, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.withdraw_funds(
            l_source_account_id, 0, l_atm_channel_id, NULL,
            l_withdraw_id, l_withdraw_reference
        );
        record_result('Zero withdrawal amount is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Zero withdrawal amount raises ORA-20341',
            -20341, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.withdraw_funds(
            l_source_account_id, 1, NULL, NULL,
            l_withdraw_id, l_withdraw_reference
        );
        record_result('NULL withdrawal channel is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'NULL withdrawal channel raises ORA-20342',
            -20342, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.withdraw_funds(
            l_source_account_id, 1, l_internet_channel_id, NULL,
            l_withdraw_id, l_withdraw_reference
        );
        record_result('Internet withdrawal is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Unsupported withdrawal channel raises ORA-20343',
            -20343, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.withdraw_funds(
            l_unknown_account_id, 1, l_atm_channel_id, NULL,
            l_withdraw_id, l_withdraw_reference
        );
        record_result('Unknown withdrawal account is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Unknown withdrawal account raises ORA-20344',
            -20344, SQLCODE, SQLERRM
        );
    END;

    SAVEPOINT withdrawal_status;

    UPDATE accounts
    SET status = 'BLOCKED'
    WHERE account_id = l_source_account_id;

    BEGIN
        pkg_transaction_management.withdraw_funds(
            l_source_account_id, 1, l_atm_channel_id, NULL,
            l_withdraw_id, l_withdraw_reference
        );
        record_result('Inactive withdrawal account is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Inactive withdrawal account raises ORA-20345',
            -20345, SQLCODE, SQLERRM
        );
    END;

    ROLLBACK TO withdrawal_status;

    SELECT balance
    INTO l_source_balance_after
    FROM accounts
    WHERE account_id = l_source_account_id;

    BEGIN
        pkg_transaction_management.withdraw_funds(
            l_source_account_id, l_source_balance_after + 1,
            l_atm_channel_id, NULL, l_withdraw_id, l_withdraw_reference
        );
        record_result('Insufficient withdrawal balance is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Insufficient withdrawal balance raises ORA-20346',
            -20346, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.withdraw_funds(
            l_source_account_id, 1, l_unknown_channel_id, NULL,
            l_withdraw_id, l_withdraw_reference
        );
        record_result('Unknown withdrawal channel is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Unknown withdrawal channel raises ORA-20302',
            -20302, SQLCODE, SQLERRM
        );
    END;

    ---------------------------------------------------------------------------
    -- H. GET_TRANSACTION_INFO
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- H. GET_TRANSACTION_INFO ---');

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
        'GET_TRANSACTION_INFO returns the transfer row',
        l_info_transaction_id = l_transfer_id
        AND l_info_reference_number = l_transfer_reference
        AND UPPER(TRIM(l_info_transaction_type)) = 'TRANSFER'
        AND l_info_source_id = l_source_account_id
        AND l_info_target_id = l_target_account_id
        AND l_info_amount = 10
        AND l_info_status = 'SUCCESS',
        'Returned transaction data does not match'
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
        'GET_TRANSACTION_INFO returns only one row',
        l_result%NOTFOUND,
        'More than one row was returned'
    );

    CLOSE l_result;

    BEGIN
        pkg_transaction_management.get_transaction_info(NULL, l_result);
        record_result('NULL transaction ID is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'NULL transaction ID raises ORA-20350',
            -20350, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.get_transaction_info(
            l_unknown_transaction_id,
            l_result
        );
        record_result('Unknown transaction is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Unknown transaction raises ORA-20351',
            -20351, SQLCODE, SQLERRM
        );
    END;

    ---------------------------------------------------------------------------
    -- I. GET_ACCOUNT_TRANSACTIONS
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- I. GET_ACCOUNT_TRANSACTIONS ---');

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
            l_transfer_id,
            l_deposit_id,
            l_withdraw_id
        ) THEN
            l_count := l_count + 1;
        END IF;
    END LOOP;

    CLOSE l_result;

    assert_number(
        'Account history contains all three test transactions',
        3,
        l_count
    );

    BEGIN
        pkg_transaction_management.get_account_transactions(NULL, l_result);
        record_result('NULL history account is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'NULL history account raises ORA-20360',
            -20360, SQLCODE, SQLERRM
        );
    END;

    BEGIN
        pkg_transaction_management.get_account_transactions(
            l_unknown_account_id,
            l_result
        );
        record_result('Unknown history account is rejected', FALSE, 'No exception');
    EXCEPTION WHEN OTHERS THEN
        assert_expected_error(
            'Unknown history account raises ORA-20361',
            -20361, SQLCODE, SQLERRM
        );
    END;

    ---------------------------------------------------------------------------
    -- J. Cleanup verification
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- J. CLEANUP VERIFICATION ---');

    ROLLBACK TO suite_start;

    SELECT COUNT(*)
    INTO l_count
    FROM transactions
    WHERE transaction_id IN (
        l_transfer_id,
        l_deposit_id,
        l_withdraw_id
    );

    assert_number(
        'All transaction test rows were rolled back',
        0,
        l_count
    );

    SELECT balance
    INTO l_source_balance_after
    FROM accounts
    WHERE account_id = l_source_account_id;

    SELECT balance
    INTO l_target_balance_after
    FROM accounts
    WHERE account_id = l_target_account_id;

    record_result(
        'Account balances were restored by rollback',
        l_source_balance_after = l_initial_source_balance
        AND l_target_balance_after = l_initial_target_balance,
        'Expected source=' || l_initial_source_balance ||
        ', Actual source=' || l_source_balance_after ||
        ', Expected target=' || l_initial_target_balance ||
        ', Actual target=' || l_target_balance_after
    );

    ---------------------------------------------------------------------------
    -- Final summary
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '================================================================================');
    DBMS_OUTPUT.PUT_LINE('PKG_TRANSACTION_MANAGEMENT TEST SUMMARY');
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

    DBMS_OUTPUT.PUT_LINE('================================================================================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;

        IF l_result%ISOPEN THEN
            CLOSE l_result;
        END IF;

        l_fail_count := l_fail_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] Test preparation -> Required accounts, channels, or reference data were not found.'
        );

        DBMS_OUTPUT.PUT_LINE(
            'PASSED=' || l_pass_count ||
            ' FAILED=' || l_fail_count ||
            ' TOTAL=' || (l_pass_count + l_fail_count)
        );

        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=FAIL');

    WHEN OTHERS THEN
        ROLLBACK;

        IF l_result%ISOPEN THEN
            CLOSE l_result;
        END IF;

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
    'PKG_TRANSACTION_MANAGEMENT',
    'PKG_ERROR_LOG'
)
ORDER BY
    name,
    sequence;