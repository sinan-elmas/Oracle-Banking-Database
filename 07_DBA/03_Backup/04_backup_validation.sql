/*
  Script  : 04_backup_validation.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports backup validation results and block corruption information.
  Run As  : SYSDBA
  Usage   : @04_backup_validation.sql

  Notes
  -----
  - This script is read-only.
  - Validation results depend on previously executed RMAN VALIDATE operations.
  - Block corruption information reflects the current database state.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 280
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Recorded RMAN Validate Operations

SELECT
    session_recid,
    session_stamp,
    operation,
    object_type,
    status,
    output_device_type,
    ROUND(input_bytes / 1024 / 1024, 2) AS input_mb,
    ROUND(output_bytes / 1024 / 1024, 2) AS output_mb,
    mbytes_processed,
    TO_CHAR(start_time, 'DD-MON-YYYY HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'DD-MON-YYYY HH24:MI:SS') AS end_time
FROM
    v$rman_status
WHERE
    row_level = 0
    AND UPPER(operation) LIKE '%VALIDATE%'
ORDER BY
    start_time DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT RMAN Validate Operation Status Summary

WITH status_reference AS (
    SELECT 'COMPLETED' AS status, 1 AS sort_order FROM dual
    UNION ALL
    SELECT 'COMPLETED WITH WARNINGS', 2 FROM dual
    UNION ALL
    SELECT 'COMPLETED WITH ERRORS', 3 FROM dual
    UNION ALL
    SELECT 'FAILED', 4 FROM dual
    UNION ALL
    SELECT 'RUNNING', 5 FROM dual
    UNION ALL
    SELECT 'RUNNING WITH WARNINGS', 6 FROM dual
    UNION ALL
    SELECT 'RUNNING WITH ERRORS', 7 FROM dual
),
validation_summary AS (
    SELECT
        status,
        COUNT(*) AS operation_count,
        MAX(end_time) AS latest_end_time
    FROM
        v$rman_status
    WHERE
        row_level = 0
        AND UPPER(operation) LIKE '%VALIDATE%'
    GROUP BY
        status
)
SELECT
    sr.status,
    NVL(vs.operation_count, 0) AS operation_count,
    vs.latest_end_time
FROM
    status_reference sr
    LEFT JOIN validation_summary vs
        ON vs.status = sr.status
ORDER BY
    sr.sort_order;

PROMPT
PROMPT Current Database Block Corruptions

SELECT
    dbc.file#,
    REGEXP_SUBSTR(df.name, '[^/]+$') AS datafile_name,
    dbc.block#,
    dbc.blocks,
    dbc.corruption_change#,
    dbc.corruption_type
FROM
    v$database_block_corruption dbc
    LEFT JOIN v$datafile df
        ON df.file# = dbc.file#
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
ORDER BY
    cc.copy_stamp DESC,
    cc.file#,
    cc.block#;

PROMPT
PROMPT Corruption Summary

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
PROMPT Backup Validation Summary

SELECT
    CASE
        WHEN EXISTS (
            SELECT
                1
            FROM
                v$rman_status
            WHERE
                row_level = 0
                AND UPPER(operation) LIKE '%VALIDATE%'
        )
        THEN 'RECORDED'
        ELSE 'NO RECORDED VALIDATE OPERATION'
    END AS validation_history_state,
    CASE
        WHEN EXISTS (
            SELECT
                1
            FROM
                v$rman_status
            WHERE
                row_level = 0
                AND UPPER(operation) LIKE '%VALIDATE%'
                AND status <> 'COMPLETED'
        )
        THEN 'REVIEW REQUIRED'
        WHEN EXISTS (
            SELECT
                1
            FROM
                v$rman_status
            WHERE
                row_level = 0
                AND UPPER(operation) LIKE '%VALIDATE%'
        )
        THEN 'ALL RECORDED OPERATIONS COMPLETED'
        ELSE 'NOT ASSESSED'
    END AS recorded_validation_status,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM v$database_block_corruption
        )
        OR EXISTS (
            SELECT 1 FROM v$backup_corruption
        )
        OR EXISTS (
            SELECT 1 FROM v$copy_corruption
        )
        THEN 'CORRUPTION RECORDED'
        ELSE 'NO RECORDED CORRUPTION'
    END AS corruption_state
FROM
    dual;

PROMPT
PROMPT Backup Validation Inventory Completed
