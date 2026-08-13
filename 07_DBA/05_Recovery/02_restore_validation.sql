/*
  Script  : 02_restore_validation.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports RMAN restore validation results and backup availability.
  Run As  : SYSDBA
  Usage   : @02_restore_validation.sql

  Notes
  -----
  - This script is read-only.
  - Validation information depends on previously executed RMAN validation operations.
  - Results reflect the RMAN repository at execution time.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 320
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Recent RMAN Validation And Restore Check Operations

SELECT
    rs.session_recid,
    rs.session_stamp,
    rs.operation,
    rs.object_type,
    rs.status,
    ROUND(rs.input_bytes / 1024 / 1024, 2) AS input_mb,
    ROUND(rs.output_bytes / 1024 / 1024, 2) AS output_mb,
    rs.mbytes_processed,
    ROUND((rs.end_time - rs.start_time) * 86400, 2) AS elapsed_seconds,
    TO_CHAR(rs.start_time, 'DD-MON-YYYY HH24:MI:SS') AS start_time,
    TO_CHAR(rs.end_time, 'DD-MON-YYYY HH24:MI:SS') AS end_time
FROM
    v$rman_status rs
WHERE
    rs.row_level = 1
    AND UPPER(rs.operation) IN (
        'VALIDATE',
        'RESTORE VALIDATE',
        'RESTORE PREVIEW',
        'RECOVER VALIDATE HEADER'
    )
ORDER BY
    rs.start_time DESC,
    rs.session_recid DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT Validation Operation Status Summary

WITH operation_reference AS (
    SELECT 'VALIDATE' AS operation, 1 AS sort_order FROM dual
    UNION ALL
    SELECT 'RESTORE VALIDATE', 2 FROM dual
    UNION ALL
    SELECT 'RESTORE PREVIEW', 3 FROM dual
    UNION ALL
    SELECT 'RECOVER VALIDATE HEADER', 4 FROM dual
),
operation_summary AS (
    SELECT
        UPPER(rs.operation) AS operation,
        COUNT(*) AS operation_count,
        SUM(CASE WHEN rs.status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_count,
        SUM(CASE WHEN rs.status <> 'COMPLETED' THEN 1 ELSE 0 END) AS non_successful_count,
        MAX(rs.end_time) AS latest_end_time
    FROM
        v$rman_status rs
    WHERE
        rs.row_level = 1
        AND UPPER(rs.operation) IN (
            'VALIDATE',
            'RESTORE VALIDATE',
            'RESTORE PREVIEW',
            'RECOVER VALIDATE HEADER'
        )
    GROUP BY
        UPPER(rs.operation)
)
SELECT
    r.operation,
    NVL(s.operation_count, 0) AS operation_count,
    NVL(s.completed_count, 0) AS completed_count,
    NVL(s.non_successful_count, 0) AS non_successful_count,
    s.latest_end_time
FROM
    operation_reference r
    LEFT JOIN operation_summary s
        ON s.operation = r.operation
ORDER BY
    r.sort_order;

PROMPT
PROMPT Recent Non Successful Validation Operations

SELECT
    rs.session_recid,
    rs.operation,
    rs.object_type,
    rs.status,
    TO_CHAR(rs.start_time, 'DD-MON-YYYY HH24:MI:SS') AS start_time,
    TO_CHAR(rs.end_time, 'DD-MON-YYYY HH24:MI:SS') AS end_time
FROM
    v$rman_status rs
WHERE
    rs.row_level = 1
    AND UPPER(rs.operation) IN (
        'VALIDATE',
        'RESTORE VALIDATE',
        'RESTORE PREVIEW',
        'RECOVER VALIDATE HEADER'
    )
    AND rs.status <> 'COMPLETED'
ORDER BY
    rs.start_time DESC,
    rs.session_recid DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT Latest Validation Operation By Type

SELECT
    rs.operation,
    MAX(
        CASE
            WHEN rs.status = 'COMPLETED' THEN rs.end_time
        END
    ) AS latest_successful_operation,
    MAX(
        CASE
            WHEN rs.status <> 'COMPLETED' THEN rs.end_time
        END
    ) AS latest_non_successful_operation
FROM
    v$rman_status rs
WHERE
    rs.row_level = 1
    AND UPPER(rs.operation) IN (
        'VALIDATE',
        'RESTORE VALIDATE',
        'RESTORE PREVIEW',
        'RECOVER VALIDATE HEADER'
    )
GROUP BY
    rs.operation
ORDER BY
    rs.operation;

PROMPT
PROMPT Current Corruption State

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
PROMPT Restore Validation Summary

WITH validation_history AS (
    SELECT
        MAX(
            CASE
                WHEN UPPER(rs.operation) = 'VALIDATE'
                THEN rs.status
            END
        ) KEEP (
            DENSE_RANK LAST
            ORDER BY
                CASE
                    WHEN UPPER(rs.operation) = 'VALIDATE'
                    THEN rs.start_time
                END NULLS FIRST,
                CASE
                    WHEN UPPER(rs.operation) = 'VALIDATE'
                    THEN rs.session_recid
                END NULLS FIRST
        ) AS latest_validate_status,
        MAX(
            CASE
                WHEN UPPER(rs.operation) = 'RESTORE VALIDATE'
                THEN rs.status
            END
        ) KEEP (
            DENSE_RANK LAST
            ORDER BY
                CASE
                    WHEN UPPER(rs.operation) = 'RESTORE VALIDATE'
                    THEN rs.start_time
                END NULLS FIRST,
                CASE
                    WHEN UPPER(rs.operation) = 'RESTORE VALIDATE'
                    THEN rs.session_recid
                END NULLS FIRST
        ) AS latest_restore_validate_status,
        MAX(
            CASE
                WHEN UPPER(rs.operation) = 'RESTORE PREVIEW'
                THEN rs.status
            END
        ) KEEP (
            DENSE_RANK LAST
            ORDER BY
                CASE
                    WHEN UPPER(rs.operation) = 'RESTORE PREVIEW'
                    THEN rs.start_time
                END NULLS FIRST,
                CASE
                    WHEN UPPER(rs.operation) = 'RESTORE PREVIEW'
                    THEN rs.session_recid
                END NULLS FIRST
        ) AS latest_restore_preview_status,
        SUM(
            CASE
                WHEN rs.status <> 'COMPLETED' THEN 1
                ELSE 0
            END
        ) AS historical_failure_count
    FROM
        v$rman_status rs
    WHERE
        rs.row_level = 1
        AND UPPER(rs.operation) IN (
            'VALIDATE',
            'RESTORE VALIDATE',
            'RESTORE PREVIEW',
            'RECOVER VALIDATE HEADER'
        )
),
corruption_state AS (
    SELECT
        (SELECT COUNT(*) FROM v$database_block_corruption)
        + (SELECT COUNT(*) FROM v$backup_corruption)
        + (SELECT COUNT(*) FROM v$copy_corruption)
        AS corruption_count
    FROM
        dual
)
SELECT
    NVL(vh.latest_validate_status, 'NOT RECORDED') AS latest_validate_status,
    NVL(vh.latest_restore_validate_status, 'NOT RECORDED') AS latest_restore_validate_status,
    NVL(vh.latest_restore_preview_status, 'NOT RECORDED') AS latest_restore_preview_status,
    CASE
        WHEN vh.latest_validate_status = 'COMPLETED'
         AND vh.latest_restore_validate_status = 'COMPLETED'
        THEN 'COMPLETED'
        WHEN vh.latest_validate_status IS NULL
          OR vh.latest_restore_validate_status IS NULL
        THEN 'NOT ASSESSED'
        ELSE 'REVIEW REQUIRED'
    END AS current_validation_state,
    CASE
        WHEN NVL(vh.historical_failure_count, 0) > 0
        THEN 'FAILURES RECORDED'
        ELSE 'NONE RECORDED'
    END AS historical_failure_state,
    CASE
        WHEN cs.corruption_count > 0
        THEN 'CORRUPTION RECORDED'
        ELSE 'NO RECORDED CORRUPTION'
    END AS corruption_state
FROM
    validation_history vh
    CROSS JOIN corruption_state cs;

PROMPT
PROMPT Restore Validation Inventory Completed
