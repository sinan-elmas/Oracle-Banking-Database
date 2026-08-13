-- ============================================================================
-- Package Body         : PKG_TRANSACTION_MANAGEMENT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Implements account transfers, deposits, withdrawals, and transaction
--   history retrieval.
--
-- Implementation Notes
--   * Validates account status, available balance, transaction type, and
--     channel eligibility.
--   * Locks affected accounts before balance updates.
--   * Uses deterministic lock ordering for transfers to reduce deadlock risk.
--   * Generates unique transaction reference numbers.
--   * Supports same-currency transfers only.
--   * Records unexpected errors through PKG_ERROR_LOG.
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Transaction control remains with the calling application or script.
--
-- Dependencies
--   * TRANSACTIONS, ACCOUNTS, TRANSACTION_TYPES, TRANSACTION_CHANNELS
--   * CURRENCIES
--   * PKG_ERROR_LOG
-- ============================================================================

create or replace PACKAGE BODY pkg_transaction_management AS

c_account_status_active CONSTANT accounts.status%TYPE := 'ACTIVE';
c_transaction_success   CONSTANT transactions.status%TYPE := 'SUCCESS';

c_type_transfer   CONSTANT transaction_types.type_name%TYPE := 'TRANSFER';
c_type_deposit    CONSTANT transaction_types.type_name%TYPE := 'DEPOSIT';
c_type_withdrawal CONSTANT transaction_types.type_name%TYPE := 'WITHDRAWAL';

c_channel_atm      CONSTANT transaction_channels.channel_name%TYPE := 'ATM';
c_channel_mobile   CONSTANT transaction_channels.channel_name%TYPE := 'MOBILE';
c_channel_internet CONSTANT transaction_channels.channel_name%TYPE := 'INTERNET';
c_channel_branch   CONSTANT transaction_channels.channel_name%TYPE := 'BRANCH';

FUNCTION get_transaction_type_id(
    p_type_name IN transaction_types.type_name%TYPE
) RETURN transaction_types.transaction_type_id%TYPE
IS
    v_id transaction_types.transaction_type_id%TYPE;
BEGIN
    SELECT transaction_type_id
      INTO v_id
      FROM transaction_types
     WHERE UPPER(TRIM(type_name)) = UPPER(TRIM(p_type_name));
    RETURN v_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20301,
            'Required transaction type is not configured: ' || p_type_name);
END get_transaction_type_id;

FUNCTION get_channel_name(
    p_channel_id IN transaction_channels.channel_id%TYPE
) RETURN transaction_channels.channel_name%TYPE
IS
    v_name transaction_channels.channel_name%TYPE;
BEGIN
    SELECT UPPER(TRIM(channel_name))
      INTO v_name
      FROM transaction_channels
     WHERE channel_id = p_channel_id;
    RETURN v_name;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20302, 'Transaction channel does not exist.');
END get_channel_name;

FUNCTION generate_reference_number
RETURN transactions.reference_number%TYPE
IS
BEGIN
    RETURN 'TRX-' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF3')
                  || '-' || SUBSTR(RAWTOHEX(SYS_GUID()), 1, 12);
END generate_reference_number;

PROCEDURE log_unexpected_error(
    p_operation_name IN VARCHAR2,
    p_entity_id      IN VARCHAR2,
    p_context_data   IN CLOB
)
IS
BEGIN
    pkg_error_log.log_error(
        p_operation_name => p_operation_name,
        p_entity_name    => 'TRANSACTIONS',
        p_entity_id      => p_entity_id,
        p_context_data   => p_context_data,
        p_severity       => 'ERROR'
    );
EXCEPTION
    WHEN OTHERS THEN NULL;
END log_unexpected_error;

PROCEDURE transfer_funds(
    p_source_account_id IN  transactions.source_account_id%TYPE,
    p_target_account_id IN  transactions.target_account_id%TYPE,
    p_amount            IN  transactions.amount%TYPE,
    p_channel_id        IN  transactions.channel_id%TYPE,
    p_description       IN  transactions.description%TYPE DEFAULT NULL,
    p_transaction_id    OUT transactions.transaction_id%TYPE,
    p_reference_number  OUT transactions.reference_number%TYPE
)
IS
    v_source_balance      accounts.balance%TYPE;
    v_source_status       accounts.status%TYPE;
    v_source_currency_id  accounts.currency_id%TYPE;
    v_target_status       accounts.status%TYPE;
    v_target_currency_id  accounts.currency_id%TYPE;
    v_first_account_id    accounts.account_id%TYPE;
    v_second_account_id   accounts.account_id%TYPE;
    v_dummy_account_id    accounts.account_id%TYPE;
    v_channel_name        transaction_channels.channel_name%TYPE;
    v_type_id             transaction_types.transaction_type_id%TYPE;
