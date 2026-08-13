-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Data Integrity
-- Script       : 04_Business_Rule_Checks.sql
-- Purpose      : Validate documented data-level business rules and customer
--                subtype consistency
-- Scope        : Core customer, account, card, transaction, and rate data
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
PROMPT BUSINESS RULE HEALTH SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN schema_name        FORMAT A20
COLUMN checked_rule_count FORMAT 999,999
COLUMN passed_rule_count  FORMAT 999,999
COLUMN failed_rule_count  FORMAT 999,999
COLUMN violating_row_count FORMAT 999,999,999
COLUMN health_status      FORMAT A12
COLUMN report_time        FORMAT A20

WITH business_rule_checks AS
(
    SELECT
        'ACCOUNTS: BALANCE MUST BE NONNEGATIVE' AS rule_name,
        COUNT(*) AS violation_count
    FROM accounts
    WHERE balance IS NOT NULL
      AND balance < 0

    UNION ALL

    SELECT
        'ACCOUNTS: ACCOUNT NUMBER LENGTH MUST BE 10 TO 20',
        COUNT(*)
    FROM accounts
    WHERE account_number IS NOT NULL
      AND LENGTH(account_number) NOT BETWEEN 10 AND 20

    UNION ALL

    SELECT
        'ACCOUNTS: CLOSING DATE MUST NOT PRECEDE OPENING DATE',
        COUNT(*)
    FROM accounts
    WHERE closing_date IS NOT NULL
      AND opening_date IS NOT NULL
      AND closing_date < opening_date

    UNION ALL

    SELECT
        'ACCOUNTS: STATUS MUST BE ACTIVE, BLOCKED, OR CLOSED',
        COUNT(*)
    FROM accounts
    WHERE status IS NOT NULL
      AND status NOT IN ('ACTIVE', 'BLOCKED', 'CLOSED')

    UNION ALL

    SELECT
        'ACCOUNTS: IBAN LENGTH MUST BE 15 TO 34',
        COUNT(*)
    FROM accounts
    WHERE iban IS NOT NULL
      AND LENGTH(iban) NOT BETWEEN 15 AND 34

    UNION ALL

    SELECT
        'ACCOUNTS: IBAN MUST BE UPPERCASE',
        COUNT(*)
    FROM accounts
    WHERE iban IS NOT NULL
      AND iban <> UPPER(iban)

    UNION ALL

    SELECT
        'CARDS: EXPIRY DATE MUST BE AFTER 01-JAN-2000',
        COUNT(*)
    FROM cards
    WHERE expiry_date IS NOT NULL
      AND expiry_date <= DATE '2000-01-01'

    UNION ALL

    SELECT
        'CARDS: CARD NUMBER LENGTH MUST BE 16 TO 20',
        COUNT(*)
    FROM cards
    WHERE card_number IS NOT NULL
      AND LENGTH(card_number) NOT BETWEEN 16 AND 20

    UNION ALL

    SELECT
        'CARDS: STATUS MUST BE ACTIVE, BLOCKED, OR CLOSED',
        COUNT(*)
    FROM cards
    WHERE status IS NOT NULL
      AND status NOT IN ('ACTIVE', 'BLOCKED', 'CLOSED')

    UNION ALL

    SELECT
        'CORPORATE CUSTOMERS: TAX NUMBER LENGTH MUST BE 10 OR 11',
        COUNT(*)
    FROM corporate_customers
    WHERE tax_number IS NOT NULL
      AND LENGTH(tax_number) NOT IN (10, 11)

    UNION ALL

    SELECT
        'CUSTOMERS: STATUS MUST BE ACTIVE, BLOCKED, OR CLOSED',
        COUNT(*)
    FROM customers
    WHERE status IS NOT NULL
      AND status NOT IN ('ACTIVE', 'BLOCKED', 'CLOSED')

    UNION ALL

    SELECT
        'CUSTOMERS: TYPE MUST BE I OR C',
        COUNT(*)
    FROM customers
    WHERE customer_type IS NOT NULL
      AND customer_type NOT IN ('I', 'C')

    UNION ALL

    SELECT
        'EXCHANGE RATES: BUY RATE MUST BE POSITIVE',
        COUNT(*)
    FROM exchange_rates
    WHERE buy_rate IS NOT NULL
      AND buy_rate <= 0

    UNION ALL

    SELECT
        'EXCHANGE RATES: BASE AND TARGET CURRENCIES MUST DIFFER',
        COUNT(*)
    FROM exchange_rates
    WHERE currency_id IS NOT NULL
      AND base_currency_id IS NOT NULL
      AND currency_id = base_currency_id

    UNION ALL

    SELECT
        'EXCHANGE RATES: SELL RATE MUST NOT BE BELOW BUY RATE',
        COUNT(*)
    FROM exchange_rates
    WHERE sell_rate IS NOT NULL
      AND buy_rate IS NOT NULL
      AND sell_rate < buy_rate

    UNION ALL

    SELECT
        'EXCHANGE RATES: SELL RATE MUST BE POSITIVE',
        COUNT(*)
    FROM exchange_rates
    WHERE sell_rate IS NOT NULL
      AND sell_rate <= 0

    UNION ALL

    SELECT
        'TRANSACTIONS: AMOUNT MUST BE POSITIVE',
        COUNT(*)
    FROM transactions
    WHERE amount IS NOT NULL
      AND amount <= 0

    UNION ALL

    SELECT
        'TRANSACTIONS: SOURCE AND TARGET ACCOUNTS MUST DIFFER',
        COUNT(*)
    FROM transactions
    WHERE target_account_id IS NOT NULL
      AND source_account_id = target_account_id

    UNION ALL

    SELECT
        'TRANSACTIONS: STATUS MUST BE SUCCESS, FAILED, OR PENDING',
        COUNT(*)
    FROM transactions
    WHERE status IS NOT NULL
      AND status NOT IN ('SUCCESS', 'FAILED', 'PENDING')

    UNION ALL

    SELECT
        'INDIVIDUAL CUSTOMERS: I TYPE MUST HAVE INDIVIDUAL DETAIL',
        COUNT(*)
    FROM customers customer_data
    WHERE customer_data.customer_type = 'I'
      AND NOT EXISTS
          (
              SELECT 1
              FROM individual_customers individual_data
              WHERE individual_data.customer_id = customer_data.customer_id
          )

    UNION ALL

    SELECT
        'CORPORATE CUSTOMERS: C TYPE MUST HAVE CORPORATE DETAIL',
        COUNT(*)
    FROM customers customer_data
    WHERE customer_data.customer_type = 'C'
      AND NOT EXISTS
          (
              SELECT 1
              FROM corporate_customers corporate_data
              WHERE corporate_data.customer_id = customer_data.customer_id
          )

    UNION ALL

    SELECT
        'INDIVIDUAL DETAILS: PARENT CUSTOMER TYPE MUST BE I',
        COUNT(*)
    FROM individual_customers individual_data
    JOIN customers customer_data
      ON customer_data.customer_id = individual_data.customer_id
    WHERE customer_data.customer_type <> 'I'

    UNION ALL

    SELECT
        'CORPORATE DETAILS: PARENT CUSTOMER TYPE MUST BE C',
        COUNT(*)
    FROM corporate_customers corporate_data
    JOIN customers customer_data
      ON customer_data.customer_id = corporate_data.customer_id
    WHERE customer_data.customer_type <> 'C'

    UNION ALL

    SELECT
        'CUSTOMERS: CUSTOMER MUST NOT EXIST IN BOTH SUBTYPE TABLES',
        COUNT(*)
    FROM individual_customers individual_data
    JOIN corporate_customers corporate_data
      ON corporate_data.customer_id = individual_data.customer_id
)
SELECT
    USER AS schema_name,
    COUNT(*) AS checked_rule_count,

    SUM(
        CASE
            WHEN violation_count = 0 THEN 1
            ELSE 0
        END
    ) AS passed_rule_count,

    SUM(
        CASE
            WHEN violation_count > 0 THEN 1
            ELSE 0
        END
    ) AS failed_rule_count,

    SUM(violation_count) AS violating_row_count,

    CASE
        WHEN SUM(violation_count) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS health_status,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM business_rule_checks;

