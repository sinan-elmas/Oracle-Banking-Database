-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Data Integrity
-- Script       : 02_Referential_Integrity_Checks.sql
-- Purpose      : Detect orphaned child rows across all application
--                foreign-key relationships
-- Scope        : Current application schema data
-- Safety       : Read-only
-- Environment  : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- ============================================================================

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 500
SET LINESIZE 240
SET FEEDBACK ON
SET VERIFY OFF
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

PROMPT
PROMPT ================================================================================
PROMPT REFERENTIAL INTEGRITY HEALTH SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN schema_name            FORMAT A20
COLUMN checked_relation_count FORMAT 999,999
COLUMN passed_relation_count  FORMAT 999,999
COLUMN failed_relation_count  FORMAT 999,999
COLUMN total_orphan_rows      FORMAT 999,999,999
COLUMN health_status          FORMAT A12
COLUMN report_time            FORMAT A20

WITH integrity_checks AS
(
    SELECT 'ACCOUNTS -> BRANCHES' AS relationship_name, COUNT(*) AS orphan_count
    FROM accounts child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM branches parent
        WHERE parent.branch_id = child.branch_id
    )

    UNION ALL

    SELECT 'ACCOUNTS -> CURRENCIES', COUNT(*)
    FROM accounts child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM currencies parent
        WHERE parent.currency_id = child.currency_id
    )

    UNION ALL

    SELECT 'ACCOUNTS -> CUSTOMERS', COUNT(*)
    FROM accounts child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM customers parent
        WHERE parent.customer_id = child.customer_id
    )

    UNION ALL

    SELECT 'ACCOUNTS -> ACCOUNT_TYPES', COUNT(*)
    FROM accounts child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM account_types parent
        WHERE parent.account_type_id = child.account_type_id
    )

    UNION ALL

    SELECT 'BENEFICIARIES -> ACCOUNTS', COUNT(*)
    FROM beneficiaries child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM accounts parent
        WHERE parent.account_id = child.beneficiary_account_id
    )

    UNION ALL

    SELECT 'BENEFICIARIES -> CUSTOMERS', COUNT(*)
    FROM beneficiaries child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM customers parent
        WHERE parent.customer_id = child.customer_id
    )

    UNION ALL

    SELECT 'BRANCHES -> CITIES', COUNT(*)
    FROM branches child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM cities parent
        WHERE parent.city_id = child.city_id
    )

    UNION ALL

    SELECT 'CARDS -> ACCOUNTS', COUNT(*)
    FROM cards child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM accounts parent
        WHERE parent.account_id = child.account_id
    )

    UNION ALL

    SELECT 'CARDS -> CARD_TYPES', COUNT(*)
    FROM cards child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM card_types parent
        WHERE parent.card_type_id = child.card_type_id
    )

    UNION ALL

    SELECT 'CITIES -> COUNTRIES', COUNT(*)
    FROM cities child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM countries parent
        WHERE parent.country_id = child.country_id
    )

    UNION ALL

    SELECT 'COMPANIES -> CITIES', COUNT(*)
    FROM companies child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM cities parent
        WHERE parent.city_id = child.city_id
    )

    UNION ALL

    SELECT 'COMPANIES -> SECTORS', COUNT(*)
    FROM companies child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sectors parent
        WHERE parent.sector_id = child.sector_id
    )

    UNION ALL

    SELECT 'CORPORATE_CUSTOMERS -> COMPANIES', COUNT(*)
    FROM corporate_customers child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM companies parent
        WHERE parent.company_id = child.company_id
    )

    UNION ALL

    SELECT 'CORPORATE_CUSTOMERS -> CUSTOMERS', COUNT(*)
    FROM corporate_customers child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM customers parent
        WHERE parent.customer_id = child.customer_id
    )

    UNION ALL

    SELECT 'CUSTOMER_ADDRESSES -> CUSTOMERS', COUNT(*)
    FROM customer_addresses child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM customers parent
        WHERE parent.customer_id = child.customer_id
    )

    UNION ALL

    SELECT 'CUSTOMER_ADDRESSES -> DISTRICTS', COUNT(*)
    FROM customer_addresses child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM districts parent
        WHERE parent.district_id = child.district_id
    )

    UNION ALL

    SELECT 'CUSTOMER_CONTACTS -> CUSTOMERS', COUNT(*)
    FROM customer_contacts child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM customers parent
        WHERE parent.customer_id = child.customer_id
    )

    UNION ALL

    SELECT 'CUSTOMER_CONTACTS -> CONTACT_TYPES', COUNT(*)
    FROM customer_contacts child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM contact_types parent
        WHERE parent.contact_type_id = child.contact_type_id
    )

    UNION ALL

    SELECT 'DISTRICTS -> CITIES', COUNT(*)
    FROM districts child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM cities parent
        WHERE parent.city_id = child.city_id
    )

    UNION ALL

    SELECT 'EXCHANGE_RATES -> BASE CURRENCY', COUNT(*)
    FROM exchange_rates child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM currencies parent
        WHERE parent.currency_id = child.base_currency_id
    )

    UNION ALL

    SELECT 'EXCHANGE_RATES -> CURRENCIES', COUNT(*)
    FROM exchange_rates child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM currencies parent
        WHERE parent.currency_id = child.currency_id
    )

    UNION ALL

    SELECT 'INDIVIDUAL_CUSTOMERS -> CUSTOMERS', COUNT(*)
    FROM individual_customers child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM customers parent
        WHERE parent.customer_id = child.customer_id
    )

    UNION ALL

    SELECT 'TRANSACTIONS -> TRANSACTION_CHANNELS', COUNT(*)
    FROM transactions child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM transaction_channels parent
        WHERE parent.channel_id = child.channel_id
    )

    UNION ALL

    SELECT 'TRANSACTIONS -> CURRENCIES', COUNT(*)
    FROM transactions child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM currencies parent
        WHERE parent.currency_id = child.currency_id
    )

    UNION ALL

    SELECT 'TRANSACTIONS -> SOURCE ACCOUNT', COUNT(*)
    FROM transactions child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM accounts parent
        WHERE parent.account_id = child.source_account_id
    )

    UNION ALL

    SELECT 'TRANSACTIONS -> TARGET ACCOUNT', COUNT(*)
    FROM transactions child
    WHERE child.target_account_id IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM accounts parent
          WHERE parent.account_id = child.target_account_id
      )

    UNION ALL

    SELECT 'TRANSACTIONS -> TRANSACTION_TYPES', COUNT(*)
    FROM transactions child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM transaction_types parent
        WHERE parent.transaction_type_id = child.transaction_type_id
    )

    UNION ALL

    SELECT 'TRANSACTION_STATUS_HISTORY -> TRANSACTIONS', COUNT(*)
    FROM transaction_status_history child
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM transactions parent
        WHERE parent.transaction_id = child.transaction_id
    )
)
SELECT
    USER AS schema_name,
    COUNT(*) AS checked_relation_count,

    SUM(
        CASE
            WHEN orphan_count = 0 THEN 1
            ELSE 0
        END
    ) AS passed_relation_count,

    SUM(
        CASE
            WHEN orphan_count > 0 THEN 1
            ELSE 0
        END
    ) AS failed_relation_count,

    SUM(orphan_count) AS total_orphan_rows,

    CASE
        WHEN SUM(orphan_count) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS health_status,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM integrity_checks;

