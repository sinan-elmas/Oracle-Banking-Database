-- ============================================================================
-- Oracle Banking Database
-- Module       : 02_Data_Deployment / 02_Data_Import
-- Script       : 05_Data_Import_Postcheck.sql
-- Purpose      : Validate the imported 23-table banking dataset, excluded log
--                tables, relational consistency, constraints, and sequence
--                safety after DATA_ONLY import
-- Execution    : Run as BANKING_DB after:
--                  1. Data Pump import
--                  2. 04_Synchronize_Application_Sequences.sql
-- Safety       : Read-only
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 500
SET LINESIZE 260
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

WHENEVER SQLERROR EXIT SQL.SQLCODE

COLUMN table_name           FORMAT A34
COLUMN expected_rows        FORMAT 999999999
COLUMN actual_rows          FORMAT 999999999
COLUMN result               FORMAT A10
COLUMN check_name           FORMAT A48
COLUMN expected_value       FORMAT 999999999
COLUMN actual_value         FORMAT 999999999
COLUMN constraint_type      FORMAT A22
COLUMN status               FORMAT A10
COLUMN validated            FORMAT A12
COLUMN sequence_name        FORMAT A32
COLUMN identity_column      FORMAT A34
COLUMN sequence_last_number FORMAT 9999999999999999999999999999
COLUMN required_next_value  FORMAT 9999999999999999999999999999
COLUMN log_scope            FORMAT A28

PROMPT
PROMPT ================================================================================
PROMPT DATA IMPORT POSTCHECK
PROMPT ================================================================================
PROMPT

PROMPT
PROMPT --- A. TARGET DATABASE CONTEXT ---
PROMPT

COLUMN current_user   FORMAT A25
COLUMN container_name FORMAT A25
COLUMN database_name  FORMAT A20

SELECT
    USER AS current_user,
    SYS_CONTEXT('USERENV', 'CON_NAME') AS container_name,
    SYS_CONTEXT('USERENV', 'DB_NAME') AS database_name
FROM dual;

PROMPT
PROMPT --- B. IMPORTED TABLE ROW-COUNT VALIDATION ---
PROMPT