PROMPT
PROMPT ================================================================================
PROMPT BUSINESS RULE CHECK DETAILS
PROMPT ================================================================================
PROMPT

COLUMN rule_name         FORMAT A72
COLUMN violation_count   FORMAT 999,999,999
COLUMN validation_status FORMAT A12

WITH business_rule_checks AS
(
    SELECT
        'ACCOUNTS: BALANCE MUST BE NONNEGATIVE' AS rule_name,
        COUNT(*) AS violation_count
    FROM accounts
    WHERE balance IS NOT NULL
      AND balance < 0

    UNION ALL

    SELECT
        'ACCOUNTS: ACCOUNT NUMBER LENGTH MUST BE 10 TO 20',
        COUNT(*)
    FROM accounts
    WHERE account_number IS NOT NULL
      AND LENGTH(account_number) NOT BETWEEN 10 AND 20

    UNION ALL

    SELECT
        'ACCOUNTS: CLOSING DATE MUST NOT PRECEDE OPENING DATE',
        COUNT(*)
    FROM accounts
    WHERE closing_date IS NOT NULL
      AND opening_date IS NOT NULL
      AND closing_date < opening_date

    UNION ALL

    SELECT
        'ACCOUNTS: STATUS MUST BE ACTIVE, BLOCKED, OR CLOSED',
        COUNT(*)
    FROM accounts
    WHERE status IS NOT NULL
      AND status NOT IN ('ACTIVE', 'BLOCKED', 'CLOSED')

    UNION ALL

    SELECT
        'ACCOUNTS: IBAN LENGTH MUST BE 15 TO 34',
        COUNT(*)
    FROM accounts
    WHERE iban IS NOT NULL
      AND LENGTH(iban) NOT BETWEEN 15 AND 34

    UNION ALL

    SELECT
        'ACCOUNTS: IBAN MUST BE UPPERCASE',
        COUNT(*)
    FROM accounts
    WHERE iban IS NOT NULL
      AND iban <> UPPER(iban)

    UNION ALL

    SELECT
        'CARDS: EXPIRY DATE MUST BE AFTER 01-JAN-2000',
        COUNT(*)
    FROM cards
    WHERE expiry_date IS NOT NULL
      AND expiry_date <= DATE '2000-01-01'

    UNION ALL

    SELECT
        'CARDS: CARD NUMBER LENGTH MUST BE 16 TO 20',
        COUNT(*)
    FROM cards
    WHERE card_number IS NOT NULL
      AND LENGTH(card_number) NOT BETWEEN 16 AND 20

    UNION ALL

    SELECT
        'CARDS: STATUS MUST BE ACTIVE, BLOCKED, OR CLOSED',
        COUNT(*)
    FROM cards
    WHERE status IS NOT NULL
      AND status NOT IN ('ACTIVE', 'BLOCKED', 'CLOSED')

    UNION ALL

    SELECT
        'CORPORATE CUSTOMERS: TAX NUMBER LENGTH MUST BE 10 OR 11',
        COUNT(*)
    FROM corporate_customers
    WHERE tax_number IS NOT NULL
      AND LENGTH(tax_number) NOT IN (10, 11)

    UNION ALL

    SELECT
        'CUSTOMERS: STATUS MUST BE ACTIVE, BLOCKED, OR CLOSED',
        COUNT(*)
    FROM customers
    WHERE status IS NOT NULL
      AND status NOT IN ('ACTIVE', 'BLOCKED', 'CLOSED')

    UNION ALL

    SELECT
        'CUSTOMERS: TYPE MUST BE I OR C',
        COUNT(*)
    FROM customers
    WHERE customer_type IS NOT NULL
      AND customer_type NOT IN ('I', 'C')

    UNION ALL

    SELECT
        'EXCHANGE RATES: BUY RATE MUST BE POSITIVE',
        COUNT(*)
    FROM exchange_rates
    WHERE buy_rate IS NOT NULL
      AND buy_rate <= 0

    UNION ALL

    SELECT
        'EXCHANGE RATES: BASE AND TARGET CURRENCIES MUST DIFFER',
        COUNT(*)
    FROM exchange_rates
    WHERE currency_id IS NOT NULL
      AND base_currency_id IS NOT NULL
      AND currency_id = base_currency_id

    UNION ALL

    SELECT
        'EXCHANGE RATES: SELL RATE MUST NOT BE BELOW BUY RATE',
        COUNT(*)
    FROM exchange_rates
    WHERE sell_rate IS NOT NULL
      AND buy_rate IS NOT NULL
      AND sell_rate < buy_rate

    UNION ALL

    SELECT
        'EXCHANGE RATES: SELL RATE MUST BE POSITIVE',
        COUNT(*)
    FROM exchange_rates
    WHERE sell_rate IS NOT NULL
      AND sell_rate <= 0

    UNION ALL

    SELECT
        'TRANSACTIONS: AMOUNT MUST BE POSITIVE',
        COUNT(*)
    FROM transactions
    WHERE amount IS NOT NULL
      AND amount <= 0

    UNION ALL

    SELECT
        'TRANSACTIONS: SOURCE AND TARGET ACCOUNTS MUST DIFFER',
        COUNT(*)
    FROM transactions
    WHERE target_account_id IS NOT NULL
      AND source_account_id = target_account_id

    UNION ALL

    SELECT
        'TRANSACTIONS: STATUS MUST BE SUCCESS, FAILED, OR PENDING',
        COUNT(*)
    FROM transactions
    WHERE status IS NOT NULL
      AND status NOT IN ('SUCCESS', 'FAILED', 'PENDING')

    UNION ALL

    SELECT
        'INDIVIDUAL CUSTOMERS: I TYPE MUST HAVE INDIVIDUAL DETAIL',
        COUNT(*)
    FROM customers customer_data
    WHERE customer_data.customer_type = 'I'
      AND NOT EXISTS
          (
              SELECT 1
              FROM individual_customers individual_data
              WHERE individual_data.customer_id = customer_data.customer_id
          )

    UNION ALL

    SELECT
        'CORPORATE CUSTOMERS: C TYPE MUST HAVE CORPORATE DETAIL',
        COUNT(*)
    FROM customers customer_data
    WHERE customer_data.customer_type = 'C'
      AND NOT EXISTS
          (
              SELECT 1
              FROM corporate_customers corporate_data
              WHERE corporate_data.customer_id = customer_data.customer_id
          )

    UNION ALL

    SELECT
        'INDIVIDUAL DETAILS: PARENT CUSTOMER TYPE MUST BE I',
        COUNT(*)
    FROM individual_customers individual_data
    JOIN customers customer_data
      ON customer_data.customer_id = individual_data.customer_id
    WHERE customer_data.customer_type <> 'I'

    UNION ALL

    SELECT
        'CORPORATE DETAILS: PARENT CUSTOMER TYPE MUST BE C',
        COUNT(*)
    FROM corporate_customers corporate_data
    JOIN customers customer_data
      ON customer_data.customer_id = corporate_data.customer_id
    WHERE customer_data.customer_type <> 'C'

    UNION ALL

    SELECT
        'CUSTOMERS: CUSTOMER MUST NOT EXIST IN BOTH SUBTYPE TABLES',
        COUNT(*)
    FROM individual_customers individual_data
    JOIN corporate_customers corporate_data
      ON corporate_data.customer_id = individual_data.customer_id
)
SELECT
    rule_name,
    violation_count,

    CASE
        WHEN violation_count = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status

