-- ============================================================================
-- Oracle Banking Database
-- Module       : 01_Database_Design / 03_Constraints
-- Script       : 04_Create_Check_Constraints.sql
-- Purpose      : Create the 36 user-defined business-rule CHECK constraints
--                present in the BANKING_DB schema
-- Execution    : Run after table creation
-- Dependencies : 02_Tables
--
-- Design Notes
--   * Oracle-generated NOT NULL constraints are intentionally excluded.
--   * NOT NULL rules are defined at column level in 02_Tables.
--   * Constraint names and conditions match the current BANKING_DB metadata.
--
-- Safety
--   DDL script. Run only during a clean deployment or controlled rebuild.
-- ============================================================================

SET DEFINE OFF
SET VERIFY OFF
SET FEEDBACK ON
SET SQLBLANKLINES ON

WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT
PROMPT ================================================================================
PROMPT CREATE CHECK CONSTRAINTS
PROMPT ================================================================================
PROMPT

-- ACCOUNTS
ALTER TABLE accounts
    ADD CONSTRAINT chk_accounts_balance
    CHECK (balance >= 0);

ALTER TABLE accounts
    ADD CONSTRAINT chk_account_number_len
    CHECK (LENGTH(account_number) BETWEEN 10 AND 20);

ALTER TABLE accounts
    ADD CONSTRAINT chk_acc_dates
    CHECK (
        closing_date IS NULL
        OR closing_date >= opening_date
    );

ALTER TABLE accounts
    ADD CONSTRAINT chk_acc_status
    CHECK (status IN ('ACTIVE','BLOCKED','CLOSED'));

ALTER TABLE accounts
    ADD CONSTRAINT chk_iban_format
    CHECK (LENGTH(iban) BETWEEN 15 AND 34);

ALTER TABLE accounts
    ADD CONSTRAINT chk_iban_upper
    CHECK (iban = UPPER(iban));

-- AUDIT_LOGS
ALTER TABLE audit_logs
    ADD CONSTRAINT chk_audit_logs_action
    CHECK (
        action_type IN (
            'INSERT',
            'UPDATE',
            'DELETE',
            'STATUS_CHANGE',
            'BUSINESS_ACTION'
        )
    );

ALTER TABLE audit_logs
    ADD CONSTRAINT chk_audit_logs_context_json
    CHECK (context_data IS JSON);

ALTER TABLE audit_logs
    ADD CONSTRAINT chk_audit_logs_new_json
    CHECK (new_data IS JSON);

ALTER TABLE audit_logs
    ADD CONSTRAINT chk_audit_logs_old_json
    CHECK (old_data IS JSON);

-- BRANCHES
ALTER TABLE branches
    ADD CONSTRAINT chk_branch_code_len
    CHECK (LENGTH(branch_code) BETWEEN 3 AND 20);

ALTER TABLE branches
    ADD CONSTRAINT chk_branch_status
    CHECK (status IN ('ACTIVE','CLOSED'));

-- CARDS
ALTER TABLE cards
    ADD CONSTRAINT chk_card_expiry
    CHECK (expiry_date > DATE '2000-01-01');

ALTER TABLE cards
    ADD CONSTRAINT chk_card_number_len
    CHECK (LENGTH(card_number) BETWEEN 16 AND 20);

ALTER TABLE cards
    ADD CONSTRAINT chk_card_status
    CHECK (status IN ('ACTIVE','BLOCKED','CLOSED'));

-- COMPANIES
ALTER TABLE companies
    ADD CONSTRAINT chk_company_status
    CHECK (status IN ('ACTIVE','PASSIVE'));

-- CORPORATE_CUSTOMERS
ALTER TABLE corporate_customers
    ADD CONSTRAINT chk_tax_number_len
    CHECK (LENGTH(tax_number) = 10 OR LENGTH(tax_number) = 11);

-- CURRENCIES
ALTER TABLE currencies
    ADD CONSTRAINT chk_currency_code
    CHECK (LENGTH(currency_code) = 3);