WITH expected_counts AS
(
    SELECT 'ACCOUNTS' AS table_name, 21000 AS expected_rows FROM dual
    UNION ALL SELECT 'ACCOUNT_TYPES', 5 FROM dual
    UNION ALL SELECT 'BENEFICIARIES', 15644 FROM dual
    UNION ALL SELECT 'BRANCHES', 50 FROM dual
    UNION ALL SELECT 'CARDS', 7866 FROM dual
    UNION ALL SELECT 'CARD_TYPES', 5 FROM dual
    UNION ALL SELECT 'CITIES', 81 FROM dual
    UNION ALL SELECT 'COMPANIES', 1001 FROM dual
    UNION ALL SELECT 'CONTACT_TYPES', 5 FROM dual
    UNION ALL SELECT 'CORPORATE_CUSTOMERS', 1001 FROM dual
    UNION ALL SELECT 'COUNTRIES', 8 FROM dual
    UNION ALL SELECT 'CURRENCIES', 8 FROM dual
    UNION ALL SELECT 'CUSTOMERS', 10003 FROM dual
    UNION ALL SELECT 'CUSTOMER_ADDRESSES', 14293 FROM dual
    UNION ALL SELECT 'CUSTOMER_CONTACTS', 22850 FROM dual
    UNION ALL SELECT 'DISTRICTS', 973 FROM dual
    UNION ALL SELECT 'EXCHANGE_RATES', 7 FROM dual
    UNION ALL SELECT 'INDIVIDUAL_CUSTOMERS', 9002 FROM dual
    UNION ALL SELECT 'SECTORS', 14 FROM dual
    UNION ALL SELECT 'TRANSACTIONS', 200000 FROM dual
    UNION ALL SELECT 'TRANSACTION_CHANNELS', 5 FROM dual
    UNION ALL SELECT 'TRANSACTION_STATUS_HISTORY', 0 FROM dual
    UNION ALL SELECT 'TRANSACTION_TYPES', 6 FROM dual
),
actual_counts AS
(
    SELECT 'ACCOUNTS' AS table_name, COUNT(*) AS actual_rows FROM accounts
    UNION ALL SELECT 'ACCOUNT_TYPES', COUNT(*) FROM account_types
    UNION ALL SELECT 'BENEFICIARIES', COUNT(*) FROM beneficiaries
    UNION ALL SELECT 'BRANCHES', COUNT(*) FROM branches
    UNION ALL SELECT 'CARDS', COUNT(*) FROM cards
    UNION ALL SELECT 'CARD_TYPES', COUNT(*) FROM card_types
    UNION ALL SELECT 'CITIES', COUNT(*) FROM cities
    UNION ALL SELECT 'COMPANIES', COUNT(*) FROM companies
    UNION ALL SELECT 'CONTACT_TYPES', COUNT(*) FROM contact_types
    UNION ALL SELECT 'CORPORATE_CUSTOMERS', COUNT(*) FROM corporate_customers
    UNION ALL SELECT 'COUNTRIES', COUNT(*) FROM countries
    UNION ALL SELECT 'CURRENCIES', COUNT(*) FROM currencies
    UNION ALL SELECT 'CUSTOMERS', COUNT(*) FROM customers
    UNION ALL SELECT 'CUSTOMER_ADDRESSES', COUNT(*) FROM customer_addresses
    UNION ALL SELECT 'CUSTOMER_CONTACTS', COUNT(*) FROM customer_contacts
    UNION ALL SELECT 'DISTRICTS', COUNT(*) FROM districts
    UNION ALL SELECT 'EXCHANGE_RATES', COUNT(*) FROM exchange_rates
    UNION ALL SELECT 'INDIVIDUAL_CUSTOMERS', COUNT(*) FROM individual_customers
    UNION ALL SELECT 'SECTORS', COUNT(*) FROM sectors
    UNION ALL SELECT 'TRANSACTIONS', COUNT(*) FROM transactions
    UNION ALL SELECT 'TRANSACTION_CHANNELS', COUNT(*) FROM transaction_channels
    UNION ALL SELECT 'TRANSACTION_STATUS_HISTORY', COUNT(*) FROM transaction_status_history
    UNION ALL SELECT 'TRANSACTION_TYPES', COUNT(*) FROM transaction_types
)
SELECT
    e.table_name,
    e.expected_rows,
    a.actual_rows,
    CASE
        WHEN a.actual_rows = e.expected_rows THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM expected_counts e
JOIN actual_counts a
  ON a.table_name = e.table_name
ORDER BY e.table_name;

PROMPT
PROMPT --- C. ROW-COUNT SUMMARY ---
PROMPT