FROM business_rule_checks

ORDER BY
    rule_name;

PROMPT
PROMPT ================================================================================
PROMPT FAILED BUSINESS RULE CHECKS
PROMPT ================================================================================
PROMPT

COLUMN rule_name         FORMAT A72
COLUMN violation_count   FORMAT 999,999,999
COLUMN validation_status FORMAT A12

WITH business_rule_checks AS
(
    SELECT
        'ACCOUNTS: BALANCE MUST BE NONNEGATIVE' AS rule_name,
        COUNT(*) AS violation_count
    FROM accounts
    WHERE balance IS NOT NULL
      AND balance < 0

    UNION ALL

    SELECT
        'ACCOUNTS: ACCOUNT NUMBER LENGTH MUST BE 10 TO 20',
        COUNT(*)
    FROM accounts
    WHERE account_number IS NOT NULL
      AND LENGTH(account_number) NOT BETWEEN 10 AND 20

    UNION ALL

    SELECT
        'ACCOUNTS: CLOSING DATE MUST NOT PRECEDE OPENING DATE',
        COUNT(*)
    FROM accounts
    WHERE closing_date IS NOT NULL
      AND opening_date IS NOT NULL
      AND closing_date < opening_date

    UNION ALL

    SELECT
        'ACCOUNTS: STATUS MUST BE ACTIVE, BLOCKED, OR CLOSED',
        COUNT(*)
    FROM accounts
    WHERE status IS NOT NULL
      AND status NOT IN ('ACTIVE', 'BLOCKED', 'CLOSED')

    UNION ALL

    SELECT
        'ACCOUNTS: IBAN LENGTH MUST BE 15 TO 34',
        COUNT(*)
    FROM accounts
    WHERE iban IS NOT NULL
      AND LENGTH(iban) NOT BETWEEN 15 AND 34

    UNION ALL

    SELECT
        'ACCOUNTS: IBAN MUST BE UPPERCASE',
        COUNT(*)
    FROM accounts
    WHERE iban IS NOT NULL
      AND iban <> UPPER(iban)

    UNION ALL

    SELECT
        'CARDS: EXPIRY DATE MUST BE AFTER 01-JAN-2000',
        COUNT(*)
    FROM cards
    WHERE expiry_date IS NOT NULL
      AND expiry_date <= DATE '2000-01-01'

    UNION ALL

    SELECT
        'CARDS: CARD NUMBER LENGTH MUST BE 16 TO 20',
        COUNT(*)
    FROM cards
    WHERE card_number IS NOT NULL
      AND LENGTH(card_number) NOT BETWEEN 16 AND 20

    UNION ALL

    SELECT
        'CARDS: STATUS MUST BE ACTIVE, BLOCKED, OR CLOSED',
        COUNT(*)
    FROM cards
    WHERE status IS NOT NULL
      AND status NOT IN ('ACTIVE', 'BLOCKED', 'CLOSED')

    UNION ALL

    SELECT
        'CORPORATE CUSTOMERS: TAX NUMBER LENGTH MUST BE 10 OR 11',
        COUNT(*)
    FROM corporate_customers
    WHERE tax_number IS NOT NULL
      AND LENGTH(tax_number) NOT IN (10, 11)

    UNION ALL

    SELECT
        'CUSTOMERS: STATUS MUST BE ACTIVE, BLOCKED, OR CLOSED',
        COUNT(*)
    FROM customers
    WHERE status IS NOT NULL
      AND status NOT IN ('ACTIVE', 'BLOCKED', 'CLOSED')

    UNION ALL

    SELECT
        'CUSTOMERS: TYPE MUST BE I OR C',
        COUNT(*)
    FROM customers
    WHERE customer_type IS NOT NULL
      AND customer_type NOT IN ('I', 'C')

    UNION ALL

    SELECT
        'EXCHANGE RATES: BUY RATE MUST BE POSITIVE',
        COUNT(*)
    FROM exchange_rates
    WHERE buy_rate IS NOT NULL
      AND buy_rate <= 0

    UNION ALL

    SELECT
        'EXCHANGE RATES: BASE AND TARGET CURRENCIES MUST DIFFER',
        COUNT(*)
    FROM exchange_rates
    WHERE currency_id IS NOT NULL
      AND base_currency_id IS NOT NULL
      AND currency_id = base_currency_id

    UNION ALL

    SELECT
        'EXCHANGE RATES: SELL RATE MUST NOT BE BELOW BUY RATE',
        COUNT(*)
    FROM exchange_rates
    WHERE sell_rate IS NOT NULL
      AND buy_rate IS NOT NULL
      AND sell_rate < buy_rate

    UNION ALL

    SELECT
        'EXCHANGE RATES: SELL RATE MUST BE POSITIVE',
        COUNT(*)
    FROM exchange_rates
    WHERE sell_rate IS NOT NULL
      AND sell_rate <= 0

    UNION ALL

    SELECT
        'TRANSACTIONS: AMOUNT MUST BE POSITIVE',
        COUNT(*)
    FROM transactions
    WHERE amount IS NOT NULL
      AND amount <= 0

    UNION ALL

    SELECT
        'TRANSACTIONS: SOURCE AND TARGET ACCOUNTS MUST DIFFER',
        COUNT(*)
    FROM transactions
    WHERE target_account_id IS NOT NULL
      AND source_account_id = target_account_id

    UNION ALL

    SELECT
        'TRANSACTIONS: STATUS MUST BE SUCCESS, FAILED, OR PENDING',
        COUNT(*)
    FROM transactions
    WHERE status IS NOT NULL
      AND status NOT IN ('SUCCESS', 'FAILED', 'PENDING')

    UNION ALL

    SELECT
        'INDIVIDUAL CUSTOMERS: I TYPE MUST HAVE INDIVIDUAL DETAIL',
        COUNT(*)
    FROM customers customer_data
    WHERE customer_data.customer_type = 'I'
      AND NOT EXISTS
          (
              SELECT 1
              FROM individual_customers individual_data
              WHERE individual_data.customer_id = customer_data.customer_id
          )

    UNION ALL

    SELECT
        'CORPORATE CUSTOMERS: C TYPE MUST HAVE CORPORATE DETAIL',
        COUNT(*)
    FROM customers customer_data
    WHERE customer_data.customer_type = 'C'
      AND NOT EXISTS
          (
              SELECT 1
              FROM corporate_customers corporate_data
              WHERE corporate_data.customer_id = customer_data.customer_id
          )

    UNION ALL

    SELECT
        'INDIVIDUAL DETAILS: PARENT CUSTOMER TYPE MUST BE I',
        COUNT(*)
    FROM individual_customers individual_data
    JOIN customers customer_data
      ON customer_data.customer_id = individual_data.customer_id
    WHERE customer_data.customer_type <> 'I'

    UNION ALL

    SELECT
        'CORPORATE DETAILS: PARENT CUSTOMER TYPE MUST BE C',
        COUNT(*)
    FROM corporate_customers corporate_data
    JOIN customers customer_data
      ON customer_data.customer_id = corporate_data.customer_id
    WHERE customer_data.customer_type <> 'C'

    UNION ALL

    SELECT
        'CUSTOMERS: CUSTOMER MUST NOT EXIST IN BOTH SUBTYPE TABLES',
        COUNT(*)
    FROM individual_customers individual_data
    JOIN corporate_customers corporate_data
      ON corporate_data.customer_id = individual_data.customer_id
)
SELECT
    rule_name,
    violation_count,
    'FAIL' AS validation_status

