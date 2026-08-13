-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Data Integrity
-- Script       : 01_Row_Count_Validation.sql
-- Purpose      : Validate current row counts against the documented minimum
--                dataset baseline
-- Scope        : Core banking tables and supporting application tables
-- Safety       : Read-only
-- Environment  : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- ============================================================================

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 500
SET LINESIZE 220
SET FEEDBACK ON
SET VERIFY OFF
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

PROMPT
PROMPT ================================================================================
PROMPT ROW COUNT VALIDATION SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN schema_name          FORMAT A20
COLUMN checked_table_count  FORMAT 999,999
COLUMN matched_table_count  FORMAT 999,999
COLUMN above_baseline_count FORMAT 999,999
COLUMN below_baseline_count FORMAT 999,999
COLUMN health_status        FORMAT A12
COLUMN report_time          FORMAT A20

WITH expected_counts AS
(
    SELECT 'CUSTOMERS' AS table_name, 10000 AS baseline_count FROM dual
    UNION ALL
    SELECT 'ACCOUNTS', 21000 FROM dual
    UNION ALL
    SELECT 'CUSTOMER_ADDRESSES', 14293 FROM dual
    UNION ALL
    SELECT 'CUSTOMER_CONTACTS', 22850 FROM dual
    UNION ALL
    SELECT 'CARDS', 7866 FROM dual
    UNION ALL
    SELECT 'TRANSACTIONS', 200000 FROM dual
    UNION ALL
    SELECT 'BENEFICIARIES', 15644 FROM dual
),
actual_counts AS
(
    SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS actual_count
    FROM customers

    UNION ALL

    SELECT 'ACCOUNTS', COUNT(*)
    FROM accounts

    UNION ALL

    SELECT 'CUSTOMER_ADDRESSES', COUNT(*)
    FROM customer_addresses

    UNION ALL

    SELECT 'CUSTOMER_CONTACTS', COUNT(*)
    FROM customer_contacts

    UNION ALL

    SELECT 'CARDS', COUNT(*)
    FROM cards

    UNION ALL

    SELECT 'TRANSACTIONS', COUNT(*)
    FROM transactions

    UNION ALL

    SELECT 'BENEFICIARIES', COUNT(*)
    FROM beneficiaries
),
validation_results AS
(
    SELECT
        expected.table_name,
        expected.baseline_count,
        actual.actual_count,

        CASE
            WHEN actual.actual_count = expected.baseline_count
                THEN 'MATCH'

            WHEN actual.actual_count > expected.baseline_count
                THEN 'ABOVE BASELINE'

            ELSE 'BELOW BASELINE'
        END AS validation_status

    FROM expected_counts expected

    JOIN actual_counts actual
      ON actual.table_name = expected.table_name
)
SELECT
    USER AS schema_name,
    COUNT(*) AS checked_table_count,

    SUM(
        CASE
            WHEN validation_status = 'MATCH' THEN 1
            ELSE 0
        END
    ) AS matched_table_count,

    SUM(
        CASE
            WHEN validation_status = 'ABOVE BASELINE' THEN 1
            ELSE 0
        END
    ) AS above_baseline_count,

    SUM(
        CASE
            WHEN validation_status = 'BELOW BASELINE' THEN 1
            ELSE 0
        END
    ) AS below_baseline_count,

    CASE
        WHEN SUM(
                 CASE
                     WHEN validation_status = 'BELOW BASELINE' THEN 1
                     ELSE 0
                 END
             ) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS health_status,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM validation_results;

PROMPT
PROMPT ================================================================================
PROMPT CORE DATASET ROW COUNT VALIDATION
PROMPT ================================================================================
PROMPT

COLUMN table_name        FORMAT A30
COLUMN baseline_count    FORMAT 999,999,999
COLUMN actual_count      FORMAT 999,999,999
COLUMN difference_count  FORMAT 999,999,999
COLUMN validation_status FORMAT A18

