/*
  Script  : 08_controlfile_information.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports control file configuration, metadata, and record usage.
  Run As  : SYSDBA
  Usage   : @08_controlfile_information.sql

  Notes
  -----
  - This script is read-only.
  - Record section usage is based on the current control file contents.
  - Control file multiplexing should also be verified at the operating-system level.
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
PROMPT Control File Configuration

SELECT
    name,
    is_recovery_dest_file,
    status
FROM
    v$controlfile
ORDER BY
    name;

PROMPT
PROMPT Control File Record Sections

SELECT
    type,
    records_total,
    records_used,
    first_index,
    last_index
FROM
    v$controlfile_record_section
WHERE
    type IN (
        'ARCHIVED LOG',
        'BACKUP DATAFILE',
        'BACKUP PIECE',
        'BACKUP REDOLOG',
        'BACKUP SET',
        'BACKUP SPFILE',
        'DATABASE INCARNATION',
        'DATAFILE',
        'LOG HISTORY',
        'REDO LOG',
        'RMAN CONFIGURATION',
        'RMAN STATUS',
        'TABLESPACE'
    )
ORDER BY
    type;

PROMPT
PROMPT Database Identification

SELECT
    name AS database_name,
    dbid,
    created,
    resetlogs_change#,
    resetlogs_time,
    checkpoint_change#
FROM
    v$database;

PROMPT
PROMPT Current Checkpoint Information

SELECT
    thread#,
    checkpoint_change#,
    TO_CHAR(checkpoint_time,'DD-MON-YYYY HH24:MI:SS') AS checkpoint_time
FROM
    v$thread
ORDER BY
    thread#;

PROMPT
PROMPT Current Control File Metadata

SELECT
    controlfile_type,
    controlfile_created,
    controlfile_sequence#,
    controlfile_change#
FROM
    v$database;

PROMPT
PROMPT Control File Information Inventory Completed