BEGIN
    p_transaction_id := NULL;
    p_reference_number := NULL;

    IF p_source_account_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20310, 'Source account ID cannot be null.');
    END IF;
    IF p_target_account_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20311, 'Target account ID cannot be null.');
    END IF;
    IF p_source_account_id = p_target_account_id THEN
        RAISE_APPLICATION_ERROR(-20312,
            'Source and target accounts must be different.');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20313,
            'Transfer amount must be greater than zero.');
    END IF;
    IF p_channel_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20314, 'Channel ID cannot be null.');
    END IF;

    v_channel_name := get_channel_name(p_channel_id);
    IF v_channel_name NOT IN
       (c_channel_mobile, c_channel_internet, c_channel_branch) THEN
        RAISE_APPLICATION_ERROR(-20315,
            'Transfers are supported only through MOBILE, INTERNET or BRANCH channels.');
    END IF;

    v_first_account_id  := LEAST(p_source_account_id, p_target_account_id);
    v_second_account_id := GREATEST(p_source_account_id, p_target_account_id);

    BEGIN
        SELECT account_id INTO v_dummy_account_id
          FROM accounts
         WHERE account_id = v_first_account_id
         FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            IF v_first_account_id = p_source_account_id THEN
                RAISE_APPLICATION_ERROR(-20316, 'Source account does not exist.');
            ELSE
                RAISE_APPLICATION_ERROR(-20317, 'Target account does not exist.');
            END IF;
    END;

    BEGIN
        SELECT account_id INTO v_dummy_account_id
          FROM accounts
         WHERE account_id = v_second_account_id
         FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            IF v_second_account_id = p_source_account_id THEN
                RAISE_APPLICATION_ERROR(-20316, 'Source account does not exist.');
            ELSE
                RAISE_APPLICATION_ERROR(-20317, 'Target account does not exist.');
            END IF;
    END;

    SELECT balance, status, currency_id
      INTO v_source_balance, v_source_status, v_source_currency_id
      FROM accounts
     WHERE account_id = p_source_account_id;

    SELECT status, currency_id
      INTO v_target_status, v_target_currency_id
      FROM accounts
     WHERE account_id = p_target_account_id;

    IF UPPER(TRIM(v_source_status)) <> c_account_status_active THEN
        RAISE_APPLICATION_ERROR(-20318, 'Source account must be active.');
    END IF;
    IF UPPER(TRIM(v_target_status)) <> c_account_status_active THEN
        RAISE_APPLICATION_ERROR(-20319, 'Target account must be active.');
    END IF;
    IF v_source_currency_id <> v_target_currency_id THEN
        RAISE_APPLICATION_ERROR(-20320,
            'Version 1.0 supports transfers only between accounts with the same currency.');
    END IF;
    IF v_source_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20321,
            'Source account has insufficient balance.');
    END IF;

    v_type_id := get_transaction_type_id(c_type_transfer);
    p_reference_number := generate_reference_number;

    UPDATE accounts
       SET balance = balance - p_amount,
           updated_at = SYSTIMESTAMP,
           updated_by = SYS_CONTEXT('USERENV', 'SESSION_USER')
     WHERE account_id = p_source_account_id;

    UPDATE accounts
       SET balance = balance + p_amount,
           updated_at = SYSTIMESTAMP,
           updated_by = SYS_CONTEXT('USERENV', 'SESSION_USER')
     WHERE account_id = p_target_account_id;

    INSERT INTO transactions (
        source_account_id, target_account_id, transaction_type_id,
        channel_id, currency_id, amount, transaction_date,
        description, reference_number, status
    ) VALUES (
        p_source_account_id, p_target_account_id, v_type_id,
        p_channel_id, v_source_currency_id, p_amount, SYSTIMESTAMP,
        TRIM(p_description), p_reference_number, c_transaction_success
    ) RETURNING transaction_id INTO p_transaction_id;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE BETWEEN -20999 AND -20000 THEN RAISE; END IF;
        log_unexpected_error(
            'TRANSFER_FUNDS', TO_CHAR(p_source_account_id),
            JSON_OBJECT(
                'source_account_id' VALUE p_source_account_id,
                'target_account_id' VALUE p_target_account_id,
                'amount' VALUE p_amount,
                'channel_id' VALUE p_channel_id,
                'sqlcode' VALUE SQLCODE,
                'sqlerrm' VALUE SQLERRM RETURNING VARCHAR2
            )
        );
        RAISE;
END transfer_funds;

