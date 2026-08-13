/*
  Script  : 04_undo_management.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports UNDO configuration, extent usage, and active transactions.
  Run As  : SYSDBA
  Usage   : @04_undo_management.sql

  Notes
  -----
  - This script is read-only.
  - UNDO extent status represents the current database state.
  - Active transaction results may change between executions.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 260
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF

PROMPT
PROMPT UNDO Configuration

SELECT
    name,
    display_value,
    isdefault,
    issys_modifiable
FROM
    v$parameter
WHERE
    name IN (
        'undo_management',
        'undo_tablespace',
        'undo_retention'
    )
ORDER BY
    CASE name
        WHEN 'undo_management' THEN 1
        WHEN 'undo_tablespace' THEN 2
        WHEN 'undo_retention' THEN 3
        ELSE 4
    END;

PROMPT
PROMPT UNDO Tablespace Inventory

SELECT
    ts.tablespace_name,
    ts.status,
    ts.retention,
    ts.extent_management,
    ts.allocation_type,
    ts.segment_space_management,
    COUNT(df.file_id) AS datafile_count,
    ROUND(SUM(df.bytes) / 1024 / 1024, 2) AS allocated_mb,
    SUM(
        CASE
            WHEN df.autoextensible = 'YES' THEN 1
            ELSE 0
        END
    ) AS autoextend_files
FROM
    dba_tablespaces ts
    LEFT JOIN dba_data_files df
        ON df.tablespace_name = ts.tablespace_name
WHERE
    ts.contents = 'UNDO'
GROUP BY
    ts.tablespace_name,
    ts.status,
    ts.retention,
    ts.extent_management,
    ts.allocation_type,
    ts.segment_space_management
ORDER BY
    ts.tablespace_name;

PROMPT
PROMPT UNDO Extent Status Summary

SELECT
    tablespace_name,
    status,
    COUNT(*) AS extent_count,
    ROUND(SUM(bytes) / 1024 / 1024, 2) AS size_mb
FROM
    dba_undo_extents
GROUP BY
    tablespace_name,
    status
ORDER BY
    tablespace_name,
    CASE status
        WHEN 'ACTIVE' THEN 1
        WHEN 'UNEXPIRED' THEN 2
        WHEN 'EXPIRED' THEN 3
        ELSE 4
    END;

PROMPT
PROMPT UNDO Tablespace Usage Summary

SELECT
    tablespace_name,
    ROUND(SUM(CASE WHEN status = 'ACTIVE' THEN bytes ELSE 0 END) / 1024 / 1024, 2) AS active_mb,
    ROUND(SUM(CASE WHEN status = 'UNEXPIRED' THEN bytes ELSE 0 END) / 1024 / 1024, 2) AS unexpired_mb,
    ROUND(SUM(CASE WHEN status = 'EXPIRED' THEN bytes ELSE 0 END) / 1024 / 1024, 2) AS expired_mb,
    ROUND(SUM(bytes) / 1024 / 1024, 2) AS total_undo_extent_mb
FROM
    dba_undo_extents
GROUP BY
    tablespace_name
ORDER BY
    tablespace_name;

PROMPT
PROMPT Active Transactions

SELECT
    s.sid,
    s.serial#,
    s.username,
    s.status AS session_status,
    t.start_time,
    t.used_ublk AS undo_blocks,
    t.used_urec AS undo_records,
    t.status AS transaction_status,
    s.sql_id,
    s.machine,
    s.program
FROM
    v$transaction t
    JOIN v$session s
        ON s.saddr = t.ses_addr
ORDER BY
    t.used_ublk DESC,
    s.sid;

PROMPT
PROMPT UNDO Management Inventory Completed
