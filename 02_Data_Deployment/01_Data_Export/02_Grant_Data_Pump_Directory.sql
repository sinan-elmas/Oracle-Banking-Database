-- ============================================================================
-- Oracle Banking Database
-- Module       : 02_Data_Deployment / 01_Data_Export
-- Script       : 02_Grant_Data_Pump_Directory.sql
-- Purpose      : Grant the BANKING_DB schema access to the existing
--                PDB-specific DATA_PUMP_DIR directory object
-- Execution    : Run as SYS in ORCLPDB1 with F5 - Run Script
-- Safety       : Grants READ and WRITE on one existing directory object
--
-- Verified environment:
--   Container       : ORCLPDB1
--   Directory name  : DATA_PUMP_DIR
--   Directory path  : /opt/oracle/admin/ORCLCDB/dpdump/
--                     5568D25A59CF0DCCE063030011AC2144
-- ============================================================================

SET PAGESIZE 200
SET LINESIZE 220
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET SQLBLANKLINES ON

WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT
PROMPT ================================================================================
PROMPT GRANT DATA PUMP DIRECTORY ACCESS
PROMPT ================================================================================
PROMPT

PROMPT --- A. CONTAINER CHECK ---
PROMPT

SELECT
    SYS_CONTEXT('USERENV', 'CON_NAME') AS container_name,
    USER AS current_user
FROM dual;

PROMPT
PROMPT --- B. VERIFIED DIRECTORY OBJECT ---
PROMPT

COLUMN directory_name FORMAT A35
COLUMN directory_path FORMAT A120

SELECT
    directory_name,
    directory_path
FROM dba_directories
WHERE directory_name = 'DATA_PUMP_DIR';

PROMPT
PROMPT --- C. GRANT DIRECTORY PRIVILEGES ---
PROMPT

GRANT READ, WRITE ON DIRECTORY data_pump_dir TO banking_db;

PROMPT
PROMPT --- D. GRANT VERIFICATION ---
PROMPT

COLUMN grantee   FORMAT A25
COLUMN privilege FORMAT A15

SELECT
    grantee,
    privilege
FROM dba_tab_privs
WHERE owner = 'SYS'
  AND table_name = 'DATA_PUMP_DIR'
  AND grantee = 'BANKING_DB'
  AND privilege IN ('READ', 'WRITE')
ORDER BY privilege;

PROMPT
PROMPT ================================================================================
PROMPT DIRECTORY ACCESS GRANT COMPLETED
PROMPT ================================================================================
PROMPT Expected verification result: READ and WRITE for BANKING_DB.
PROMPT