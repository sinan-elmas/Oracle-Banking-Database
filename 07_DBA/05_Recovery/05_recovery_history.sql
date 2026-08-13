/*
  Script  : 05_recovery_advisor.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports database recovery recommendations and recovery-related status.
  Run As  : SYSDBA
  Usage   : @05_recovery_advisor.sql

  Notes
  -----
  - This script is read-only.
  - Recommendations are based on the current database recovery metadata.
  - Results may change after backup or recovery operations.
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
PROMPT Database Incarnation History

SELECT incarnation#,status,resetlogs_change#,
       TO_CHAR(resetlogs_time,'DD-MON-YYYY HH24:MI:SS') resetlogs_time,
       prior_incarnation#
FROM v$database_incarnation
ORDER BY incarnation#;

PROMPT
PROMPT Recovery Related RMAN Operations

SELECT
    rs.session_recid,
    rs.operation,
    rs.object_type,
    rs.status,
    TO_CHAR(rs.start_time,'DD-MON-YYYY HH24:MI:SS') start_time,
    TO_CHAR(rs.end_time,'DD-MON-YYYY HH24:MI:SS') end_time
FROM v$rman_status rs
WHERE rs.row_level=1
  AND (UPPER(rs.operation) LIKE 'RESTORE%'
       OR UPPER(rs.operation) LIKE 'RECOVER%'
       OR UPPER(rs.operation)='VALIDATE')
ORDER BY rs.start_time DESC, rs.session_recid DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT Recovery Operation Summary

WITH ops AS (
SELECT operation,
COUNT(*) operation_count,
SUM(CASE WHEN status='COMPLETED' THEN 1 ELSE 0 END) completed_cnt,
SUM(CASE WHEN status<>'COMPLETED' THEN 1 ELSE 0 END) failed_cnt,
MAX(end_time) latest_end
FROM v$rman_status
WHERE row_level=1
AND (UPPER(operation) LIKE 'RESTORE%'
 OR UPPER(operation) LIKE 'RECOVER%'
 OR UPPER(operation)='VALIDATE')
GROUP BY operation)
SELECT * FROM ops ORDER BY operation;

PROMPT
PROMPT Current Recovery Environment

SELECT open_mode,log_mode,database_role,protection_mode,
       protection_level,flashback_on
FROM v$database;

PROMPT
PROMPT Recovery History Summary

WITH s AS (
SELECT
SUM(CASE WHEN UPPER(operation)='RESTORE' THEN 1 ELSE 0 END) actual_restore_ops,
SUM(CASE WHEN UPPER(operation)='RECOVER' THEN 1 ELSE 0 END) actual_recover_ops,
SUM(CASE WHEN UPPER(operation)='RESTORE VALIDATE' THEN 1 ELSE 0 END) restore_validate_ops,
SUM(CASE WHEN UPPER(operation)='RESTORE PREVIEW' THEN 1 ELSE 0 END) restore_preview_ops,
SUM(CASE WHEN UPPER(operation)='VALIDATE' THEN 1 ELSE 0 END) validate_ops,
SUM(CASE WHEN UPPER(operation)='RECOVER VALIDATE HEADER' THEN 1 ELSE 0 END) recover_validate_header_ops,
SUM(CASE WHEN status<>'COMPLETED' THEN 1 ELSE 0 END) historical_failures,
MAX(CASE WHEN UPPER(operation)='VALIDATE' THEN status END)
 KEEP (DENSE_RANK LAST ORDER BY CASE WHEN UPPER(operation)='VALIDATE' THEN start_time END NULLS FIRST) latest_validate_status,
MAX(CASE WHEN UPPER(operation)='RESTORE VALIDATE' THEN status END)
 KEEP (DENSE_RANK LAST ORDER BY CASE WHEN UPPER(operation)='RESTORE VALIDATE' THEN start_time END NULLS FIRST) latest_restore_validate_status
FROM v$rman_status
WHERE row_level=1
AND (UPPER(operation) LIKE 'RESTORE%'
 OR UPPER(operation) LIKE 'RECOVER%'
 OR UPPER(operation)='VALIDATE'))
SELECT
actual_restore_ops,
actual_recover_ops,
restore_validate_ops,
restore_preview_ops,
validate_ops,
recover_validate_header_ops,
CASE
 WHEN latest_validate_status='COMPLETED'
  AND latest_restore_validate_status='COMPLETED'
 THEN 'COMPLETED'
 ELSE 'REVIEW REQUIRED'
END latest_recovery_operation_status,
CASE
 WHEN historical_failures>0 THEN 'FAILURES RECORDED'
 ELSE 'NONE RECORDED'
END historical_failure_state
FROM s;

PROMPT
PROMPT Recovery History Inventory Completed
