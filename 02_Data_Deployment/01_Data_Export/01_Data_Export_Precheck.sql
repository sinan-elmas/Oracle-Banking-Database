-- ============================================================================
-- Oracle Banking Database
-- Module       : 02_Data_Deployment / 01_Data_Export
-- Script       : 01_Data_Export_Precheck.sql
-- Purpose      : Verify the source schema, export scope, data volume,
--                Data Pump directory objects, and export prerequisites before
--                creating the DATA_ONLY export set
-- Execution    : Run as BANKING_DB with F5 - Run Script
-- Safety       : Read-only
--
-- Export Scope
--   Included data tables : 23
--   Excluded log tables  : 3
--
-- Intentionally excluded from data export:
--   AUDIT_LOGS
--   DDL_AUDIT_LOGS
--   ERROR_LOGS
--
-- These three table structures remain part of 01_Database_Design, but their
-- existing rows are not transported because they represent source-environment
-- operational history rather than reusable banking dataset content.
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
COLUMN export_scope        FORMAT A16
COLUMN scope_reason        FORMAT A70
COLUMN object_status       FORMAT A12
COLUMN num_rows            FORMAT 999999999
COLUMN blocks              FORMAT 999999999
COLUMN table_mb            FORMAT 9999990.00
COLUMN last_analyzed       FORMAT A20
COLUMN directory_name      FORMAT A35
COLUMN directory_path      FORMAT A100
COLUMN privilege           FORMAT A20
COLUMN grantor             FORMAT A25
COLUMN grantee             FORMAT A25
COLUMN object_name         FORMAT A35
COLUMN check_name          FORMAT A42
COLUMN expected_value      FORMAT 999
COLUMN actual_value        FORMAT 999999999
COLUMN result              FORMAT A10

PROMPT
PROMPT ================================================================================
PROMPT DATA PUMP EXPORT PRECHECK
PROMPT ================================================================================
PROMPT

PROMPT
PROMPT --- A. SOURCE DATABASE CONTEXT ---
PROMPT

SELECT
    USER AS current_user,
    SYS_CONTEXT('USERENV', 'CON_NAME') AS container_name,
    SYS_CONTEXT('USERENV', 'DB_NAME') AS database_name
FROM dual;

PROMPT
PROMPT --- B. PROJECT TABLE EXPORT SCOPE ---
PROMPT

WITH project_tables AS
(
    SELECT 'ACCOUNTS' AS table_name, 'INCLUDED' AS export_scope,
           'Banking dataset table' AS scope_reason FROM dual
    UNION ALL SELECT 'ACCOUNT_TYPES', 'INCLUDED', 'Reference data table' FROM dual
    UNION ALL SELECT 'AUDIT_LOGS', 'EXCLUDED', 'Source-environment application audit history' FROM dual
    UNION ALL SELECT 'BENEFICIARIES', 'INCLUDED', 'Banking dataset table' FROM dual
    UNION ALL SELECT 'BRANCHES', 'INCLUDED', 'Banking dataset table' FROM dual
    UNION ALL SELECT 'CARDS', 'INCLUDED', 'Banking dataset table' FROM dual
    UNION ALL SELECT 'CARD_TYPES', 'INCLUDED', 'Reference data table' FROM dual
    UNION ALL SELECT 'CITIES', 'INCLUDED', 'Reference data table' FROM dual
    UNION ALL SELECT 'COMPANIES', 'INCLUDED', 'Banking dataset table' FROM dual
    UNION ALL SELECT 'CONTACT_TYPES', 'INCLUDED', 'Reference data table' FROM dual
    UNION ALL SELECT 'CORPORATE_CUSTOMERS', 'INCLUDED', 'Banking dataset table' FROM dual
    UNION ALL SELECT 'COUNTRIES', 'INCLUDED', 'Reference data table' FROM dual
    UNION ALL SELECT 'CURRENCIES', 'INCLUDED', 'Reference data table' FROM dual
    UNION ALL SELECT 'CUSTOMERS', 'INCLUDED', 'Banking dataset table' FROM dual
    UNION ALL SELECT 'CUSTOMER_ADDRESSES', 'INCLUDED', 'Banking dataset table' FROM dual
    UNION ALL SELECT 'CUSTOMER_CONTACTS', 'INCLUDED', 'Banking dataset table' FROM dual
    UNION ALL SELECT 'DDL_AUDIT_LOGS', 'EXCLUDED', 'Source-environment DDL audit history' FROM dual
    UNION ALL SELECT 'DISTRICTS', 'INCLUDED', 'Reference data table' FROM dual
    UNION ALL SELECT 'ERROR_LOGS', 'EXCLUDED', 'Source-environment diagnostic error history' FROM dual
    UNION ALL SELECT 'EXCHANGE_RATES', 'INCLUDED', 'Banking dataset table' FROM dual
    UNION ALL SELECT 'INDIVIDUAL_CUSTOMERS', 'INCLUDED', 'Banking dataset table' FROM dual
    UNION ALL SELECT 'SECTORS', 'INCLUDED', 'Reference data table' FROM dual
    UNION ALL SELECT 'TRANSACTIONS', 'INCLUDED', 'Banking dataset table' FROM dual
    UNION ALL SELECT 'TRANSACTION_CHANNELS', 'INCLUDED', 'Reference data table' FROM dual
    UNION ALL SELECT 'TRANSACTION_STATUS_HISTORY', 'INCLUDED', 'Transaction business-history table' FROM dual
    UNION ALL SELECT 'TRANSACTION_TYPES', 'INCLUDED', 'Reference data table' FROM dual
)
SELECT
    p.table_name,
    p.export_scope,
    p.scope_reason,
    CASE
        WHEN t.table_name IS NOT NULL THEN 'FOUND'
        ELSE 'MISSING'
    END AS object_status