PROCEDURE deposit_funds(
    p_account_id        IN  accounts.account_id%TYPE,
    p_amount            IN  transactions.amount%TYPE,
    p_channel_id        IN  transactions.channel_id%TYPE,
    p_description       IN  transactions.description%TYPE DEFAULT NULL,
    p_transaction_id    OUT transactions.transaction_id%TYPE,
    p_reference_number  OUT transactions.reference_number%TYPE
)
IS
    v_status       accounts.status%TYPE;
    v_currency_id  accounts.currency_id%TYPE;
    v_channel_name transaction_channels.channel_name%TYPE;
    v_type_id      transaction_types.transaction_type_id%TYPE;
BEGIN
    p_transaction_id := NULL;
    p_reference_number := NULL;

    IF p_account_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20330, 'Account ID cannot be null.');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20331,
            'Deposit amount must be greater than zero.');
    END IF;
    IF p_channel_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20332, 'Channel ID cannot be null.');
    END IF;

    v_channel_name := get_channel_name(p_channel_id);
    IF v_channel_name NOT IN (c_channel_atm, c_channel_branch) THEN
        RAISE_APPLICATION_ERROR(-20333,
            'Deposits are supported only through ATM or BRANCH channels.');
    END IF;

    BEGIN
        SELECT status, currency_id
          INTO v_status, v_currency_id
          FROM accounts
         WHERE account_id = p_account_id
         FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20334, 'Account does not exist.');
    END;

    IF UPPER(TRIM(v_status)) <> c_account_status_active THEN
        RAISE_APPLICATION_ERROR(-20335, 'Account must be active.');
    END IF;

    v_type_id := get_transaction_type_id(c_type_deposit);
    p_reference_number := generate_reference_number;

    UPDATE accounts
       SET balance = balance + p_amount,
           updated_at = SYSTIMESTAMP,
           updated_by = SYS_CONTEXT('USERENV', 'SESSION_USER')
     WHERE account_id = p_account_id;

    INSERT INTO transactions (
        source_account_id, target_account_id, transaction_type_id,
        channel_id, currency_id, amount, transaction_date,
        description, reference_number, status
    ) VALUES (
        p_account_id, NULL, v_type_id,
        p_channel_id, v_currency_id, p_amount, SYSTIMESTAMP,
        TRIM(p_description), p_reference_number, c_transaction_success
    ) RETURNING transaction_id INTO p_transaction_id;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE BETWEEN -20999 AND -20000 THEN RAISE; END IF;
        log_unexpected_error(
            'DEPOSIT_FUNDS', TO_CHAR(p_account_id),
            JSON_OBJECT(
                'account_id' VALUE p_account_id,
                'amount' VALUE p_amount,
                'channel_id' VALUE p_channel_id,
                'sqlcode' VALUE SQLCODE,
                'sqlerrm' VALUE SQLERRM RETURNING VARCHAR2
            )
        );
        RAISE;
END deposit_funds;

PROCEDURE withdraw_funds(
    p_account_id        IN  accounts.account_id%TYPE,
    p_amount            IN  transactions.amount%TYPE,
    p_channel_id        IN  transactions.channel_id%TYPE,
    p_description       IN  transactions.description%TYPE DEFAULT NULL,
    p_transaction_id    OUT transactions.transaction_id%TYPE,
    p_reference_number  OUT transactions.reference_number%TYPE
)
IS
    v_balance      accounts.balance%TYPE;
    v_status       accounts.status%TYPE;
    v_currency_id  accounts.currency_id%TYPE;
    v_channel_name transaction_channels.channel_name%TYPE;
    v_type_id      transaction_types.transaction_type_id%TYPE;
BEGIN
    p_transaction_id := NULL;
    p_reference_number := NULL;

    IF p_account_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20340, 'Account ID cannot be null.');
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20341,
            'Withdrawal amount must be greater than zero.');
    END IF;
    IF p_channel_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20342, 'Channel ID cannot be null.');
    END IF;

    v_channel_name := get_channel_name(p_channel_id);
    IF v_channel_name NOT IN (c_channel_atm, c_channel_branch) THEN
        RAISE_APPLICATION_ERROR(-20343,
            'Withdrawals are supported only through ATM or BRANCH channels.');
    END IF;

    BEGIN
        SELECT balance, status, currency_id
          INTO v_balance, v_status, v_currency_id
          FROM accounts
         WHERE account_id = p_account_id
         FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20344, 'Account does not exist.');
    END;

    IF UPPER(TRIM(v_status)) <> c_account_status_active THEN
        RAISE_APPLICATION_ERROR(-20345, 'Account must be active.');
    END IF;
    IF v_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20346, 'Account has insufficient balance.');
    END IF;

    v_type_id := get_transaction_type_id(c_type_withdrawal);
    p_reference_number := generate_reference_number;

    UPDATE accounts
       SET balance = balance - p_amount,
           updated_at = SYSTIMESTAMP,
           updated_by = SYS_CONTEXT('USERENV', 'SESSION_USER')
     WHERE account_id = p_account_id;

    INSERT INTO transactions (
        source_account_id, target_account_id, transaction_type_id,
        channel_id, currency_id, amount, transaction_date,
        description, reference_number, status
    ) VALUES (
        p_account_id, NULL, v_type_id,
        p_channel_id, v_currency_id, p_amount, SYSTIMESTAMP,
        TRIM(p_description), p_reference_number, c_transaction_success
    ) RETURNING transaction_id INTO p_transaction_id;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE BETWEEN -20999 AND -20000 THEN RAISE; END IF;
        log_unexpected_error(
            'WITHDRAW_FUNDS', TO_CHAR(p_account_id),
            JSON_OBJECT(
                'account_id' VALUE p_account_id,
                'amount' VALUE p_amount,
                'channel_id' VALUE p_channel_id,
                'sqlcode' VALUE SQLCODE,
                'sqlerrm' VALUE SQLERRM RETURNING VARCHAR2
            )
        );
        RAISE;
