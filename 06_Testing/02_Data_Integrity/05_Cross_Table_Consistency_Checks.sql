-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Data Integrity
-- Script       : 05_Cross_Table_Consistency_Checks.sql
-- Purpose      : Review cross-table consistency conditions that are not fully
--                represented by a single foreign key or check constraint
-- Scope        : Customer, company, beneficiary, account, card, and transaction data
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
PROMPT CROSS-TABLE CONSISTENCY SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN schema_name             FORMAT A20
COLUMN checked_condition_count FORMAT 999,999
COLUMN consistent_count        FORMAT 999,999
COLUMN review_count            FORMAT 999,999
COLUMN observed_row_count      FORMAT 999,999,999
COLUMN assessment_status       FORMAT A12
COLUMN report_time             FORMAT A20

WITH consistency_checks AS
(
    SELECT
        'CUSTOMERS WITHOUT INDIVIDUAL OR CORPORATE DETAIL' AS check_name,
        COUNT(*) AS result_count
    FROM customers customer_data
    WHERE NOT EXISTS
          (
              SELECT 1
              FROM individual_customers individual_data
              WHERE individual_data.customer_id = customer_data.customer_id
          )
      AND NOT EXISTS
          (
              SELECT 1
              FROM corporate_customers corporate_data
              WHERE corporate_data.customer_id = customer_data.customer_id
          )

    UNION ALL

    SELECT
        'CUSTOMERS PRESENT IN BOTH SUBTYPE TABLES',
        COUNT(*)
    FROM individual_customers individual_data
    JOIN corporate_customers corporate_data
      ON corporate_data.customer_id = individual_data.customer_id

    UNION ALL

    SELECT
        'COMPANIES WITHOUT CORPORATE CUSTOMER',
        COUNT(*)
    FROM companies company_data
    WHERE NOT EXISTS
          (
              SELECT 1
              FROM corporate_customers corporate_data
              WHERE corporate_data.company_id = company_data.company_id
          )

    UNION ALL

    SELECT
        'CORPORATE CUSTOMERS WITHOUT COMPANY',
        COUNT(*)
    FROM corporate_customers corporate_data
    WHERE NOT EXISTS
          (
              SELECT 1
              FROM companies company_data
              WHERE company_data.company_id = corporate_data.company_id
          )

    UNION ALL

    SELECT
        'BENEFICIARIES USING CUSTOMER OWN ACCOUNT',
        COUNT(*)
    FROM beneficiaries beneficiary_data
    JOIN accounts account_data
      ON account_data.account_id =
         beneficiary_data.beneficiary_account_id
    WHERE account_data.customer_id = beneficiary_data.customer_id

    UNION ALL

    SELECT
        'TRANSACTIONS WITH SOURCE CURRENCY DIFFERENT FROM TRANSACTION CURRENCY',
        COUNT(*)
    FROM transactions transaction_data
    JOIN accounts source_account
      ON source_account.account_id =
         transaction_data.source_account_id
    WHERE source_account.currency_id <>
          transaction_data.currency_id

    UNION ALL

    SELECT
        'TRANSACTIONS WITH TARGET CURRENCY DIFFERENT FROM TRANSACTION CURRENCY',
        COUNT(*)
    FROM transactions transaction_data
    JOIN accounts target_account
      ON target_account.account_id =
         transaction_data.target_account_id
    WHERE transaction_data.target_account_id IS NOT NULL
      AND target_account.currency_id <>
          transaction_data.currency_id

    UNION ALL

    SELECT
        'CARDS LINKED TO CLOSED ACCOUNTS',
        COUNT(*)
    FROM cards card_data
    JOIN accounts account_data
      ON account_data.account_id = card_data.account_id
    WHERE account_data.status = 'CLOSED'

    UNION ALL

    SELECT
        'ACTIVE CARDS LINKED TO NONACTIVE ACCOUNTS',
        COUNT(*)
    FROM cards card_data
    JOIN accounts account_data
      ON account_data.account_id = card_data.account_id
    WHERE card_data.status = 'ACTIVE'
      AND account_data.status <> 'ACTIVE'

    UNION ALL

    SELECT
        'CLOSED ACCOUNTS WITHOUT CLOSING DATE',
        COUNT(*)
    FROM accounts
    WHERE status = 'CLOSED'
      AND closing_date IS NULL

    UNION ALL

    SELECT
        'NONCLOSED ACCOUNTS WITH CLOSING DATE',
        COUNT(*)
    FROM accounts
    WHERE status <> 'CLOSED'
      AND closing_date IS NOT NULL
)
SELECT
    USER AS schema_name,
    COUNT(*) AS checked_condition_count,

    SUM(
        CASE
            WHEN result_count = 0 THEN 1
            ELSE 0
        END
    ) AS consistent_count,

    SUM(
        CASE
            WHEN result_count > 0 THEN 1
            ELSE 0
        END
    ) AS review_count,

    SUM(result_count) AS observed_row_count,

    CASE
        WHEN SUM(result_count) = 0
            THEN 'CONSISTENT'
        ELSE 'REVIEW'
    END AS assessment_status,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM consistency_checks;

