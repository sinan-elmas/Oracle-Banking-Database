-- ============================================================================
-- Oracle Banking Database
-- Module       : 02_Data_Deployment / 02_Data_Import
-- Script       : 01_Data_Import_Precheck.sql
-- Purpose      : Verify that the target BANKING_DB schema is ready for the
--                23-table DATA_ONLY import
-- Execution    : Run as BANKING_DB with F5 - Run Script
-- Safety       : Read-only
--
-- Import Scope
--   Included data tables : 23
--   Excluded log tables  : 3
--
-- Important
--   The 23 included tables must be empty before import.
--   AUDIT_LOGS, DDL_AUDIT_LOGS, and ERROR_LOGS are not part of the dump set.
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 500
SET LINESIZE 240
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

WHENEVER SQLERROR EXIT SQL.SQLCODE

COLUMN current_user        FORMAT A25
COLUMN container_name      FORMAT A25
COLUMN database_name       FORMAT A20
COLUMN table_name          FORMAT A32
COLUMN import_scope        FORMAT A16
COLUMN object_status       FORMAT A12
COLUMN row_count           FORMAT 999999999
COLUMN constraint_type     FORMAT A20
COLUMN status              FORMAT A10
COLUMN validated           FORMAT A12
COLUMN sequence_name       FORMAT A30
COLUMN last_number         FORMAT 9999999999999999999999999999
COLUMN directory_name      FORMAT A35
COLUMN directory_path      FORMAT A100
COLUMN privilege           FORMAT A15
COLUMN check_name          FORMAT A44
COLUMN expected_value      FORMAT 999999999
COLUMN actual_value        FORMAT 999999999
COLUMN result              FORMAT A10

PROMPT
PROMPT ================================================================================
PROMPT DATA PUMP IMPORT PRECHECK
PROMPT ================================================================================
PROMPT

PROMPT
PROMPT --- A. TARGET DATABASE CONTEXT ---
PROMPT

SELECT
    USER AS current_user,
    SYS_CONTEXT('USERENV', 'CON_NAME') AS container_name,
    SYS_CONTEXT('USERENV', 'DB_NAME') AS database_name
FROM dual;

PROMPT
PROMPT --- B. PROJECT TABLE INVENTORY AND IMPORT SCOPE ---
PROMPT

WITH project_tables AS
(
    SELECT 'ACCOUNTS' AS table_name, 'INCLUDED' AS import_scope FROM dual
    UNION ALL SELECT 'ACCOUNT_TYPES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'AUDIT_LOGS', 'EXCLUDED' FROM dual
    UNION ALL SELECT 'BENEFICIARIES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'BRANCHES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CARDS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CARD_TYPES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CITIES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'COMPANIES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CONTACT_TYPES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CORPORATE_CUSTOMERS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'COUNTRIES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CURRENCIES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CUSTOMERS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CUSTOMER_ADDRESSES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CUSTOMER_CONTACTS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'DDL_AUDIT_LOGS', 'EXCLUDED' FROM dual
    UNION ALL SELECT 'DISTRICTS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'ERROR_LOGS', 'EXCLUDED' FROM dual
    UNION ALL SELECT 'EXCHANGE_RATES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'INDIVIDUAL_CUSTOMERS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'SECTORS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'TRANSACTIONS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'TRANSACTION_CHANNELS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'TRANSACTION_STATUS_HISTORY', 'INCLUDED' FROM dual
    UNION ALL SELECT 'TRANSACTION_TYPES', 'INCLUDED' FROM dual
)
SELECT
    p.table_name,
    p.import_scope,
    CASE
        WHEN t.table_name IS NOT NULL THEN 'FOUND'
        ELSE 'MISSING'
    END AS object_status
FROM project_tables p
LEFT JOIN user_tables t
       ON t.table_name = p.table_name
ORDER BY
    p.import_scope,
    p.table_name;

PROMPT
PROMPT --- C. ACTUAL ROW COUNTS FOR INCLUDED TABLES ---
PROMPT

DECLARE
    l_count NUMBER;
