/*
  Script  : 03_job_history.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports historical Data Pump job information available in the database.
  Run As  : SYSDBA
  Usage   : @03_job_history.sql

  Notes
  -----
  - This script is read-only.
  - Oracle does not permanently retain a complete Data Pump execution history.
  - Reported information depends on available repository metadata.
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
PROMPT Data Pump Master Tables

SELECT
    owner,
    object_name,
    object_type,
    status,
    created,
    last_ddl_time
FROM
    dba_objects
WHERE
       object_type = 'TABLE'
   AND object_name LIKE 'SYS\_EXPORT\_%' ESCAPE '\'
    OR object_name LIKE 'SYS\_IMPORT\_%' ESCAPE '\'
ORDER BY
    created DESC,
    owner,
    object_name;

PROMPT
PROMPT Recent Data Pump Jobs

SELECT
    owner_name,
    job_name,
    operation,
    job_mode,
    state,
    degree,
    attached_sessions,
    datapump_sessions
FROM
    dba_datapump_jobs
ORDER BY
    owner_name,
    job_name;

PROMPT
PROMPT Data Pump History Summary

WITH h AS (
SELECT
SUM(CASE WHEN job_name LIKE 'SYS_EXPORT%' THEN 1 ELSE 0 END) export_jobs,
SUM(CASE WHEN job_name LIKE 'SYS_IMPORT%' THEN 1 ELSE 0 END) import_jobs,
COUNT(*) total_jobs
FROM dba_datapump_jobs
),
m AS (
SELECT COUNT(*) master_tables
FROM dba_objects
WHERE object_type='TABLE'
AND (object_name LIKE 'SYS\_EXPORT\_%' ESCAPE '\'
OR object_name LIKE 'SYS\_IMPORT\_%' ESCAPE '\')
)
SELECT
h.total_jobs,
NVL(h.export_jobs,0) export_jobs,
NVL(h.import_jobs,0) import_jobs,
m.master_tables,
CASE
 WHEN h.total_jobs=0 THEN 'NO RECORDED JOB'
 ELSE 'JOB HISTORY AVAILABLE'
END AS datapump_history_state
FROM h CROSS JOIN m;

PROMPT
PROMPT Data Pump Job History Inventory Completed
