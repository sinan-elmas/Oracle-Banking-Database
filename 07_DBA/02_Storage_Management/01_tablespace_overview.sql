/*
  Script  : 01_tablespace_overview.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports tablespace configuration and database default tablespaces.
  Run As  : SYSDBA
  Usage   : @01_tablespace_overview.sql

  Notes
  -----
  - This script is read-only.
  - It reports permanent, UNDO, and temporary tablespaces.
  - Configuration values reflect the current database state.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 240
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF

PROMPT
PROMPT Tablespace Configuration

SELECT
    tablespace_name,
    status,
    contents,
    ROUND(block_size / 1024, 2) AS block_size_kb,
    logging,
    force_logging,
    extent_management,
    allocation_type,
    segment_space_management,
    bigfile
FROM
    dba_tablespaces
ORDER BY
    CASE contents
        WHEN 'PERMANENT' THEN 1
        WHEN 'UNDO' THEN 2
        WHEN 'TEMPORARY' THEN 3
        ELSE 4
    END,
    tablespace_name;

PROMPT
PROMPT Default Tablespaces

SELECT
    property_name,
    property_value
FROM
    database_properties
WHERE
    property_name IN (
        'DEFAULT_PERMANENT_TABLESPACE',
        'DEFAULT_TEMP_TABLESPACE',
        'DEFAULT_TBS_TYPE'
    )
ORDER BY
    property_name;

PROMPT
PROMPT Tablespace Summary By Contents And Status

SELECT
    contents,
    status,
    COUNT(*) AS tablespace_count
FROM
    dba_tablespaces
GROUP BY
    contents,
    status
ORDER BY
    contents,
    status;

PROMPT
PROMPT Tablespace Overview Inventory Completed