WITH expected_counts AS
(
    SELECT 'ACCOUNTS' AS table_name, 21000 AS expected_rows FROM dual
    UNION ALL SELECT 'ACCOUNT_TYPES', 5 FROM dual
    UNION ALL SELECT 'BENEFICIARIES', 15644 FROM dual
    UNION ALL SELECT 'BRANCHES', 50 FROM dual
    UNION ALL SELECT 'CARDS', 7866 FROM dual
    UNION ALL SELECT 'CARD_TYPES', 5 FROM dual
    UNION ALL SELECT 'CITIES', 81 FROM dual
    UNION ALL SELECT 'COMPANIES', 1001 FROM dual
    UNION ALL SELECT 'CONTACT_TYPES', 5 FROM dual
    UNION ALL SELECT 'CORPORATE_CUSTOMERS', 1001 FROM dual
    UNION ALL SELECT 'COUNTRIES', 8 FROM dual
    UNION ALL SELECT 'CURRENCIES', 8 FROM dual
    UNION ALL SELECT 'CUSTOMERS', 10003 FROM dual
    UNION ALL SELECT 'CUSTOMER_ADDRESSES', 14293 FROM dual
    UNION ALL SELECT 'CUSTOMER_CONTACTS', 22850 FROM dual
    UNION ALL SELECT 'DISTRICTS', 973 FROM dual
    UNION ALL SELECT 'EXCHANGE_RATES', 7 FROM dual
    UNION ALL SELECT 'INDIVIDUAL_CUSTOMERS', 9002 FROM dual
    UNION ALL SELECT 'SECTORS', 14 FROM dual
    UNION ALL SELECT 'TRANSACTIONS', 200000 FROM dual
    UNION ALL SELECT 'TRANSACTION_CHANNELS', 5 FROM dual
    UNION ALL SELECT 'TRANSACTION_STATUS_HISTORY', 0 FROM dual
    UNION ALL SELECT 'TRANSACTION_TYPES', 6 FROM dual
),
actual_counts AS
(
    SELECT 'ACCOUNTS' AS table_name, COUNT(*) AS actual_rows FROM accounts
    UNION ALL SELECT 'ACCOUNT_TYPES', COUNT(*) FROM account_types
    UNION ALL SELECT 'BENEFICIARIES', COUNT(*) FROM beneficiaries
    UNION ALL SELECT 'BRANCHES', COUNT(*) FROM branches
    UNION ALL SELECT 'CARDS', COUNT(*) FROM cards
    UNION ALL SELECT 'CARD_TYPES', COUNT(*) FROM card_types
    UNION ALL SELECT 'CITIES', COUNT(*) FROM cities
    UNION ALL SELECT 'COMPANIES', COUNT(*) FROM companies
    UNION ALL SELECT 'CONTACT_TYPES', COUNT(*) FROM contact_types
    UNION ALL SELECT 'CORPORATE_CUSTOMERS', COUNT(*) FROM corporate_customers
    UNION ALL SELECT 'COUNTRIES', COUNT(*) FROM countries
    UNION ALL SELECT 'CURRENCIES', COUNT(*) FROM currencies
    UNION ALL SELECT 'CUSTOMERS', COUNT(*) FROM customers
    UNION ALL SELECT 'CUSTOMER_ADDRESSES', COUNT(*) FROM customer_addresses
    UNION ALL SELECT 'CUSTOMER_CONTACTS', COUNT(*) FROM customer_contacts
    UNION ALL SELECT 'DISTRICTS', COUNT(*) FROM districts
    UNION ALL SELECT 'EXCHANGE_RATES', COUNT(*) FROM exchange_rates
    UNION ALL SELECT 'INDIVIDUAL_CUSTOMERS', COUNT(*) FROM individual_customers
    UNION ALL SELECT 'SECTORS', COUNT(*) FROM sectors
    UNION ALL SELECT 'TRANSACTIONS', COUNT(*) FROM transactions
    UNION ALL SELECT 'TRANSACTION_CHANNELS', COUNT(*) FROM transaction_channels
    UNION ALL SELECT 'TRANSACTION_STATUS_HISTORY', COUNT(*) FROM transaction_status_history
    UNION ALL SELECT 'TRANSACTION_TYPES', COUNT(*) FROM transaction_types
)
SELECT
    'EXPECTED_IMPORTED_TABLES' AS check_name,
    23 AS expected_value,
    COUNT(*) AS actual_value,
    CASE WHEN COUNT(*) = 23 THEN 'PASS' ELSE 'FAIL' END AS result
FROM actual_counts

UNION ALL

SELECT
    'TABLES_WITH_MATCHING_ROW_COUNTS',
    23,
    COUNT(*),
    CASE WHEN COUNT(*) = 23 THEN 'PASS' ELSE 'FAIL' END
FROM expected_counts e
JOIN actual_counts a
  ON a.table_name = e.table_name
WHERE a.actual_rows = e.expected_rows

UNION ALL

SELECT
    'TOTAL_IMPORTED_ROWS',
    SUM(expected_rows),
    SUM(actual_rows),
    CASE
        WHEN SUM(actual_rows) = SUM(expected_rows) THEN 'PASS'
        ELSE 'FAIL'
    END
FROM expected_counts e
JOIN actual_counts a
  ON a.table_name = e.table_name;

PROMPT
PROMPT --- D. EXCLUDED LOG TABLE STATUS ---
PROMPT

SELECT
    table_name,
    actual_rows,
    'TARGET-LOCAL HISTORY' AS log_scope
FROM
(
    SELECT 'AUDIT_LOGS' AS table_name, COUNT(*) AS actual_rows FROM audit_logs
    UNION ALL
    SELECT 'DDL_AUDIT_LOGS', COUNT(*) FROM ddl_audit_logs
    UNION ALL
    SELECT 'ERROR_LOGS', COUNT(*) FROM error_logs
)
ORDER BY table_name;

PROMPT
PROMPT Existing rows in these tables are target-environment records.
PROMPT Their counts are informational and are not compared with source counts.
PROMPT

