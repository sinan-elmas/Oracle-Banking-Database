/*
  Script  : 02_backup_inventory.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports RMAN backup inventory and available backup pieces.
  Run As  : SYSDBA
  Usage   : @02_backup_inventory.sql

  Notes
  -----
  - This script is read-only.
  - Backup information is obtained from RMAN repository metadata.
  - Availability depends on the configured RMAN retention policy.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 280
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF

PROMPT
PROMPT Recent Available Backup Sets

WITH piece_summary AS (
    SELECT
        set_stamp,
        set_count,
        MAX(tag) AS tag,
        MAX(device_type) AS device_type,
        MAX(compressed) AS compressed,
        MAX(encrypted) AS encrypted,
        SUM(bytes) AS output_bytes,
        SUM(CASE WHEN status = 'A' THEN 1 ELSE 0 END) AS available_pieces
    FROM
        v$backup_piece
    GROUP BY
        set_stamp,
        set_count
)
SELECT
    bs.recid,
    CASE
        WHEN bs.backup_type = 'L' THEN 'ARCHIVELOG'
        WHEN bs.backup_type = 'I'
            THEN 'INCREMENTAL LEVEL ' || NVL(TO_CHAR(bs.incremental_level), '?')
        WHEN bs.backup_type = 'D'
             AND NOT EXISTS (
                 SELECT
                     1
                 FROM
                     v$backup_datafile bdf
                 WHERE
                     bdf.set_stamp = bs.set_stamp
                     AND bdf.set_count = bs.set_count
                     AND bdf.file# > 0
             )
            THEN 'CONTROLFILE/SPFILE'
        WHEN bs.backup_type = 'D' THEN 'DATAFILE FULL'
        ELSE bs.backup_type
    END AS backup_category,
    bs.incremental_level,
    bs.controlfile_included,
    bs.pieces,
    ps.device_type,
    ps.compressed,
    ps.encrypted,
    ROUND(ps.output_bytes / 1024 / 1024, 2) AS output_mb,
    ROUND(bs.elapsed_seconds, 2) AS elapsed_seconds,
    ps.tag,
    TO_CHAR(bs.completion_time, 'DD-MON-YYYY HH24:MI:SS') AS completion_time
FROM
    v$backup_set bs
    JOIN piece_summary ps
        ON ps.set_stamp = bs.set_stamp
       AND ps.set_count = bs.set_count
WHERE
    ps.available_pieces > 0
ORDER BY
    bs.completion_time DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT Recent Available Backup Pieces

SELECT
    recid,
    REGEXP_SUBSTR(handle, '[^/]+$') AS piece_name,
    CASE
        WHEN is_recovery_dest_file = 'YES' THEN 'FRA'
        ELSE 'CUSTOM LOCATION'
    END AS storage_location,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    device_type,
    compressed,
    encrypted,
    tag,
    TO_CHAR(completion_time, 'DD-MON-YYYY HH24:MI:SS') AS completion_time
FROM
    v$backup_piece
WHERE
    status = 'A'
    AND deleted = 'NO'
ORDER BY
    completion_time DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT Backup Piece Status Summary

WITH status_reference AS (
    SELECT 'A' AS status_code, 'AVAILABLE' AS piece_status, 1 AS sort_order FROM dual
    UNION ALL
    SELECT 'D', 'DELETED', 2 FROM dual
    UNION ALL
    SELECT 'X', 'EXPIRED', 3 FROM dual
),
piece_summary AS (
    SELECT
        status,
        COUNT(*) AS piece_count,
        SUM(bytes) AS recorded_bytes,
        MAX(completion_time) AS latest_completion
    FROM
        v$backup_piece
    GROUP BY
        status
)
SELECT
    sr.piece_status,
    NVL(ps.piece_count, 0) AS piece_count,
    ROUND(NVL(ps.recorded_bytes, 0) / 1024 / 1024, 2) AS recorded_size_mb,
    ps.latest_completion
FROM
    status_reference sr
    LEFT JOIN piece_summary ps
        ON ps.status = sr.status_code
ORDER BY
    sr.sort_order;

PROMPT
PROMPT Available Backup Storage Summary

SELECT
    device_type,
    CASE
        WHEN is_recovery_dest_file = 'YES' THEN 'FRA'
        ELSE 'CUSTOM LOCATION'
    END AS storage_location,
    COUNT(*) AS piece_count,
    ROUND(SUM(bytes) / 1024 / 1024, 2) AS total_size_mb,
    MIN(completion_time) AS oldest_backup,
    MAX(completion_time) AS latest_backup
FROM
    v$backup_piece
WHERE
    status = 'A'
    AND deleted = 'NO'
GROUP BY
    device_type,
    CASE
        WHEN is_recovery_dest_file = 'YES' THEN 'FRA'
        ELSE 'CUSTOM LOCATION'
    END
ORDER BY
    device_type,
    storage_location;

PROMPT
PROMPT Datafile Backup Summary

SELECT
    bdf.file#,
    REGEXP_SUBSTR(df.name, '[^/]+$') AS datafile_name,
    COUNT(*) AS backup_count,
    SUM(CASE WHEN bdf.incremental_level IS NULL THEN 1 ELSE 0 END) AS full_backups,
    SUM(CASE WHEN bdf.incremental_level = 0 THEN 1 ELSE 0 END) AS level0_backups,
    SUM(CASE WHEN bdf.incremental_level = 1 THEN 1 ELSE 0 END) AS level1_backups,
    MAX(bdf.completion_time) AS latest_backup
FROM
    v$backup_datafile bdf
    JOIN v$datafile df
        ON df.file# = bdf.file#
WHERE
    bdf.file# > 0
GROUP BY
    bdf.file#,
    REGEXP_SUBSTR(df.name, '[^/]+$')
ORDER BY
    bdf.file#;

PROMPT
PROMPT Control File And SPFILE Backup Summary

SELECT
    'CONTROLFILE' AS backup_content,
    COUNT(*) AS backup_count,
    MAX(completion_time) AS latest_backup
FROM
    v$backup_datafile
WHERE
    file# = 0
UNION ALL
SELECT
    'SPFILE' AS backup_content,
    COUNT(*) AS backup_count,
    MAX(completion_time) AS latest_backup
FROM
    v$backup_spfile
ORDER BY
    backup_content;

PROMPT
PROMPT Backup Category Summary

WITH backup_categories AS (
    SELECT
        bs.set_stamp,
        bs.set_count,
        bs.completion_time,
        CASE
            WHEN bs.backup_type = 'L' THEN 'ARCHIVELOG'
            WHEN bs.backup_type = 'I'
                THEN 'INCREMENTAL LEVEL ' || NVL(TO_CHAR(bs.incremental_level), '?')
            WHEN bs.backup_type = 'D'
                 AND NOT EXISTS (
                     SELECT
                         1
                     FROM
                         v$backup_datafile bdf
                     WHERE
                         bdf.set_stamp = bs.set_stamp
                         AND bdf.set_count = bs.set_count
                         AND bdf.file# > 0
                 )
                THEN 'CONTROLFILE/SPFILE'
            WHEN bs.backup_type = 'D' THEN 'DATAFILE FULL'
            ELSE bs.backup_type
        END AS backup_category
    FROM
        v$backup_set bs
)
SELECT
    backup_category,
    COUNT(*) AS backup_set_count,
    MAX(completion_time) AS latest_backup
FROM
    backup_categories
GROUP BY
    backup_category
ORDER BY
    backup_category;

PROMPT
PROMPT Backup Inventory Completed
