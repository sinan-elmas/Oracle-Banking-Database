/*
  Script  : 04_block_corruption_report.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports Oracle block corruption records detected by the database.
  Run As  : SYSDBA
  Usage   : @04_block_corruption_report.sql

  Notes
  -----
  - This script is read-only.
  - Results depend on corruption information currently recorded by Oracle.
  - No validation or repair operation is executed.
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
PROMPT Current Database Block Corruptions

SELECT
    dbc.file#,
    t.name AS tablespace_name,
    REGEXP_SUBSTR(df.name, '[^/]+$') AS datafile_name,
    dbc.block#,
    dbc.blocks,
    dbc.corruption_change#,
    dbc.corruption_type
FROM
    v$database_block_corruption dbc
    LEFT JOIN v$datafile df
        ON df.file# = dbc.file#
    LEFT JOIN v$tablespace t
        ON t.ts# = df.ts#
ORDER BY
    dbc.file#,
    dbc.block#;

PROMPT
PROMPT Backup Set Block Corruptions

SELECT
    bc.recid,
    bc.set_stamp,
    bc.set_count,
    bc.piece#,
    bc.file#,
    t.name AS tablespace_name,
    REGEXP_SUBSTR(df.name, '[^/]+$') AS datafile_name,
    bc.block#,
    bc.blocks,
    bc.corruption_change#,
    bc.marked_corrupt,
    bc.corruption_type
FROM
    v$backup_corruption bc
    LEFT JOIN v$datafile df
        ON df.file# = bc.file#
    LEFT JOIN v$tablespace t
        ON t.ts# = df.ts#
ORDER BY
    bc.set_stamp DESC,
    bc.set_count DESC,
    bc.file#,
    bc.block#;

PROMPT
PROMPT Datafile Copy Block Corruptions

SELECT
    cc.recid,
    cc.copy_recid,
    cc.copy_stamp,
    cc.file#,
    t.name AS tablespace_name,
    REGEXP_SUBSTR(df.name, '[^/]+$') AS datafile_name,
    cc.block#,
    cc.blocks,
    cc.corruption_change#,
    cc.marked_corrupt,
    cc.corruption_type
FROM
    v$copy_corruption cc
    LEFT JOIN v$datafile df
        ON df.file# = cc.file#
    LEFT JOIN v$tablespace t
        ON t.ts# = df.ts#
ORDER BY
    cc.copy_stamp DESC,
    cc.file#,
    cc.block#;

PROMPT
PROMPT Corruption Summary By Source

SELECT
    corruption_source,
    corrupt_ranges,
    corrupt_blocks
FROM (
    SELECT
        'CURRENT DATABASE' AS corruption_source,
        COUNT(*) AS corrupt_ranges,
        NVL(SUM(blocks), 0) AS corrupt_blocks,
        1 AS sort_order
    FROM
        v$database_block_corruption
    UNION ALL
    SELECT
        'BACKUP SET' AS corruption_source,
        COUNT(*) AS corrupt_ranges,
        NVL(SUM(blocks), 0) AS corrupt_blocks,
        2 AS sort_order
    FROM
        v$backup_corruption
    UNION ALL
    SELECT
        'DATAFILE COPY' AS corruption_source,
        COUNT(*) AS corrupt_ranges,
        NVL(SUM(blocks), 0) AS corrupt_blocks,
        3 AS sort_order
    FROM
        v$copy_corruption
)
ORDER BY
    sort_order;

PROMPT
PROMPT Current Database Corruption Summary By Datafile

WITH corruption_by_file AS (
    SELECT
        dbc.file#,
        COUNT(*) AS corrupt_ranges,
        SUM(dbc.blocks) AS corrupt_blocks,
        MIN(dbc.block#) AS first_corrupt_block,
        MAX(dbc.block# + dbc.blocks - 1) AS last_corrupt_block
    FROM
        v$database_block_corruption dbc
    GROUP BY
        dbc.file#
)
SELECT
    cbf.file#,
    t.name AS tablespace_name,
    REGEXP_SUBSTR(df.name, '[^/]+$') AS datafile_name,
    cbf.corrupt_ranges,
    cbf.corrupt_blocks,
    cbf.first_corrupt_block,
    cbf.last_corrupt_block
FROM
    corruption_by_file cbf
    LEFT JOIN v$datafile df
        ON df.file# = cbf.file#
    LEFT JOIN v$tablespace t
        ON t.ts# = df.ts#
ORDER BY
    cbf.file#;

PROMPT
PROMPT Block Corruption Status Summary

WITH corruption_state AS (
    SELECT
        (SELECT COUNT(*) FROM v$database_block_corruption) AS current_database_ranges,
        (SELECT NVL(SUM(blocks), 0) FROM v$database_block_corruption) AS current_database_blocks,
        (SELECT COUNT(*) FROM v$backup_corruption) AS backup_set_ranges,
        (SELECT NVL(SUM(blocks), 0) FROM v$backup_corruption) AS backup_set_blocks,
        (SELECT COUNT(*) FROM v$copy_corruption) AS datafile_copy_ranges,
        (SELECT NVL(SUM(blocks), 0) FROM v$copy_corruption) AS datafile_copy_blocks
    FROM
        dual
)
SELECT
    current_database_ranges,
    current_database_blocks,
    backup_set_ranges,
    backup_set_blocks,
    datafile_copy_ranges,
    datafile_copy_blocks,
    CASE
        WHEN current_database_ranges > 0 THEN 'IMMEDIATE ACTION REQUIRED'
        WHEN backup_set_ranges > 0 OR datafile_copy_ranges > 0 THEN 'BACKUP REVIEW REQUIRED'
        ELSE 'NO RECORDED CORRUPTION'
    END AS corruption_status
FROM
    corruption_state;

PROMPT
PROMPT Block Corruption Report Completed