PROMPT
PROMPT --- E. CUSTOMER SUBTYPE VALIDATION ---
PROMPT

SELECT
    'CUSTOMER_SUBTYPE_TOTAL' AS check_name,
    (SELECT COUNT(*) FROM customers) AS expected_value,
    (SELECT COUNT(*) FROM individual_customers) +
    (SELECT COUNT(*) FROM corporate_customers) AS actual_value,
    CASE
        WHEN (SELECT COUNT(*) FROM customers) =
             (SELECT COUNT(*) FROM individual_customers) +
             (SELECT COUNT(*) FROM corporate_customers)
            THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM dual

UNION ALL

SELECT
    'INDIVIDUAL_TYPE_MAPPING',
    (SELECT COUNT(*) FROM customers WHERE customer_type = 'I'),
    (SELECT COUNT(*) FROM individual_customers),
    CASE
        WHEN (SELECT COUNT(*) FROM customers WHERE customer_type = 'I') =
             (SELECT COUNT(*) FROM individual_customers)
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dual

UNION ALL

SELECT
    'CORPORATE_TYPE_MAPPING',
    (SELECT COUNT(*) FROM customers WHERE customer_type = 'C'),
    (SELECT COUNT(*) FROM corporate_customers),
    CASE
        WHEN (SELECT COUNT(*) FROM customers WHERE customer_type = 'C') =
             (SELECT COUNT(*) FROM corporate_customers)
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM dual

UNION ALL

SELECT
    'CUSTOMERS_IN_BOTH_SUBTYPES',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM individual_customers i
JOIN corporate_customers c
  ON c.customer_id = i.customer_id;

PROMPT
PROMPT --- F. ORPHANED FOREIGN-KEY DATA CHECKS ---
PROMPT

SELECT
    'ACCOUNTS_WITHOUT_CUSTOMER' AS check_name,
    0 AS expected_value,
    COUNT(*) AS actual_value,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM accounts a
WHERE NOT EXISTS
(
    SELECT 1
    FROM customers c
    WHERE c.customer_id = a.customer_id
)

UNION ALL

SELECT
    'ACCOUNTS_WITHOUT_BRANCH',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM accounts a
WHERE NOT EXISTS
(
    SELECT 1
    FROM branches b
    WHERE b.branch_id = a.branch_id
)

UNION ALL

SELECT
    'CARDS_WITHOUT_ACCOUNT',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM cards c
WHERE NOT EXISTS
(
    SELECT 1
    FROM accounts a
    WHERE a.account_id = c.account_id
)

UNION ALL

SELECT
    'BENEFICIARIES_WITHOUT_CUSTOMER',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM beneficiaries b
WHERE NOT EXISTS
(
    SELECT 1
    FROM customers c
    WHERE c.customer_id = b.customer_id
)

UNION ALL

SELECT
    'BENEFICIARIES_WITHOUT_ACCOUNT',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM beneficiaries b
WHERE NOT EXISTS
(
    SELECT 1
    FROM accounts a
    WHERE a.account_id = b.beneficiary_account_id
)

UNION ALL

SELECT
    'TRANSACTIONS_WITHOUT_SOURCE_ACCOUNT',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM transactions t
WHERE NOT EXISTS
(
    SELECT 1
    FROM accounts a
    WHERE a.account_id = t.source_account_id
)

UNION ALL

SELECT
    'TRANSACTIONS_WITH_INVALID_TARGET',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM transactions t
WHERE t.target_account_id IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM accounts a
      WHERE a.account_id = t.target_account_id
  )

UNION ALL

SELECT
    'STATUS_HISTORY_WITHOUT_TRANSACTION',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM transaction_status_history h
WHERE NOT EXISTS
(
    SELECT 1
    FROM transactions t
    WHERE t.transaction_id = h.transaction_id
);

PROMPT
PROMPT --- G. IMPORTED BUSINESS-RULE CHECKS ---
PROMPT

SELECT
    'NEGATIVE_ACCOUNT_BALANCES' AS check_name,
    0 AS expected_value,
    COUNT(*) AS actual_value,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM accounts
WHERE balance < 0

UNION ALL

SELECT
    'NONPOSITIVE_TRANSACTION_AMOUNTS',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM transactions
WHERE amount <= 0

UNION ALL

SELECT
    'SAME_SOURCE_AND_TARGET_ACCOUNT',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM transactions
