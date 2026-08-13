-- ============================================================================
-- Oracle Banking Database
-- Module       : 01_Database_Design / 03_Constraints
-- Script       : 02_Create_Unique_Constraints.sql
-- Purpose      : Create the 26 unique constraints defined by the banking schema
-- Execution    : Run after 01_Create_Primary_Keys.sql
-- Dependencies : 02_Tables
--
-- Design Notes
--   * Existing user-defined UQ_* names are preserved.
--   * Oracle-generated SYS_C... names are replaced with stable descriptive
--     UQ_* names for clean and repeatable deployments.
--   * Column order for composite unique constraints matches the current
--     BANKING_DB metadata.
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
PROMPT CREATE UNIQUE CONSTRAINTS
PROMPT ================================================================================
PROMPT

ALTER TABLE accounts
    ADD CONSTRAINT uq_accounts_iban UNIQUE (iban);

ALTER TABLE accounts
    ADD CONSTRAINT uq_accounts_account_number UNIQUE (account_number);

ALTER TABLE account_types
    ADD CONSTRAINT uq_account_types_name UNIQUE (type_name);

ALTER TABLE beneficiaries
    ADD CONSTRAINT uq_benef_customer_account
        UNIQUE (customer_id, beneficiary_account_id);

ALTER TABLE branches
    ADD CONSTRAINT uq_branches_code UNIQUE (branch_code);

ALTER TABLE cards
    ADD CONSTRAINT uq_cards_number UNIQUE (card_number);

ALTER TABLE card_types
    ADD CONSTRAINT uq_card_types_name UNIQUE (type_name);

ALTER TABLE cities
    ADD CONSTRAINT uq_city_country UNIQUE (country_id, city_name);

ALTER TABLE companies
    ADD CONSTRAINT uq_company_name UNIQUE (company_name);

ALTER TABLE contact_types
    ADD CONSTRAINT uq_contact_types_name UNIQUE (type_name);

ALTER TABLE corporate_customers
    ADD CONSTRAINT uq_corporate_registration_number
        UNIQUE (registration_number);

ALTER TABLE corporate_customers
    ADD CONSTRAINT uq_corporate_tax_number
        UNIQUE (tax_number);

ALTER TABLE corporate_customers
    ADD CONSTRAINT uq_corporate_company UNIQUE (company_id);

ALTER TABLE countries
    ADD CONSTRAINT uq_countries_code UNIQUE (country_code);

ALTER TABLE countries
    ADD CONSTRAINT uq_country_name UNIQUE (country_name);

ALTER TABLE currencies
    ADD CONSTRAINT uq_currencies_code UNIQUE (currency_code);

ALTER TABLE customers
    ADD CONSTRAINT uq_customers_customer_no UNIQUE (customer_no);

ALTER TABLE customer_addresses
    ADD CONSTRAINT uq_customer_address_type
        UNIQUE (customer_id, address_type);

ALTER TABLE customer_contacts
    ADD CONSTRAINT uq_cc
        UNIQUE (customer_id, contact_value, contact_type_id);

ALTER TABLE districts
    ADD CONSTRAINT uq_district_city UNIQUE (city_id, district_name);

ALTER TABLE exchange_rates
    ADD CONSTRAINT uq_exchange_rate
        UNIQUE (currency_id, base_currency_id, rate_date);

ALTER TABLE individual_customers
    ADD CONSTRAINT uq_individual_national_id UNIQUE (national_id);

ALTER TABLE sectors
    ADD CONSTRAINT uq_sector_name UNIQUE (sector_name);

ALTER TABLE transactions
    ADD CONSTRAINT uq_transactions_reference_number UNIQUE (reference_number);

ALTER TABLE transaction_channels
    ADD CONSTRAINT uq_transaction_channels_name UNIQUE (channel_name);

ALTER TABLE transaction_types
    ADD CONSTRAINT uq_transaction_types_name UNIQUE (type_name);

PROMPT
PROMPT ================================================================================
PROMPT UNIQUE CONSTRAINT CREATION CHECK
PROMPT ================================================================================
PROMPT

COLUMN constraint_name FORMAT A45
COLUMN table_name      FORMAT A30
COLUMN status          FORMAT A10

SELECT
    constraint_name,
    table_name,
    status
FROM user_constraints
WHERE constraint_type = 'U'
ORDER BY table_name, constraint_name;

PROMPT
PROMPT Unique-constraint creation completed.
PROMPT