FROM project_tables p
LEFT JOIN user_tables t
       ON t.table_name = p.table_name
ORDER BY
    p.export_scope,
    p.table_name;

PROMPT
PROMPT --- C. INCLUDED TABLE STATISTICS AND ESTIMATED SEGMENT SIZE ---
PROMPT

SELECT
    t.table_name,
    t.num_rows,
    t.blocks,
    ROUND(NVL(s.bytes, 0) / 1024 / 1024, 2) AS table_mb,
    TO_CHAR(t.last_analyzed, 'DD-MON-YYYY HH24:MI:SS') AS last_analyzed
FROM user_tables t
LEFT JOIN
(
    SELECT
        segment_name,
        SUM(bytes) AS bytes
    FROM user_segments
    WHERE segment_type IN
    (
        'TABLE',
        'TABLE PARTITION',
        'TABLE SUBPARTITION'
    )
    GROUP BY segment_name
) s
  ON s.segment_name = t.table_name
WHERE t.table_name IN
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
ORDER BY t.table_name;

PROMPT
PROMPT --- D. ACTUAL ROW COUNTS FOR INCLUDED TABLES ---
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
PROMPT --- E. ACTUAL ROW COUNTS FOR EXCLUDED LOG TABLES ---
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
            '  [EXCLUDED FROM DATA EXPORT]'
        );
    END LOOP;
END;
/

PROMPT
PROMPT --- F. AVAILABLE DIRECTORY OBJECTS ---
PROMPT

SELECT
    directory_name,
    directory_path
FROM all_directories
ORDER BY directory_name;

PROMPT
PROMPT --- G. DIRECTORY OBJECT PRIVILEGES GRANTED TO CURRENT USER ---
PROMPT

SELECT
    grantor,
    grantee,
    table_name AS object_name,
    privilege
FROM user_tab_privs
WHERE type = 'DIRECTORY'
ORDER BY table_name, privilege;

PROMPT
PROMPT --- H. EXPORT INVENTORY SUMMARY ---
PROMPT

WITH project_tables AS
(
    SELECT 'ACCOUNTS' AS table_name, 'INCLUDED' AS export_scope FROM dual
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
    'EXPECTED_PROJECT_TABLES' AS check_name,
    26 AS expected_value,
    COUNT(*) AS actual_value,
    CASE WHEN COUNT(*) = 26 THEN 'PASS' ELSE 'FAIL' END AS result
FROM user_tables t
JOIN project_tables p
  ON p.table_name = t.table_name

UNION ALL

SELECT
    'EXPECTED_INCLUDED_DATA_TABLES',
    23,
    COUNT(*),
    CASE WHEN COUNT(*) = 23 THEN 'PASS' ELSE 'FAIL' END
FROM user_tables t
JOIN project_tables p
  ON p.table_name = t.table_name
WHERE p.export_scope = 'INCLUDED'

UNION ALL

SELECT
    'EXPECTED_EXCLUDED_LOG_TABLES',
    3,
    COUNT(*),
    CASE WHEN COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END
FROM user_tables t
JOIN project_tables p
  ON p.table_name = t.table_name
WHERE p.export_scope = 'EXCLUDED'

UNION ALL

SELECT
    'MISSING_PROJECT_TABLES',
    0,
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM project_tables p
WHERE NOT EXISTS
(
    SELECT 1
    FROM user_tables t
    WHERE t.table_name = p.table_name
)

UNION ALL

SELECT
    'VISIBLE_DIRECTORY_OBJECTS',
    NULL,
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN 'INFO' ELSE 'REVIEW' END
FROM all_directories

UNION ALL

SELECT
    'DIRECTORY_PRIVILEGES',
    NULL,
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN 'INFO' ELSE 'REVIEW' END
FROM user_tab_privs
WHERE type = 'DIRECTORY';

PROMPT
PROMPT ================================================================================
PROMPT PRECHECK FINISHED
PROMPT ================================================================================
PROMPT Expected export scope: 23 included data tables, 3 excluded log tables.
PROMPT Send the complete Script Output before creating the export parameter file.
PROMPT