FROM business_rule_checks

WHERE violation_count > 0

ORDER BY
    rule_name;

PROMPT
PROMPT ================================================================================
PROMPT BUSINESS RULE INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT PASS means no stored row violated the reviewed business rule.
PROMPT
PROMPT Nineteen checks reproduce the documented application CHECK constraints
PROMPT using actual stored data.
PROMPT
PROMPT Five additional checks validate the CUSTOMER_TYPE subtype model across
PROMPT CUSTOMERS, INDIVIDUAL_CUSTOMERS, and CORPORATE_CUSTOMERS.
PROMPT
PROMPT CHECK-constraint tests preserve Oracle NULL semantics by evaluating only
PROMPT non-NULL values where the documented constraint permits NULL.
PROMPT
PROMPT NOT NULL enforcement is validated through the enabled and validated
PROMPT constraint checks in the Schema Validation module.
PROMPT
PROMPT Customer subtype checks confirm that every I customer has one individual
PROMPT detail row, every C customer has one corporate detail row, subtype rows
PROMPT match the parent type, and no customer exists in both subtype tables.
PROMPT
PROMPT No undocumented assumptions are made about transaction currency matching,
PROMPT beneficiary ownership, account closure behavior, or card lifecycle rules.
PROMPT
PROMPT No table, row, constraint, index, sequence, or schema object is modified.
PROMPT
PROMPT End of business rule validation report.