WHERE target_account_id IS NOT NULL
  AND source_account_id = target_account_id

UNION ALL

SELECT
    'INVALID_CUSTOMER_NO_FORMAT',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM customers
WHERE customer_no IS NULL
   OR NOT REGEXP_LIKE(customer_no, '^CUST[0-9]{6}$')

UNION ALL

SELECT
    'INVALID_INDIVIDUAL_NAME_CASE',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM individual_customers
WHERE first_name <>
          NLS_INITCAP(
              NLS_LOWER(first_name, 'NLS_SORT=XTURKISH'),
              'NLS_SORT=XTURKISH'
          )
   OR last_name <>
          NLS_INITCAP(
              NLS_LOWER(last_name, 'NLS_SORT=XTURKISH'),
              'NLS_SORT=XTURKISH'
          );

PROMPT
PROMPT --- H. CONSTRAINT HEALTH SUMMARY ---
PROMPT

SELECT
    CASE constraint_type
        WHEN 'P' THEN 'PRIMARY KEY'
        WHEN 'U' THEN 'UNIQUE'
        WHEN 'R' THEN 'FOREIGN KEY'
        WHEN 'C' THEN 'CHECK / NOT NULL'
        ELSE constraint_type
    END AS constraint_type,
    status,
    validated,
    COUNT(*) AS actual_value
FROM user_constraints
GROUP BY
    constraint_type,
    status,
    validated
ORDER BY
    constraint_type,
    status,
    validated;

PROMPT
PROMPT --- I. APPLICATION SEQUENCE SAFETY ---
PROMPT

WITH required_values AS
(
    SELECT
        'CARD_SEQ' AS sequence_name,
        NVL(MAX(card_id), 0) + 1 AS required_next_value
    FROM cards

    UNION ALL

    SELECT
        'SEQ_CUSTOMER_NO',
        NVL(
            MAX(
                CASE
                    WHEN REGEXP_LIKE(customer_no, '^CUST[0-9]{6}$')
                    THEN TO_NUMBER(SUBSTR(customer_no, 5))
                END
            ),
            0
        ) + 1
    FROM customers
)
SELECT
    s.sequence_name,
    s.last_number AS sequence_last_number,
    r.required_next_value,
    CASE
        WHEN s.increment_by = 1
         AND s.cycle_flag = 'N'
         AND s.last_number >= r.required_next_value
            THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM user_sequences s
JOIN required_values r
  ON r.sequence_name = s.sequence_name
WHERE s.sequence_name IN
(
    'CARD_SEQ',
    'SEQ_CUSTOMER_NO'
)
ORDER BY s.sequence_name;

PROMPT
PROMPT --- J. IDENTITY SEQUENCE SAFETY ---
PROMPT

DECLARE
    l_max_value       NUMBER;
    l_last_number     NUMBER;
    l_result          VARCHAR2(10);
BEGIN
    DBMS_OUTPUT.PUT_LINE(
        RPAD('TABLE.COLUMN', 64) ||
        RPAD('SEQUENCE', 32) ||
        LPAD('MAX_VALUE', 15) ||
        LPAD('LAST_NUMBER', 15) ||
        LPAD('RESULT', 10)
    );

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 136, '-'));

    FOR r IN
    (
        SELECT
            table_name,
            column_name,
            sequence_name
        FROM user_tab_identity_cols
        ORDER BY table_name, column_name
    )
    LOOP
        EXECUTE IMMEDIATE
            'SELECT NVL(MAX(' ||
            DBMS_ASSERT.SIMPLE_SQL_NAME(r.column_name) ||
            '), 0) FROM ' ||
            DBMS_ASSERT.SQL_OBJECT_NAME(r.table_name)
        INTO l_max_value;

        SELECT last_number
        INTO l_last_number
        FROM user_sequences
        WHERE sequence_name = r.sequence_name;

        l_result :=
            CASE
                WHEN l_last_number > l_max_value THEN 'PASS'
                ELSE 'FAIL'
            END;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.table_name || '.' || r.column_name, 64) ||
            RPAD(r.sequence_name, 32) ||
            LPAD(TO_CHAR(l_max_value), 15) ||
            LPAD(TO_CHAR(l_last_number), 15) ||
            LPAD(l_result, 10)
        );
    END LOOP;
