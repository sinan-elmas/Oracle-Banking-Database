/*
  Script  : 01_directory_objects.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports Oracle DIRECTORY objects and Data Pump directory privileges.
  Run As  : SYSDBA
  Usage   : @01_directory_objects.sql

  Notes
  -----
  - This script is read-only.
  - DIRECTORY objects are database objects, not operating-system directories.
  - Privileges reflect the current database configuration.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 340
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Data Pump DIRECTORY Objects

SELECT
    owner,
    directory_name,
    directory_path
FROM
    dba_directories
ORDER BY
    owner,
    directory_name;

PROMPT
PROMPT DIRECTORY Object Privileges

SELECT
    owner,
    table_name AS directory_name,
    grantee,
    privilege,
    grantable
FROM
    dba_tab_privs
WHERE
    type = 'DIRECTORY'
ORDER BY
    owner,
    table_name,
    grantee,
    privilege;

PROMPT
PROMPT Data Pump Related Parameters

SELECT
    name,
    display_value
FROM
    v$parameter
WHERE
    name = 'parallel_max_servers'
ORDER BY
    name;

PROMPT
PROMPT DIRECTORY Summary

WITH directory_summary AS (
    SELECT
        COUNT(*) AS directory_count,
        SUM(
            CASE
                WHEN directory_name = 'DATA_PUMP_DIR' THEN 1
                ELSE 0
            END
        ) AS default_datapump_directory_count
    FROM
        dba_directories
),
privilege_summary AS (
    SELECT
        COUNT(*) AS privilege_count,
        COUNT(DISTINCT grantee) AS grantee_count
    FROM
        dba_tab_privs
    WHERE
        type = 'DIRECTORY'
)
SELECT
    ds.directory_count,
    ds.default_datapump_directory_count,
    ps.privilege_count,
    ps.grantee_count,
    CASE
        WHEN ds.default_datapump_directory_count > 0 THEN 'AVAILABLE'
        ELSE 'NOT CONFIGURED'
    END AS datapump_directory_state
FROM
    directory_summary ds
    CROSS JOIN privilege_summary ps;

PROMPT
PROMPT DIRECTORY Inventory Completed