PROMPT
PROMPT ================================================================================
PROMPT CROSS-TABLE CONSISTENCY DETAILS
PROMPT ================================================================================
PROMPT

COLUMN check_name        FORMAT A72
COLUMN result_count      FORMAT 999,999,999
COLUMN assessment_status FORMAT A12

WITH consistency_checks AS
(
    SELECT
        'CUSTOMERS WITHOUT INDIVIDUAL OR CORPORATE DETAIL' AS check_name,
        COUNT(*) AS result_count
    FROM customers customer_data
    WHERE NOT EXISTS
          (
              SELECT 1
              FROM individual_customers individual_data
              WHERE individual_data.customer_id = customer_data.customer_id
          )
      AND NOT EXISTS
          (
              SELECT 1
              FROM corporate_customers corporate_data
              WHERE corporate_data.customer_id = customer_data.customer_id
          )

    UNION ALL

    SELECT
        'CUSTOMERS PRESENT IN BOTH SUBTYPE TABLES',
        COUNT(*)
    FROM individual_customers individual_data
    JOIN corporate_customers corporate_data
      ON corporate_data.customer_id = individual_data.customer_id

    UNION ALL

    SELECT
        'COMPANIES WITHOUT CORPORATE CUSTOMER',
        COUNT(*)
    FROM companies company_data
    WHERE NOT EXISTS
          (
              SELECT 1
              FROM corporate_customers corporate_data
              WHERE corporate_data.company_id = company_data.company_id
          )

    UNION ALL

    SELECT
        'CORPORATE CUSTOMERS WITHOUT COMPANY',
        COUNT(*)
    FROM corporate_customers corporate_data
    WHERE NOT EXISTS
          (
              SELECT 1
              FROM companies company_data
              WHERE company_data.company_id = corporate_data.company_id
          )

    UNION ALL

    SELECT
        'BENEFICIARIES USING CUSTOMER OWN ACCOUNT',
        COUNT(*)
    FROM beneficiaries beneficiary_data
    JOIN accounts account_data
      ON account_data.account_id =
         beneficiary_data.beneficiary_account_id
    WHERE account_data.customer_id = beneficiary_data.customer_id

    UNION ALL

    SELECT
        'TRANSACTIONS WITH SOURCE CURRENCY DIFFERENT FROM TRANSACTION CURRENCY',
        COUNT(*)
    FROM transactions transaction_data
    JOIN accounts source_account
      ON source_account.account_id =
         transaction_data.source_account_id
    WHERE source_account.currency_id <>
          transaction_data.currency_id

    UNION ALL

    SELECT
        'TRANSACTIONS WITH TARGET CURRENCY DIFFERENT FROM TRANSACTION CURRENCY',
        COUNT(*)
    FROM transactions transaction_data
    JOIN accounts target_account
      ON target_account.account_id =
         transaction_data.target_account_id
    WHERE transaction_data.target_account_id IS NOT NULL
      AND target_account.currency_id <>
          transaction_data.currency_id

    UNION ALL

    SELECT
        'CARDS LINKED TO CLOSED ACCOUNTS',
        COUNT(*)
    FROM cards card_data
    JOIN accounts account_data
      ON account_data.account_id = card_data.account_id
    WHERE account_data.status = 'CLOSED'

    UNION ALL

    SELECT
        'ACTIVE CARDS LINKED TO NONACTIVE ACCOUNTS',
        COUNT(*)
    FROM cards card_data
    JOIN accounts account_data
      ON account_data.account_id = card_data.account_id
    WHERE card_data.status = 'ACTIVE'
      AND account_data.status <> 'ACTIVE'

    UNION ALL

    SELECT
        'CLOSED ACCOUNTS WITHOUT CLOSING DATE',
        COUNT(*)
    FROM accounts
    WHERE status = 'CLOSED'
      AND closing_date IS NULL

    UNION ALL

    SELECT
        'NONCLOSED ACCOUNTS WITH CLOSING DATE',
        COUNT(*)
    FROM accounts
    WHERE status <> 'CLOSED'
      AND closing_date IS NOT NULL
)
SELECT
    check_name,
    result_count,

    CASE
        WHEN result_count = 0
            THEN 'CONSISTENT'
        ELSE 'REVIEW'
    END AS assessment_status

FROM consistency_checks

ORDER BY
    check_name;

PROMPT
PROMPT ================================================================================
PROMPT CONDITIONS REQUIRING REVIEW
PROMPT ================================================================================
PROMPT

