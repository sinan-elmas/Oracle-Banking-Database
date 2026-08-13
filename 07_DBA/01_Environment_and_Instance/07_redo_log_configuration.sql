/*
  Script  : 07_redo_log_configuration.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports redo log groups, members, and archive configuration.
  Run As  : SYSDBA
  Usage   : @07_redo_log_configuration.sql

  Notes
  -----
  - This script is read-only.
  - Redo log and archive status reflects the current instance state.
  - Configuration changes must be evaluated separately before implementation.
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
PROMPT Database Log Mode

SELECT
    name AS database_name,
    log_mode,
    open_mode,
    force_logging,
    flashback_on
FROM v$database;

PROMPT
PROMPT Redo Log Groups

SELECT
    l.group#,
    l.thread#,
    ROUND(l.bytes/1024/1024,2) AS size_mb,
    l.members,
    l.archived,
    l.status,
    lf.type
FROM v$log l
JOIN v$logfile lf
  ON l.group#=lf.group#
ORDER BY l.group#;

PROMPT
PROMPT Redo Log Members

SELECT
    group#,
    member,
    status,
    is_recovery_dest_file
FROM v$logfile
ORDER BY group#, member;

PROMPT
PROMPT Archive Destinations

SELECT
    dest_id,
    status,
    destination,
    target,
    schedule,
    valid_now
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;

PROMPT
PROMPT Archive Log Summary

SELECT
    COUNT(*) AS archived_logs,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence,
    MIN(first_time) AS oldest_log,
    MAX(completion_time) AS latest_completion
FROM
    v$archived_log
WHERE
    archived = 'YES'
    AND deleted = 'NO'
    AND name IS NOT NULL
    AND resetlogs_id = (
        SELECT
            resetlogs_id
        FROM
            v$database_incarnation
        WHERE
            status = 'CURRENT'
    );

PROMPT
PROMPT Redo Log Configuration Inventory Completed
