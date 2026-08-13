/*
  Script  : 06_registry_components.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports database registry components and SQL patch inventory.
  Run As  : SYSDBA
  Usage   : @06_registry_components.sql

  Notes
  -----
  - This script is read-only.
  - Registry and SQL patch information reflects the current database state.
  - Component status should be reviewed after patching or upgrade operations.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 220
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF

PROMPT
PROMPT Registry Component Summary

SELECT
    comp_id,
    comp_name,
    version,
    status,
    schema
FROM
    dba_registry
ORDER BY
    comp_name;

PROMPT
PROMPT Invalid Registry Components

SELECT
    comp_id,
    comp_name,
    version,
    status
FROM
    dba_registry
WHERE
    status NOT IN ('VALID', 'OPTION OFF')
ORDER BY
    comp_name;

PROMPT
PROMPT Registry SQL Patch Inventory

SELECT
    patch_id,
    patch_type,
    action,
    status,
    TO_CHAR(action_time, 'DD-MON-YYYY HH24:MI:SS') AS action_time,
    source_version,
    target_version,
    description
FROM
    dba_registry_sqlpatch
ORDER BY
    action_time DESC;

PROMPT
PROMPT Installed Registry Count

SELECT
    status,
    COUNT(*) AS component_count
FROM
    dba_registry
GROUP BY
    status
ORDER BY
    status;

PROMPT
PROMPT Registry Components Inventory Completed