BEGIN
    FOR r IN
    (
        SELECT table_name
        FROM user_tables
        WHERE table_name IN
        (
            'ACCOUNTS',
            'ACCOUNT_TYPES',
            'BENEFICIARIES',
            'BRANCHES',
            'CARDS',
            'CARD_TYPES',
            'CITIES',
            'COMPANIES',
            'CONTACT_TYPES',
            'CORPORATE_CUSTOMERS',
            'COUNTRIES',
            'CURRENCIES',
            'CUSTOMERS',
            'CUSTOMER_ADDRESSES',
            'CUSTOMER_CONTACTS',
            'DISTRICTS',
            'EXCHANGE_RATES',
            'INDIVIDUAL_CUSTOMERS',
            'SECTORS',
            'TRANSACTIONS',
            'TRANSACTION_CHANNELS',
            'TRANSACTION_STATUS_HISTORY',
            'TRANSACTION_TYPES'
        )
        ORDER BY table_name
    )
    LOOP
        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' ||
            DBMS_ASSERT.SQL_OBJECT_NAME(r.table_name)
        INTO l_count;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.table_name, 35) ||
            TO_CHAR(l_count, 'FM999999999999')
        );
    END LOOP;
END;
/

PROMPT
PROMPT --- D. ACTUAL ROW COUNTS FOR EXCLUDED LOG TABLES ---
PROMPT

DECLARE
    l_count NUMBER;
BEGIN
    FOR r IN
    (
        SELECT table_name
        FROM user_tables
        WHERE table_name IN
        (
            'AUDIT_LOGS',
            'DDL_AUDIT_LOGS',
            'ERROR_LOGS'
        )
        ORDER BY table_name
    )
    LOOP
        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' ||
            DBMS_ASSERT.SQL_OBJECT_NAME(r.table_name)
        INTO l_count;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.table_name, 35) ||
            TO_CHAR(l_count, 'FM999999999999') ||
            '  [NOT IMPORTED FROM DUMP]'
        );
    END LOOP;
END;
/

PROMPT
PROMPT --- E. CONSTRAINT HEALTH SUMMARY ---
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
PROMPT --- F. IDENTITY COLUMN INVENTORY ---
PROMPT

SELECT
    table_name,
    column_name,
    generation_type,
    identity_options
FROM user_tab_identity_cols
ORDER BY
    table_name,
    column_name;

PROMPT
PROMPT --- G. APPLICATION SEQUENCE STATUS ---
PROMPT

SELECT
    sequence_name,
    increment_by,
    cache_size,
    cycle_flag,
    order_flag,
    last_number
FROM user_sequences
WHERE sequence_name IN
(
    'CARD_SEQ',
    'SEQ_CUSTOMER_NO'
)
ORDER BY sequence_name;

PROMPT
PROMPT --- H. AVAILABLE DIRECTORY OBJECTS ---
PROMPT

SELECT
    directory_name,
    directory_path
FROM all_directories
ORDER BY directory_name;

PROMPT
PROMPT --- I. DIRECTORY PRIVILEGES GRANTED TO CURRENT USER ---
PROMPT

SELECT
    table_name AS directory_name,
    privilege
FROM user_tab_privs
WHERE type = 'DIRECTORY'
ORDER BY
    table_name,
    privilege;

PROMPT
PROMPT --- J. IMPORT READINESS SUMMARY ---
PROMPT