END;
/

PROMPT
PROMPT --- K. INVALID OBJECT CHECK ---
PROMPT

SELECT
    object_type,
    object_name,
    status
FROM user_objects
WHERE status <> 'VALID'
ORDER BY object_type, object_name;

PROMPT
PROMPT --- L. FINAL IMPORT VALIDATION SUMMARY ---
PROMPT

WITH row_checks AS
(
    SELECT COUNT(*) AS failed_count
    FROM
    (
        SELECT 21000 expected_rows, COUNT(*) actual_rows FROM accounts
        UNION ALL SELECT 5, COUNT(*) FROM account_types
        UNION ALL SELECT 15644, COUNT(*) FROM beneficiaries
        UNION ALL SELECT 50, COUNT(*) FROM branches
        UNION ALL SELECT 7866, COUNT(*) FROM cards
        UNION ALL SELECT 5, COUNT(*) FROM card_types
        UNION ALL SELECT 81, COUNT(*) FROM cities
        UNION ALL SELECT 1001, COUNT(*) FROM companies
        UNION ALL SELECT 5, COUNT(*) FROM contact_types
        UNION ALL SELECT 1001, COUNT(*) FROM corporate_customers
        UNION ALL SELECT 8, COUNT(*) FROM countries
        UNION ALL SELECT 8, COUNT(*) FROM currencies
        UNION ALL SELECT 10003, COUNT(*) FROM customers
        UNION ALL SELECT 14293, COUNT(*) FROM customer_addresses
        UNION ALL SELECT 22850, COUNT(*) FROM customer_contacts
        UNION ALL SELECT 973, COUNT(*) FROM districts
        UNION ALL SELECT 7, COUNT(*) FROM exchange_rates
        UNION ALL SELECT 9002, COUNT(*) FROM individual_customers
        UNION ALL SELECT 14, COUNT(*) FROM sectors
        UNION ALL SELECT 200000, COUNT(*) FROM transactions
        UNION ALL SELECT 5, COUNT(*) FROM transaction_channels
        UNION ALL SELECT 0, COUNT(*) FROM transaction_status_history
        UNION ALL SELECT 6, COUNT(*) FROM transaction_types
    )
    WHERE expected_rows <> actual_rows
),
invalid_objects AS
(
    SELECT COUNT(*) AS invalid_count
    FROM user_objects
    WHERE status <> 'VALID'
),
disabled_constraints AS
(
    SELECT COUNT(*) AS invalid_count
    FROM user_constraints
    WHERE status <> 'ENABLED'
       OR validated <> 'VALIDATED'
),
invalid_name_case AS
(
    SELECT COUNT(*) AS invalid_count
    FROM individual_customers
    WHERE first_name <>
              NLS_INITCAP(
                  NLS_LOWER(first_name, 'NLS_SORT=XTURKISH'),
                  'NLS_SORT=XTURKISH'
              )
       OR last_name <>
              NLS_INITCAP(
                  NLS_LOWER(last_name, 'NLS_SORT=XTURKISH'),
                  'NLS_SORT=XTURKISH'
              )
)
SELECT
    'ROW_COUNT_FAILURES' AS check_name,
    0 AS expected_value,
    failed_count AS actual_value,
    CASE WHEN failed_count = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM row_checks

UNION ALL

SELECT
    'INVALID_OBJECTS',
    0,
    invalid_count,
    CASE WHEN invalid_count = 0 THEN 'PASS' ELSE 'FAIL' END
FROM invalid_objects

UNION ALL

SELECT
    'DISABLED_OR_UNVALIDATED_CONSTRAINTS',
    0,
    invalid_count,
    CASE WHEN invalid_count = 0 THEN 'PASS' ELSE 'FAIL' END
FROM disabled_constraints

UNION ALL

SELECT
    'INVALID_INDIVIDUAL_NAME_CASE',
    0,
    invalid_count,
    CASE WHEN invalid_count = 0 THEN 'PASS' ELSE 'FAIL' END
FROM invalid_name_case;

PROMPT
PROMPT ================================================================================
PROMPT DATA IMPORT POSTCHECK FINISHED
PROMPT ================================================================================
PROMPT Review every FAIL result before accepting the imported dataset.
PROMPT Identity-sequence rows must also return PASS.
PROMPT