WITH expected_counts AS
(
    SELECT 'CUSTOMERS' AS table_name, 10000 AS baseline_count FROM dual
    UNION ALL
    SELECT 'ACCOUNTS', 21000 FROM dual
    UNION ALL
    SELECT 'CUSTOMER_ADDRESSES', 14293 FROM dual
    UNION ALL
    SELECT 'CUSTOMER_CONTACTS', 22850 FROM dual
    UNION ALL
    SELECT 'CARDS', 7866 FROM dual
    UNION ALL
    SELECT 'TRANSACTIONS', 200000 FROM dual
    UNION ALL
    SELECT 'BENEFICIARIES', 15644 FROM dual
),
actual_counts AS
(
    SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS actual_count
    FROM customers

    UNION ALL

    SELECT 'ACCOUNTS', COUNT(*)
    FROM accounts

    UNION ALL

    SELECT 'CUSTOMER_ADDRESSES', COUNT(*)
    FROM customer_addresses

    UNION ALL

    SELECT 'CUSTOMER_CONTACTS', COUNT(*)
    FROM customer_contacts

    UNION ALL

    SELECT 'CARDS', COUNT(*)
    FROM cards

    UNION ALL

    SELECT 'TRANSACTIONS', COUNT(*)
    FROM transactions

    UNION ALL

    SELECT 'BENEFICIARIES', COUNT(*)
    FROM beneficiaries
)
SELECT
    expected.table_name,
    expected.baseline_count,
    actual.actual_count,
    actual.actual_count - expected.baseline_count AS difference_count,

    CASE
        WHEN actual.actual_count = expected.baseline_count
            THEN 'MATCH'

        WHEN actual.actual_count > expected.baseline_count
            THEN 'ABOVE BASELINE'

        ELSE 'BELOW BASELINE'
    END AS validation_status

FROM expected_counts expected

JOIN actual_counts actual
  ON actual.table_name = expected.table_name

ORDER BY
    CASE expected.table_name
        WHEN 'CUSTOMERS' THEN 1
        WHEN 'ACCOUNTS' THEN 2
        WHEN 'CUSTOMER_ADDRESSES' THEN 3
        WHEN 'CUSTOMER_CONTACTS' THEN 4
        WHEN 'CARDS' THEN 5
        WHEN 'TRANSACTIONS' THEN 6
        WHEN 'BENEFICIARIES' THEN 7
        ELSE 8
    END;

PROMPT
PROMPT ================================================================================
PROMPT BELOW-BASELINE ROW COUNT FAILURES
PROMPT ================================================================================
PROMPT

WITH expected_counts AS
(
    SELECT 'CUSTOMERS' AS table_name, 10000 AS baseline_count FROM dual
    UNION ALL
    SELECT 'ACCOUNTS', 21000 FROM dual
    UNION ALL
    SELECT 'CUSTOMER_ADDRESSES', 14293 FROM dual
    UNION ALL
    SELECT 'CUSTOMER_CONTACTS', 22850 FROM dual
    UNION ALL
    SELECT 'CARDS', 7866 FROM dual
    UNION ALL
    SELECT 'TRANSACTIONS', 200000 FROM dual
    UNION ALL
    SELECT 'BENEFICIARIES', 15644 FROM dual
),
actual_counts AS
(
    SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS actual_count
    FROM customers

    UNION ALL

    SELECT 'ACCOUNTS', COUNT(*)
    FROM accounts

    UNION ALL

    SELECT 'CUSTOMER_ADDRESSES', COUNT(*)
    FROM customer_addresses

    UNION ALL

    SELECT 'CUSTOMER_CONTACTS', COUNT(*)
    FROM customer_contacts

    UNION ALL

    SELECT 'CARDS', COUNT(*)
    FROM cards

    UNION ALL

    SELECT 'TRANSACTIONS', COUNT(*)
    FROM transactions

    UNION ALL

    SELECT 'BENEFICIARIES', COUNT(*)
    FROM beneficiaries
)
SELECT
    expected.table_name,
    expected.baseline_count,
    actual.actual_count,
    actual.actual_count - expected.baseline_count AS difference_count,
    'BELOW BASELINE' AS validation_status

FROM expected_counts expected

JOIN actual_counts actual
  ON actual.table_name = expected.table_name

WHERE actual.actual_count < expected.baseline_count

ORDER BY
    expected.table_name;

PROMPT
PROMPT ================================================================================
PROMPT SUPPORTING TABLE ROW COUNTS
PROMPT ================================================================================
PROMPT

COLUMN table_name   FORMAT A30
COLUMN actual_count FORMAT 999,999,999

SELECT 'ACCOUNT_TYPES' AS table_name, COUNT(*) AS actual_count
FROM account_types

UNION ALL

SELECT 'BRANCHES', COUNT(*)
FROM branches

UNION ALL

SELECT 'CARD_TYPES', COUNT(*)
FROM card_types

UNION ALL

SELECT 'CITIES', COUNT(*)
FROM cities

UNION ALL

SELECT 'COMPANIES', COUNT(*)
FROM companies

UNION ALL

SELECT 'CONTACT_TYPES', COUNT(*)
FROM contact_types

UNION ALL

SELECT 'CORPORATE_CUSTOMERS', COUNT(*)
FROM corporate_customers

UNION ALL

SELECT 'COUNTRIES', COUNT(*)
FROM countries

UNION ALL

SELECT 'CURRENCIES', COUNT(*)
FROM currencies

UNION ALL

SELECT 'DISTRICTS', COUNT(*)
FROM districts

UNION ALL

SELECT 'EXCHANGE_RATES', COUNT(*)
FROM exchange_rates

UNION ALL