WITH project_tables AS
(
    SELECT 'ACCOUNTS' AS table_name, 'INCLUDED' AS import_scope FROM dual
    UNION ALL SELECT 'ACCOUNT_TYPES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'AUDIT_LOGS', 'EXCLUDED' FROM dual
    UNION ALL SELECT 'BENEFICIARIES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'BRANCHES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CARDS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CARD_TYPES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CITIES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'COMPANIES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CONTACT_TYPES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CORPORATE_CUSTOMERS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'COUNTRIES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CURRENCIES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CUSTOMERS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CUSTOMER_ADDRESSES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'CUSTOMER_CONTACTS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'DDL_AUDIT_LOGS', 'EXCLUDED' FROM dual
    UNION ALL SELECT 'DISTRICTS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'ERROR_LOGS', 'EXCLUDED' FROM dual
    UNION ALL SELECT 'EXCHANGE_RATES', 'INCLUDED' FROM dual
    UNION ALL SELECT 'INDIVIDUAL_CUSTOMERS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'SECTORS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'TRANSACTIONS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'TRANSACTION_CHANNELS', 'INCLUDED' FROM dual
    UNION ALL SELECT 'TRANSACTION_STATUS_HISTORY', 'INCLUDED' FROM dual
    UNION ALL SELECT 'TRANSACTION_TYPES', 'INCLUDED' FROM dual
),
included_rows AS
(
    SELECT
        SUM(
            CASE
                WHEN table_name = 'ACCOUNTS' THEN
                    (SELECT COUNT(*) FROM accounts)
                WHEN table_name = 'ACCOUNT_TYPES' THEN
                    (SELECT COUNT(*) FROM account_types)
                WHEN table_name = 'BENEFICIARIES' THEN
                    (SELECT COUNT(*) FROM beneficiaries)
                WHEN table_name = 'BRANCHES' THEN
                    (SELECT COUNT(*) FROM branches)
                WHEN table_name = 'CARDS' THEN
                    (SELECT COUNT(*) FROM cards)
                WHEN table_name = 'CARD_TYPES' THEN
                    (SELECT COUNT(*) FROM card_types)
                WHEN table_name = 'CITIES' THEN
                    (SELECT COUNT(*) FROM cities)
                WHEN table_name = 'COMPANIES' THEN
                    (SELECT COUNT(*) FROM companies)
                WHEN table_name = 'CONTACT_TYPES' THEN
                    (SELECT COUNT(*) FROM contact_types)
                WHEN table_name = 'CORPORATE_CUSTOMERS' THEN
                    (SELECT COUNT(*) FROM corporate_customers)
                WHEN table_name = 'COUNTRIES' THEN
                    (SELECT COUNT(*) FROM countries)
                WHEN table_name = 'CURRENCIES' THEN
                    (SELECT COUNT(*) FROM currencies)
                WHEN table_name = 'CUSTOMERS' THEN
                    (SELECT COUNT(*) FROM customers)
                WHEN table_name = 'CUSTOMER_ADDRESSES' THEN
                    (SELECT COUNT(*) FROM customer_addresses)
                WHEN table_name = 'CUSTOMER_CONTACTS' THEN
                    (SELECT COUNT(*) FROM customer_contacts)
                WHEN table_name = 'DISTRICTS' THEN
                    (SELECT COUNT(*) FROM districts)
                WHEN table_name = 'EXCHANGE_RATES' THEN
                    (SELECT COUNT(*) FROM exchange_rates)
                WHEN table_name = 'INDIVIDUAL_CUSTOMERS' THEN
                    (SELECT COUNT(*) FROM individual_customers)
                WHEN table_name = 'SECTORS' THEN
                    (SELECT COUNT(*) FROM sectors)
                WHEN table_name = 'TRANSACTIONS' THEN
                    (SELECT COUNT(*) FROM transactions)
                WHEN table_name = 'TRANSACTION_CHANNELS' THEN
                    (SELECT COUNT(*) FROM transaction_channels)
                WHEN table_name = 'TRANSACTION_STATUS_HISTORY' THEN
                    (SELECT COUNT(*) FROM transaction_status_history)
                WHEN table_name = 'TRANSACTION_TYPES' THEN
                    (SELECT COUNT(*) FROM transaction_types)
                ELSE 0
            END
        ) AS total_rows
    FROM project_tables
    WHERE import_scope = 'INCLUDED'
)
SELECT
    'EXPECTED_PROJECT_TABLES' AS check_name,
    26 AS expected_value,
    COUNT(*) AS actual_value,
    CASE WHEN COUNT(*) = 26 THEN 'PASS' ELSE 'FAIL' END AS result
FROM user_tables t
JOIN project_tables p
  ON p.table_name = t.table_name

UNION ALL

SELECT
    'EXPECTED_INCLUDED_TABLES',
    23,
    COUNT(*),
    CASE WHEN COUNT(*) = 23 THEN 'PASS' ELSE 'FAIL' END
FROM user_tables t
JOIN project_tables p
  ON p.table_name = t.table_name
WHERE p.import_scope = 'INCLUDED'

UNION ALL

SELECT
    'EXPECTED_EXCLUDED_LOG_TABLES',
    3,
    COUNT(*),
    CASE WHEN COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END
FROM user_tables t
JOIN project_tables p
  ON p.table_name = t.table_name
WHERE p.import_scope = 'EXCLUDED'

UNION ALL

SELECT
    'INCLUDED_TABLE_ROWS_BEFORE_IMPORT',
    0,
    total_rows,
    CASE WHEN total_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM included_rows

UNION ALL

SELECT
    'VALID_APPLICATION_SEQUENCES',
    2,
    COUNT(*),
    CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END
FROM user_sequences
WHERE sequence_name IN
(
    'CARD_SEQ',
    'SEQ_CUSTOMER_NO'
)

UNION ALL

SELECT
    'DATA_PUMP_DIR_READ_WRITE',
    2,
    COUNT(*),
    CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END
FROM user_tab_privs
WHERE type = 'DIRECTORY'
  AND table_name = 'DATA_PUMP_DIR'
  AND privilege IN ('READ', 'WRITE');

PROMPT
PROMPT ================================================================================
PROMPT PRECHECK FINISHED
PROMPT ================================================================================
PROMPT Import is allowed only when INCLUDED_TABLE_ROWS_BEFORE_IMPORT = 0 and PASS.
PROMPT Send the complete Script Output before creating the import parameter file.
PROMPT