-- CUSTOMERS
ALTER TABLE customers
    ADD CONSTRAINT chk_customer_status
    CHECK (status IN ('ACTIVE','BLOCKED','CLOSED'));

ALTER TABLE customers
    ADD CONSTRAINT chk_customer_type
    CHECK (customer_type IN ('I','C'));

-- CUSTOMER_ADDRESSES
ALTER TABLE customer_addresses
    ADD CONSTRAINT chk_address_type
    CHECK (
        address_type IN (
            'HOME',
            'WORK',
            'OTHER',
            'REGISTERED_OFFICE',
            'BILLING',
            'BRANCH_OFFICE',
            'WAREHOUSE'
        )
    );

ALTER TABLE customer_addresses
    ADD CONSTRAINT chk_postal_code_len
    CHECK (
        postal_code IS NULL
        OR LENGTH(postal_code) BETWEEN 5 AND 10
    );

-- CUSTOMER_CONTACTS
ALTER TABLE customer_contacts
    ADD CONSTRAINT chk_priority_rank
    CHECK (priority_rank >= 1);

ALTER TABLE customer_contacts
    ADD CONSTRAINT chk_source_channel
    CHECK (
        source_channel IS NULL
        OR source_channel IN ('BRANCH','MOBILE','WEB','CALL_CENTER')
    );

ALTER TABLE customer_contacts
    ADD CONSTRAINT ck_cc_primary
    CHECK (is_primary IN ('Y','N'));

ALTER TABLE customer_contacts
    ADD CONSTRAINT ck_cc_verified
    CHECK (is_verified IN ('Y','N'));

-- ERROR_LOGS
ALTER TABLE error_logs
    ADD CONSTRAINT chk_error_logs_context_json
    CHECK (context_data IS JSON);

ALTER TABLE error_logs
    ADD CONSTRAINT chk_error_logs_severity
    CHECK (severity IN ('INFO', 'WARN', 'ERROR', 'FATAL'));

-- EXCHANGE_RATES
ALTER TABLE exchange_rates
    ADD CONSTRAINT chk_buy_rate
    CHECK (buy_rate > 0);

ALTER TABLE exchange_rates
    ADD CONSTRAINT chk_rate_currency_diff
    CHECK (currency_id <> base_currency_id);

ALTER TABLE exchange_rates
    ADD CONSTRAINT chk_sell_gte_buy
    CHECK (sell_rate >= buy_rate);

ALTER TABLE exchange_rates
    ADD CONSTRAINT chk_sell_rate
    CHECK (sell_rate > 0);

-- TRANSACTIONS
ALTER TABLE transactions
    ADD CONSTRAINT chk_transaction_amount
    CHECK (amount > 0);

ALTER TABLE transactions
    ADD CONSTRAINT chk_tr_source_target_diff
    CHECK (
        target_account_id IS NULL
        OR source_account_id <> target_account_id
    );

ALTER TABLE transactions
    ADD CONSTRAINT chk_tr_status
    CHECK (status IN ('SUCCESS','FAILED','PENDING'));

-- TRANSACTION_STATUS_HISTORY
ALTER TABLE transaction_status_history
    ADD CONSTRAINT chk_trx_status_hist_change
    CHECK (
        old_status IS NULL
        OR old_status <> new_status
    );

PROMPT
PROMPT ================================================================================
PROMPT CHECK CONSTRAINT CREATION CHECK
PROMPT ================================================================================
PROMPT

COLUMN table_name      FORMAT A30
COLUMN constraint_name FORMAT A40
COLUMN status          FORMAT A10
COLUMN validated       FORMAT A12

SELECT
    table_name,
    constraint_name,
    status,
    validated
FROM user_constraints
WHERE constraint_type = 'C'
  AND generated = 'USER NAME'
ORDER BY table_name, constraint_name;

PROMPT
PROMPT User-defined check-constraint creation completed.
PROMPT