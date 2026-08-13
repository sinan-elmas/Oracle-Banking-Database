-- ============================================================================
-- Oracle Banking Database
-- Module       : 01_Database_Design / 04_Indexes
-- Script       : 01_Create_Supporting_Indexes.sql
-- Purpose      : Create the 28 independently managed non-function-based
--                supporting indexes in the BANKING_DB schema
-- Execution    : Run after table and constraint creation
-- Dependencies : 02_Tables
--                03_Constraints
--
-- Design Notes
--   * Primary-key and unique-constraint backing indexes are intentionally
--     excluded because Oracle creates or reuses them through constraints.
--   * IDX_CORP_COMPANY_ID is also excluded because it is used by the
--     UQ_CORPORATE_COMPANY constraint.
--   * The function-based unique index is created separately by
--     02_Create_Function_Based_Indexes.sql.
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
PROMPT CREATE SUPPORTING INDEXES
PROMPT ================================================================================
PROMPT

-- ACCOUNTS
CREATE INDEX idx_accounts_branch_id
    ON accounts (branch_id);

CREATE INDEX idx_accounts_currency_id
    ON accounts (currency_id);

CREATE INDEX idx_accounts_customer_id
    ON accounts (customer_id);

CREATE INDEX idx_accounts_type_id
    ON accounts (account_type_id);

-- BENEFICIARIES
CREATE INDEX idx_benef_account_id
    ON beneficiaries (beneficiary_account_id);

CREATE INDEX idx_benef_customer_id
    ON beneficiaries (customer_id);

-- BRANCHES
CREATE INDEX idx_branches_city_id
    ON branches (city_id);

-- CARDS
CREATE INDEX idx_cards_account_id
    ON cards (account_id);

CREATE INDEX idx_cards_type_id
    ON cards (card_type_id);

-- CITIES
CREATE INDEX idx_cities_country_id
    ON cities (country_id);

-- COMPANIES
CREATE INDEX idx_companies_city_id
    ON companies (city_id);

CREATE INDEX idx_companies_sector_id
    ON companies (sector_id);

-- CUSTOMER_ADDRESSES
CREATE INDEX idx_addr_customer_id
    ON customer_addresses (customer_id);

CREATE INDEX idx_addr_district_id
    ON customer_addresses (district_id);

-- CUSTOMER_CONTACTS
CREATE INDEX idx_cc_customer_id
    ON customer_contacts (customer_id);

CREATE INDEX idx_cc_type_id
    ON customer_contacts (contact_type_id);

-- DDL_AUDIT_LOGS
CREATE INDEX idx_ddl_audit_logs_event_time
    ON ddl_audit_logs (event_timestamp);

CREATE INDEX idx_ddl_audit_logs_object
    ON ddl_audit_logs (
        object_owner,
        object_name,
        object_type
    );

-- DISTRICTS
CREATE INDEX idx_districts_city_id
    ON districts (city_id);

-- EXCHANGE_RATES
CREATE INDEX idx_rates_base_currency_id
    ON exchange_rates (base_currency_id);

CREATE INDEX idx_rates_currency_id
    ON exchange_rates (currency_id);

-- TRANSACTIONS
CREATE INDEX idx_tr_channel_id
    ON transactions (channel_id);

CREATE INDEX idx_tr_currency_id
    ON transactions (currency_id);

CREATE INDEX idx_tr_source_account_id
    ON transactions (source_account_id);

CREATE INDEX idx_tr_target_account_id
    ON transactions (target_account_id);

CREATE INDEX idx_tr_type_id
    ON transactions (transaction_type_id);

-- TRANSACTION_STATUS_HISTORY
CREATE INDEX idx_trx_status_hist_changed_at
    ON transaction_status_history (changed_at);

CREATE INDEX idx_trx_status_hist_transaction
    ON transaction_status_history (transaction_id);

PROMPT
PROMPT ================================================================================
PROMPT SUPPORTING INDEX CREATION CHECK
PROMPT ================================================================================
PROMPT

COLUMN index_name FORMAT A40
COLUMN table_name FORMAT A30
COLUMN index_type FORMAT A24
COLUMN uniqueness FORMAT A10
COLUMN status     FORMAT A10
COLUMN visibility FORMAT A10

SELECT
    index_name,
    table_name,
    index_type,
    uniqueness,
    status,
    visibility
FROM user_indexes
WHERE index_name IN (
    'IDX_ACCOUNTS_BRANCH_ID',
    'IDX_ACCOUNTS_CURRENCY_ID',
    'IDX_ACCOUNTS_CUSTOMER_ID',
    'IDX_ACCOUNTS_TYPE_ID',
    'IDX_BENEF_ACCOUNT_ID',
    'IDX_BENEF_CUSTOMER_ID',
    'IDX_BRANCHES_CITY_ID',
    'IDX_CARDS_ACCOUNT_ID',
    'IDX_CARDS_TYPE_ID',
    'IDX_CITIES_COUNTRY_ID',
    'IDX_COMPANIES_CITY_ID',
    'IDX_COMPANIES_SECTOR_ID',
    'IDX_ADDR_CUSTOMER_ID',
    'IDX_ADDR_DISTRICT_ID',
    'IDX_CC_CUSTOMER_ID',
    'IDX_CC_TYPE_ID',
    'IDX_DDL_AUDIT_LOGS_EVENT_TIME',
    'IDX_DDL_AUDIT_LOGS_OBJECT',
    'IDX_DISTRICTS_CITY_ID',
    'IDX_RATES_BASE_CURRENCY_ID',
    'IDX_RATES_CURRENCY_ID',
    'IDX_TR_CHANNEL_ID',
    'IDX_TR_CURRENCY_ID',
    'IDX_TR_SOURCE_ACCOUNT_ID',
    'IDX_TR_TARGET_ACCOUNT_ID',
    'IDX_TR_TYPE_ID',
    'IDX_TRX_STATUS_HIST_CHANGED_AT',
    'IDX_TRX_STATUS_HIST_TRANSACTION'
)
ORDER BY table_name, index_name;

PROMPT
PROMPT Supporting-index creation completed.
PROMPT