WITH consistency_checks AS
(
    SELECT
        'CUSTOMERS WITHOUT INDIVIDUAL OR CORPORATE DETAIL' AS check_name,
        COUNT(*) AS result_count
    FROM customers customer_data
    WHERE NOT EXISTS
          (
              SELECT 1
              FROM individual_customers individual_data
              WHERE individual_data.customer_id = customer_data.customer_id
          )
      AND NOT EXISTS
          (
              SELECT 1
              FROM corporate_customers corporate_data
              WHERE corporate_data.customer_id = customer_data.customer_id
          )

    UNION ALL

    SELECT
        'CUSTOMERS PRESENT IN BOTH SUBTYPE TABLES',
        COUNT(*)
    FROM individual_customers individual_data
    JOIN corporate_customers corporate_data
      ON corporate_data.customer_id = individual_data.customer_id

    UNION ALL

    SELECT
        'COMPANIES WITHOUT CORPORATE CUSTOMER',
        COUNT(*)
    FROM companies company_data
    WHERE NOT EXISTS
          (
              SELECT 1
              FROM corporate_customers corporate_data
              WHERE corporate_data.company_id = company_data.company_id
          )

    UNION ALL

    SELECT
        'CORPORATE CUSTOMERS WITHOUT COMPANY',
        COUNT(*)
    FROM corporate_customers corporate_data
    WHERE NOT EXISTS
          (
              SELECT 1
              FROM companies company_data
              WHERE company_data.company_id = corporate_data.company_id
          )

    UNION ALL

    SELECT
        'BENEFICIARIES USING CUSTOMER OWN ACCOUNT',
        COUNT(*)
    FROM beneficiaries beneficiary_data
    JOIN accounts account_data
      ON account_data.account_id =
         beneficiary_data.beneficiary_account_id
    WHERE account_data.customer_id = beneficiary_data.customer_id

    UNION ALL

    SELECT
        'TRANSACTIONS WITH SOURCE CURRENCY DIFFERENT FROM TRANSACTION CURRENCY',
        COUNT(*)
    FROM transactions transaction_data
    JOIN accounts source_account
      ON source_account.account_id =
         transaction_data.source_account_id
    WHERE source_account.currency_id <>
          transaction_data.currency_id

    UNION ALL

    SELECT
        'TRANSACTIONS WITH TARGET CURRENCY DIFFERENT FROM TRANSACTION CURRENCY',
        COUNT(*)
    FROM transactions transaction_data
    JOIN accounts target_account
      ON target_account.account_id =
         transaction_data.target_account_id
    WHERE transaction_data.target_account_id IS NOT NULL
      AND target_account.currency_id <>
          transaction_data.currency_id

    UNION ALL

    SELECT
        'CARDS LINKED TO CLOSED ACCOUNTS',
        COUNT(*)
    FROM cards card_data
    JOIN accounts account_data
      ON account_data.account_id = card_data.account_id
    WHERE account_data.status = 'CLOSED'

    UNION ALL

    SELECT
        'ACTIVE CARDS LINKED TO NONACTIVE ACCOUNTS',
        COUNT(*)
    FROM cards card_data
    JOIN accounts account_data
      ON account_data.account_id = card_data.account_id
    WHERE card_data.status = 'ACTIVE'
      AND account_data.status <> 'ACTIVE'

    UNION ALL

    SELECT
        'CLOSED ACCOUNTS WITHOUT CLOSING DATE',
        COUNT(*)
    FROM accounts
    WHERE status = 'CLOSED'
      AND closing_date IS NULL

    UNION ALL

    SELECT
        'NONCLOSED ACCOUNTS WITH CLOSING DATE',
        COUNT(*)
    FROM accounts
    WHERE status <> 'CLOSED'
      AND closing_date IS NOT NULL
)
SELECT
    check_name,
    result_count,
    'REVIEW' AS assessment_status

FROM consistency_checks

WHERE result_count > 0

ORDER BY
    check_name;

PROMPT
PROMPT ================================================================================
PROMPT CROSS-TABLE CONSISTENCY INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT CONSISTENT means the reviewed condition returned zero rows.
PROMPT
PROMPT REVIEW means rows were found and the result requires business analysis.
PROMPT
PROMPT REVIEW is not automatically equivalent to data corruption or test failure.
PROMPT
PROMPT Customer subtype conditions overlap intentionally with documented subtype
PROMPT validation and provide a consolidated cross-table view.
PROMPT
PROMPT Corporate-customer, beneficiary-ownership, currency-alignment, card-state,
PROMPT and account-closing conditions are cross-table dataset assertions.
PROMPT
PROMPT These assertions describe the validated project dataset and must not be
PROMPT presented as universal banking-industry rules.
PROMPT
PROMPT Referential integrity and documented CHECK constraints are validated in
PROMPT separate scripts.
PROMPT
PROMPT No table, row, constraint, index, sequence, or schema object is modified.
PROMPT
PROMPT End of cross-table consistency assessment.