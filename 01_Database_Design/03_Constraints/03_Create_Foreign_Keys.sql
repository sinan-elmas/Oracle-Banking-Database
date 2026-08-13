-- ============================================================================
-- Oracle Banking Database
-- Module       : 01_Database_Design / 03_Constraints
-- Script       : 03_Create_Foreign_Keys.sql
-- Purpose      : Create all 28 foreign-key constraints for the banking schema
-- Execution    : Run after primary-key and unique-constraint scripts
-- Dependencies : 02_Tables
--                01_Create_Primary_Keys.sql
--                02_Create_Unique_Constraints.sql
--
-- Design Notes
--   * Constraint names and column mappings match the current BANKING_DB schema.
--   * ON DELETE CASCADE is preserved only for the two customer subtype
--     relationships present in the current schema.
--   * All remaining foreign keys use Oracle's default NO ACTION behavior.
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
PROMPT CREATE FOREIGN KEY CONSTRAINTS
PROMPT ================================================================================
PROMPT

ALTER TABLE accounts
    ADD CONSTRAINT fk_acc_branch
    FOREIGN KEY (branch_id)
    REFERENCES branches (branch_id);

ALTER TABLE accounts
    ADD CONSTRAINT fk_acc_currency
    FOREIGN KEY (currency_id)
    REFERENCES currencies (currency_id);

ALTER TABLE accounts
    ADD CONSTRAINT fk_acc_customer
    FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id);

ALTER TABLE accounts
    ADD CONSTRAINT fk_acc_type
    FOREIGN KEY (account_type_id)
    REFERENCES account_types (account_type_id);

ALTER TABLE beneficiaries
    ADD CONSTRAINT fk_benef_account
    FOREIGN KEY (beneficiary_account_id)
    REFERENCES accounts (account_id);

ALTER TABLE beneficiaries
    ADD CONSTRAINT fk_benef_customer
    FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id);

ALTER TABLE branches
    ADD CONSTRAINT fk_branches_city
    FOREIGN KEY (city_id)
    REFERENCES cities (city_id);

ALTER TABLE cards
    ADD CONSTRAINT fk_card_account
    FOREIGN KEY (account_id)
    REFERENCES accounts (account_id);

ALTER TABLE cards
    ADD CONSTRAINT fk_card_type
    FOREIGN KEY (card_type_id)
    REFERENCES card_types (card_type_id);

ALTER TABLE cities
    ADD CONSTRAINT fk_cities_country
    FOREIGN KEY (country_id)
    REFERENCES countries (country_id);

ALTER TABLE companies
    ADD CONSTRAINT fk_company_city
    FOREIGN KEY (city_id)
    REFERENCES cities (city_id);

ALTER TABLE companies
    ADD CONSTRAINT fk_company_sector
    FOREIGN KEY (sector_id)
    REFERENCES sectors (sector_id);

ALTER TABLE corporate_customers
    ADD CONSTRAINT fk_corporate_company
    FOREIGN KEY (company_id)
    REFERENCES companies (company_id);

ALTER TABLE corporate_customers
    ADD CONSTRAINT fk_corporate_customer
    FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id)
    ON DELETE CASCADE;

ALTER TABLE customer_addresses
    ADD CONSTRAINT fk_addr_customer
    FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id);

ALTER TABLE customer_addresses
    ADD CONSTRAINT fk_addr_district
    FOREIGN KEY (district_id)
    REFERENCES districts (district_id);

ALTER TABLE customer_contacts
    ADD CONSTRAINT fk_cc_customer
    FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id);

ALTER TABLE customer_contacts
    ADD CONSTRAINT fk_cc_type
    FOREIGN KEY (contact_type_id)
    REFERENCES contact_types (contact_type_id);

ALTER TABLE districts
    ADD CONSTRAINT fk_districts_city
    FOREIGN KEY (city_id)
    REFERENCES cities (city_id);

ALTER TABLE exchange_rates
    ADD CONSTRAINT fk_rates_base_currency
    FOREIGN KEY (base_currency_id)
    REFERENCES currencies (currency_id);

ALTER TABLE exchange_rates
    ADD CONSTRAINT fk_rates_currency
    FOREIGN KEY (currency_id)
    REFERENCES currencies (currency_id);

ALTER TABLE individual_customers
    ADD CONSTRAINT fk_individual_customer
    FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id)
    ON DELETE CASCADE;

ALTER TABLE transactions
    ADD CONSTRAINT fk_tr_channel
    FOREIGN KEY (channel_id)
    REFERENCES transaction_channels (channel_id);

ALTER TABLE transactions
    ADD CONSTRAINT fk_tr_currency
    FOREIGN KEY (currency_id)
    REFERENCES currencies (currency_id);

ALTER TABLE transactions
    ADD CONSTRAINT fk_tr_source
    FOREIGN KEY (source_account_id)
    REFERENCES accounts (account_id);

ALTER TABLE transactions
    ADD CONSTRAINT fk_tr_target
    FOREIGN KEY (target_account_id)
    REFERENCES accounts (account_id);

ALTER TABLE transactions
    ADD CONSTRAINT fk_tr_type
    FOREIGN KEY (transaction_type_id)
    REFERENCES transaction_types (transaction_type_id);

ALTER TABLE transaction_status_history
    ADD CONSTRAINT fk_trx_status_hist_transaction
    FOREIGN KEY (transaction_id)
    REFERENCES transactions (transaction_id);

PROMPT
PROMPT ================================================================================
PROMPT FOREIGN KEY CREATION CHECK
PROMPT ================================================================================
PROMPT

COLUMN constraint_name  FORMAT A40
COLUMN table_name       FORMAT A30
COLUMN referenced_table FORMAT A30
COLUMN delete_rule      FORMAT A12
COLUMN status           FORMAT A10

SELECT
    c.constraint_name,
    c.table_name,
    r.table_name AS referenced_table,
    c.delete_rule,
    c.status
FROM user_constraints c
JOIN user_constraints r
  ON r.constraint_name = c.r_constraint_name
WHERE c.constraint_type = 'R'
ORDER BY c.table_name, c.constraint_name;

PROMPT
PROMPT Foreign-key constraint creation completed.
PROMPT