SELECT 'INDIVIDUAL_CUSTOMERS', COUNT(*)
FROM individual_customers

UNION ALL

SELECT 'SECTORS', COUNT(*)
FROM sectors

UNION ALL

SELECT 'TRANSACTION_CHANNELS', COUNT(*)
FROM transaction_channels

UNION ALL

SELECT 'TRANSACTION_STATUS_HISTORY', COUNT(*)
FROM transaction_status_history

UNION ALL

SELECT 'TRANSACTION_TYPES', COUNT(*)
FROM transaction_types

ORDER BY
    table_name;

PROMPT
PROMPT ================================================================================
PROMPT EMPTY APPLICATION TABLES
PROMPT ================================================================================
PROMPT

COLUMN table_name FORMAT A30

WITH table_counts AS
(
    SELECT 'ACCOUNTS' AS table_name, COUNT(*) AS row_count
    FROM accounts

    UNION ALL

    SELECT 'ACCOUNT_TYPES', COUNT(*)
    FROM account_types

    UNION ALL

    SELECT 'AUDIT_LOGS', COUNT(*)
    FROM audit_logs

    UNION ALL

    SELECT 'BENEFICIARIES', COUNT(*)
    FROM beneficiaries

    UNION ALL

    SELECT 'BRANCHES', COUNT(*)
    FROM branches

    UNION ALL

    SELECT 'CARDS', COUNT(*)
    FROM cards

    UNION ALL

    SELECT 'CARD_TYPES', COUNT(*)
    FROM card_types

    UNION ALL

    SELECT 'CITIES', COUNT(*)
    FROM cities

    UNION ALL

    SELECT 'COMPANIES', COUNT(*)
    FROM companies

    UNION ALL

    SELECT 'CONTACT_TYPES', COUNT(*)
    FROM contact_types

    UNION ALL

    SELECT 'CORPORATE_CUSTOMERS', COUNT(*)
    FROM corporate_customers

    UNION ALL

    SELECT 'COUNTRIES', COUNT(*)
    FROM countries

    UNION ALL

    SELECT 'CURRENCIES', COUNT(*)
    FROM currencies

    UNION ALL

    SELECT 'CUSTOMERS', COUNT(*)
    FROM customers

    UNION ALL

    SELECT 'CUSTOMER_ADDRESSES', COUNT(*)
    FROM customer_addresses

    UNION ALL

    SELECT 'CUSTOMER_CONTACTS', COUNT(*)
    FROM customer_contacts

    UNION ALL

    SELECT 'DDL_AUDIT_LOGS', COUNT(*)
    FROM ddl_audit_logs

    UNION ALL

    SELECT 'DISTRICTS', COUNT(*)
    FROM districts

    UNION ALL

    SELECT 'ERROR_LOGS', COUNT(*)
    FROM error_logs

    UNION ALL

    SELECT 'EXCHANGE_RATES', COUNT(*)
    FROM exchange_rates

    UNION ALL

    SELECT 'INDIVIDUAL_CUSTOMERS', COUNT(*)
    FROM individual_customers

    UNION ALL

    SELECT 'SECTORS', COUNT(*)
    FROM sectors

    UNION ALL

    SELECT 'TRANSACTIONS', COUNT(*)
    FROM transactions

    UNION ALL

    SELECT 'TRANSACTION_CHANNELS', COUNT(*)
    FROM transaction_channels

    UNION ALL

    SELECT 'TRANSACTION_STATUS_HISTORY', COUNT(*)
    FROM transaction_status_history

    UNION ALL

    SELECT 'TRANSACTION_TYPES', COUNT(*)
    FROM transaction_types
)
SELECT
    table_name

FROM table_counts

WHERE row_count = 0

ORDER BY
    table_name;

PROMPT
PROMPT ================================================================================
PROMPT ROW COUNT INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT PASS means no core dataset table contains fewer rows than its documented
PROMPT minimum baseline.
PROMPT
PROMPT MATCH means the current row count exactly matches the documented baseline.
PROMPT
PROMPT ABOVE BASELINE means additional rows have been inserted after the baseline,
PROMPT for example through package, integration, or workflow testing.
PROMPT
PROMPT BELOW BASELINE is classified as a failure because it may indicate data loss,
PROMPT incomplete deployment, or unintended deletion.
PROMPT
PROMPT Supporting table counts are informational and are not included in the
PROMPT overall PASS or FAIL result.
PROMPT
PROMPT Empty tables are reported for review and are not automatically classified
PROMPT as failures because operational or history tables may legitimately be empty.
PROMPT
PROMPT COUNT(*) is used intentionally because this is a data validation test rather
PROMPT than an optimizer-statistics report.
PROMPT
PROMPT No table, row, sequence, constraint, or application object is modified.
PROMPT
PROMPT End of row count validation report.