PROMPT
PROMPT ================================================================================
PROMPT REFERENTIAL INTEGRITY CHECK DETAILS
PROMPT ================================================================================
PROMPT

COLUMN relationship_name FORMAT A52
COLUMN orphan_count      FORMAT 999,999,999
COLUMN validation_status FORMAT A12

WITH integrity_checks AS
(
    SELECT 'ACCOUNTS -> BRANCHES' AS relationship_name, COUNT(*) AS orphan_count
    FROM accounts child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM branches parent
        WHERE parent.branch_id = child.branch_id
    )

    UNION ALL

    SELECT 'ACCOUNTS -> CURRENCIES', COUNT(*)
    FROM accounts child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM currencies parent
        WHERE parent.currency_id = child.currency_id
    )

    UNION ALL

    SELECT 'ACCOUNTS -> CUSTOMERS', COUNT(*)
    FROM accounts child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM customers parent
        WHERE parent.customer_id = child.customer_id
    )

    UNION ALL

    SELECT 'ACCOUNTS -> ACCOUNT_TYPES', COUNT(*)
    FROM accounts child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM account_types parent
        WHERE parent.account_type_id = child.account_type_id
    )

    UNION ALL

    SELECT 'BENEFICIARIES -> ACCOUNTS', COUNT(*)
    FROM beneficiaries child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM accounts parent
        WHERE parent.account_id = child.beneficiary_account_id
    )

    UNION ALL

    SELECT 'BENEFICIARIES -> CUSTOMERS', COUNT(*)
    FROM beneficiaries child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM customers parent
        WHERE parent.customer_id = child.customer_id
    )

    UNION ALL

    SELECT 'BRANCHES -> CITIES', COUNT(*)
    FROM branches child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM cities parent
        WHERE parent.city_id = child.city_id
    )

    UNION ALL

    SELECT 'CARDS -> ACCOUNTS', COUNT(*)
    FROM cards child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM accounts parent
        WHERE parent.account_id = child.account_id
    )

    UNION ALL

    SELECT 'CARDS -> CARD_TYPES', COUNT(*)
    FROM cards child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM card_types parent
        WHERE parent.card_type_id = child.card_type_id
    )

    UNION ALL

    SELECT 'CITIES -> COUNTRIES', COUNT(*)
    FROM cities child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM countries parent
        WHERE parent.country_id = child.country_id
    )

    UNION ALL

    SELECT 'COMPANIES -> CITIES', COUNT(*)
    FROM companies child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM cities parent
        WHERE parent.city_id = child.city_id
    )

    UNION ALL

    SELECT 'COMPANIES -> SECTORS', COUNT(*)
    FROM companies child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM sectors parent
        WHERE parent.sector_id = child.sector_id
    )

    UNION ALL

    SELECT 'CORPORATE_CUSTOMERS -> COMPANIES', COUNT(*)
    FROM corporate_customers child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM companies parent
        WHERE parent.company_id = child.company_id
    )

    UNION ALL

    SELECT 'CORPORATE_CUSTOMERS -> CUSTOMERS', COUNT(*)
    FROM corporate_customers child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM customers parent
        WHERE parent.customer_id = child.customer_id
    )

    UNION ALL

    SELECT 'CUSTOMER_ADDRESSES -> CUSTOMERS', COUNT(*)
    FROM customer_addresses child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM customers parent
        WHERE parent.customer_id = child.customer_id
    )

    UNION ALL

    SELECT 'CUSTOMER_ADDRESSES -> DISTRICTS', COUNT(*)
    FROM customer_addresses child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM districts parent
        WHERE parent.district_id = child.district_id
    )

    UNION ALL

    SELECT 'CUSTOMER_CONTACTS -> CUSTOMERS', COUNT(*)
    FROM customer_contacts child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM customers parent
        WHERE parent.customer_id = child.customer_id
    )

    UNION ALL

    SELECT 'CUSTOMER_CONTACTS -> CONTACT_TYPES', COUNT(*)
    FROM customer_contacts child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM contact_types parent
        WHERE parent.contact_type_id = child.contact_type_id
    )

    UNION ALL

    SELECT 'DISTRICTS -> CITIES', COUNT(*)
    FROM districts child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM cities parent
        WHERE parent.city_id = child.city_id
    )

    UNION ALL

    SELECT 'EXCHANGE_RATES -> BASE CURRENCY', COUNT(*)
    FROM exchange_rates child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM currencies parent
        WHERE parent.currency_id = child.base_currency_id
    )

    UNION ALL

    SELECT 'EXCHANGE_RATES -> CURRENCIES', COUNT(*)
    FROM exchange_rates child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM currencies parent
        WHERE parent.currency_id = child.currency_id
    )

    UNION ALL

    SELECT 'INDIVIDUAL_CUSTOMERS -> CUSTOMERS', COUNT(*)
    FROM individual_customers child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM customers parent
        WHERE parent.customer_id = child.customer_id
    )

    UNION ALL

    SELECT 'TRANSACTIONS -> TRANSACTION_CHANNELS', COUNT(*)
    FROM transactions child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM transaction_channels parent
        WHERE parent.channel_id = child.channel_id
    )

    UNION ALL

    SELECT 'TRANSACTIONS -> CURRENCIES', COUNT(*)
    FROM transactions child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM currencies parent
        WHERE parent.currency_id = child.currency_id
    )

    UNION ALL

    SELECT 'TRANSACTIONS -> SOURCE ACCOUNT', COUNT(*)
    FROM transactions child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM accounts parent
        WHERE parent.account_id = child.source_account_id
    )

    UNION ALL

    SELECT 'TRANSACTIONS -> TARGET ACCOUNT', COUNT(*)
    FROM transactions child
    WHERE child.target_account_id IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1 FROM accounts parent
          WHERE parent.account_id = child.target_account_id
      )

    UNION ALL

    SELECT 'TRANSACTIONS -> TRANSACTION_TYPES', COUNT(*)
    FROM transactions child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM transaction_types parent
        WHERE parent.transaction_type_id = child.transaction_type_id
    )

    UNION ALL

    SELECT 'TRANSACTION_STATUS_HISTORY -> TRANSACTIONS', COUNT(*)
    FROM transaction_status_history child
    WHERE NOT EXISTS
    (
        SELECT 1 FROM transactions parent
        WHERE parent.transaction_id = child.transaction_id
    )
)
SELECT
    relationship_name,
    orphan_count,

    CASE
        WHEN orphan_count = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status

FROM integrity_checks

ORDER BY
    relationship_name;

PROMPT
PROMPT ================================================================================
PROMPT REFERENTIAL INTEGRITY INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT PASS means no orphaned child row was detected in any reviewed relationship.
PROMPT
PROMPT The report evaluates all 28 foreign-key relationships defined in the schema.
PROMPT
PROMPT Relationship and column mappings are based on USER_CONSTRAINTS and
PROMPT USER_CONS_COLUMNS metadata from the current schema.
PROMPT
PROMPT TARGET_ACCOUNT_ID is evaluated only when it contains a non-NULL value,
PROMPT because the foreign-key column is nullable.
PROMPT
PROMPT Foreign-key metadata status is validated separately in Schema Validation.
PROMPT
PROMPT This script validates actual stored data rather than relying only on
PROMPT constraint metadata.
PROMPT
PROMPT Any ORPHAN_COUNT greater than zero is classified as FAIL and requires review.
PROMPT
PROMPT No row, constraint, table, index, sequence, or schema object is modified.
PROMPT
PROMPT End of referential integrity validation report.