-- ============================================================================
-- Oracle Banking Database
-- Module       : 01_Database_Design / 03_Constraints
-- Script       : 01_Create_Primary_Keys.sql
-- Purpose      : Create primary-key constraints for all 26 schema tables
-- Execution    : Run after all table creation scripts
-- Dependencies : 02_Tables
--
-- Design Notes
--   * All 26 primary keys are single-column keys.
--   * Stable descriptive PK_* names are used for clean deployments instead of
--     reproducing Oracle-generated SYS_C... names from the development schema.
--   * Primary-key indexes are created automatically by Oracle.
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
PROMPT CREATE PRIMARY KEY CONSTRAINTS
PROMPT ================================================================================
PROMPT

ALTER TABLE accounts
    ADD CONSTRAINT pk_accounts PRIMARY KEY (account_id);

ALTER TABLE account_types
    ADD CONSTRAINT pk_account_types PRIMARY KEY (account_type_id);

ALTER TABLE audit_logs
    ADD CONSTRAINT pk_audit_logs PRIMARY KEY (audit_log_id);

ALTER TABLE beneficiaries
    ADD CONSTRAINT pk_beneficiaries PRIMARY KEY (beneficiary_id);

ALTER TABLE branches
    ADD CONSTRAINT pk_branches PRIMARY KEY (branch_id);

ALTER TABLE cards
    ADD CONSTRAINT pk_cards PRIMARY KEY (card_id);

ALTER TABLE card_types
    ADD CONSTRAINT pk_card_types PRIMARY KEY (card_type_id);

ALTER TABLE cities
    ADD CONSTRAINT pk_cities PRIMARY KEY (city_id);

ALTER TABLE companies
    ADD CONSTRAINT pk_companies PRIMARY KEY (company_id);

ALTER TABLE contact_types
    ADD CONSTRAINT pk_contact_types PRIMARY KEY (contact_type_id);

ALTER TABLE corporate_customers
    ADD CONSTRAINT pk_corporate_customers PRIMARY KEY (customer_id);

ALTER TABLE countries
    ADD CONSTRAINT pk_countries PRIMARY KEY (country_id);

ALTER TABLE currencies
    ADD CONSTRAINT pk_currencies PRIMARY KEY (currency_id);

ALTER TABLE customers
    ADD CONSTRAINT pk_customers PRIMARY KEY (customer_id);

ALTER TABLE customer_addresses
    ADD CONSTRAINT pk_customer_addresses PRIMARY KEY (address_id);

ALTER TABLE customer_contacts
    ADD CONSTRAINT pk_customer_contacts PRIMARY KEY (contact_id);

ALTER TABLE ddl_audit_logs
    ADD CONSTRAINT pk_ddl_audit_logs PRIMARY KEY (ddl_audit_id);

ALTER TABLE districts
    ADD CONSTRAINT pk_districts PRIMARY KEY (district_id);

ALTER TABLE error_logs
    ADD CONSTRAINT pk_error_logs PRIMARY KEY (error_log_id);

ALTER TABLE exchange_rates
    ADD CONSTRAINT pk_exchange_rates PRIMARY KEY (rate_id);

ALTER TABLE individual_customers
    ADD CONSTRAINT pk_individual_customers PRIMARY KEY (customer_id);

ALTER TABLE sectors
    ADD CONSTRAINT pk_sectors PRIMARY KEY (sector_id);

ALTER TABLE transactions
    ADD CONSTRAINT pk_transactions PRIMARY KEY (transaction_id);

ALTER TABLE transaction_channels
    ADD CONSTRAINT pk_transaction_channels PRIMARY KEY (channel_id);

ALTER TABLE transaction_status_history
    ADD CONSTRAINT pk_transaction_status_history PRIMARY KEY (history_id);

ALTER TABLE transaction_types
    ADD CONSTRAINT pk_transaction_types PRIMARY KEY (transaction_type_id);

PROMPT
PROMPT ================================================================================
PROMPT PRIMARY KEY CREATION CHECK
PROMPT ================================================================================
PROMPT

COLUMN constraint_name FORMAT A40
COLUMN table_name      FORMAT A30
COLUMN status          FORMAT A10

SELECT
    constraint_name,
    table_name,
    status
FROM user_constraints
WHERE constraint_type = 'P'
ORDER BY table_name;

PROMPT
PROMPT Primary-key constraint creation completed.
PROMPT