END withdraw_funds;

PROCEDURE get_transaction_info(
    p_transaction_id IN  transactions.transaction_id%TYPE,
    p_result         OUT SYS_REFCURSOR
)
IS
    v_count PLS_INTEGER;
BEGIN
    IF p_transaction_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20350, 'Transaction ID cannot be null.');
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM transactions
     WHERE transaction_id = p_transaction_id;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20351, 'Transaction does not exist.');
    END IF;

    OPEN p_result FOR
        SELECT t.transaction_id,
               t.reference_number,
               tt.type_name AS transaction_type,
               tc.channel_name,
               t.source_account_id,
               sa.account_number AS source_account_number,
               sa.iban AS source_iban,
               t.target_account_id,
               ta.account_number AS target_account_number,
               ta.iban AS target_iban,
               t.currency_id,
               c.currency_code,
               t.amount,
               t.status,
               t.transaction_date,
               t.description
          FROM transactions t
          JOIN transaction_types tt
            ON tt.transaction_type_id = t.transaction_type_id
          JOIN transaction_channels tc
            ON tc.channel_id = t.channel_id
          JOIN accounts sa
            ON sa.account_id = t.source_account_id
          LEFT JOIN accounts ta
            ON ta.account_id = t.target_account_id
          JOIN currencies c
            ON c.currency_id = t.currency_id
         WHERE t.transaction_id = p_transaction_id;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE BETWEEN -20999 AND -20000 THEN RAISE; END IF;
        log_unexpected_error(
            'GET_TRANSACTION_INFO', TO_CHAR(p_transaction_id),
            JSON_OBJECT(
                'transaction_id' VALUE p_transaction_id,
                'sqlcode' VALUE SQLCODE,
                'sqlerrm' VALUE SQLERRM RETURNING VARCHAR2
            )
        );
        RAISE;
END get_transaction_info;

PROCEDURE get_account_transactions(
    p_account_id IN  accounts.account_id%TYPE,
    p_result     OUT SYS_REFCURSOR
)
IS
    v_count PLS_INTEGER;
BEGIN
    IF p_account_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20360, 'Account ID cannot be null.');
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM accounts
     WHERE account_id = p_account_id;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20361, 'Account does not exist.');
    END IF;

    OPEN p_result FOR
        SELECT t.transaction_id,
               t.reference_number,
               tt.type_name AS transaction_type,
               tc.channel_name,
               CASE
                   WHEN t.source_account_id = p_account_id
                        AND t.target_account_id IS NOT NULL THEN 'OUTGOING'
                   WHEN t.target_account_id = p_account_id THEN 'INCOMING'
                   WHEN tt.type_name = c_type_deposit THEN 'CREDIT'
                   ELSE 'DEBIT'
               END AS transaction_direction,
               t.source_account_id,
               t.target_account_id,
               c.currency_code,
               t.amount,
               t.status,
               t.transaction_date,
               t.description
          FROM transactions t
          JOIN transaction_types tt
            ON tt.transaction_type_id = t.transaction_type_id
          JOIN transaction_channels tc
            ON tc.channel_id = t.channel_id
          JOIN currencies c
            ON c.currency_id = t.currency_id
         WHERE t.source_account_id = p_account_id
            OR t.target_account_id = p_account_id
         ORDER BY t.transaction_date DESC, t.transaction_id DESC;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE BETWEEN -20999 AND -20000 THEN RAISE; END IF;
        log_unexpected_error(
            'GET_ACCOUNT_TRANSACTIONS', TO_CHAR(p_account_id),
            JSON_OBJECT(
                'account_id' VALUE p_account_id,
                'sqlcode' VALUE SQLCODE,
                'sqlerrm' VALUE SQLERRM RETURNING VARCHAR2
            )
        );
        RAISE;
END get_account_transactions;

END pkg_transaction_management;
