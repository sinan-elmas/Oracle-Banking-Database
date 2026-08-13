/*
  Script  : 01_restore_readiness.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports database readiness for restore and recovery operations.
  Run As  : SYSDBA
  Usage   : @01_restore_readiness.sql

  Notes
  -----
  - This script is read-only.
  - It reports configuration required before database restore operations.
  - Results reflect the current database configuration.
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
PROMPT Database Restore State

SELECT
    d.name AS database_name,
    d.open_mode,
    d.log_mode,
    d.database_role,
    i.status AS instance_status,
    i.database_status
FROM
    v$database d
    CROSS JOIN v$instance i;

PROMPT
PROMPT Parameter File And Control File Readiness

SELECT
    CASE
        WHEN value IS NOT NULL THEN 'SPFILE'
        ELSE 'PFILE'
    END AS parameter_file_type,
    value AS spfile_location
FROM
    v$parameter
WHERE
    name = 'spfile';

SELECT
    COUNT(*) AS control_file_count
FROM
    v$controlfile;

SELECT
    name AS control_file_name,
    NVL(status, 'NORMAL') AS status,
    is_recovery_dest_file
FROM
    v$controlfile
ORDER BY
    name;

PROMPT
PROMPT Control File Autobackup State

SELECT
    CASE
        WHEN EXISTS (
            SELECT
                1
            FROM
                v$rman_configuration
            WHERE
                UPPER(name) LIKE '%CONTROLFILE AUTOBACKUP%'
                AND UPPER(value) LIKE '%ON%'
        )
        THEN 'EXPLICITLY ENABLED'
        WHEN EXISTS (
            SELECT
                1
            FROM
                v$rman_configuration
            WHERE
                UPPER(name) LIKE '%CONTROLFILE AUTOBACKUP%'
                AND UPPER(value) LIKE '%OFF%'
        )
        THEN 'EXPLICITLY DISABLED'
        ELSE 'DEFAULT OR NOT RECORDED - VERIFY WITH RMAN SHOW ALL'
    END AS controlfile_autobackup_state
FROM
    dual;

PROMPT
PROMPT Available Restore Assets

WITH available_sets AS (
    SELECT DISTINCT
        bs.set_stamp,
        bs.set_count,
        bs.backup_type,
        bs.incremental_level,
        bs.completion_time
    FROM
        v$backup_set bs
    WHERE
        EXISTS (
            SELECT
                1
            FROM
                v$backup_piece bp
            WHERE
                bp.set_stamp = bs.set_stamp
                AND bp.set_count = bs.set_count
                AND bp.status = 'A'
                AND bp.deleted = 'NO'
        )
)
SELECT
    'INCREMENTAL LEVEL 0' AS restore_asset,
    COUNT(*) AS available_count,
    MAX(bdf.completion_time) AS latest_available_backup
FROM
    v$backup_datafile bdf
WHERE
    bdf.file# > 0
    AND bdf.incremental_level = 0
    AND EXISTS (
        SELECT
            1
        FROM
            available_sets s
        WHERE
            s.set_stamp = bdf.set_stamp
            AND s.set_count = bdf.set_count
    )
UNION ALL
SELECT
    'INCREMENTAL LEVEL 1',
    COUNT(*),
    MAX(bdf.completion_time)
FROM
    v$backup_datafile bdf
WHERE
    bdf.file# > 0
    AND bdf.incremental_level = 1
    AND EXISTS (
        SELECT
            1
        FROM
            available_sets s
        WHERE
            s.set_stamp = bdf.set_stamp
            AND s.set_count = bdf.set_count
    )
UNION ALL
SELECT
    'CONTROLFILE',
    COUNT(*),
    MAX(bdf.completion_time)
FROM
    v$backup_datafile bdf
WHERE
    bdf.file# = 0
    AND EXISTS (
        SELECT
            1
        FROM
            available_sets s
        WHERE
            s.set_stamp = bdf.set_stamp
            AND s.set_count = bdf.set_count
    )
UNION ALL
SELECT
    'SPFILE',
    COUNT(*),
    MAX(bs.completion_time)
FROM
    v$backup_spfile bs
WHERE
    EXISTS (
        SELECT
            1
        FROM
            available_sets s
        WHERE
            s.set_stamp = bs.set_stamp
            AND s.set_count = bs.set_count
    )
UNION ALL
SELECT
    'ARCHIVELOG BACKUP SET',
    COUNT(*),
    MAX(s.completion_time)
FROM
    available_sets s
WHERE
    s.backup_type = 'L';

PROMPT
PROMPT Current Database Incarnation

SELECT
    incarnation#,
    status,
    resetlogs_change#,
    resetlogs_time
FROM
    v$database_incarnation
WHERE
    status = 'CURRENT';

PROMPT
PROMPT Restore Readiness Summary

WITH restore_assets AS (
    SELECT
        SUM(
            CASE
                WHEN bdf.file# > 0
                 AND bdf.incremental_level = 0
                THEN 1
                ELSE 0
            END
        ) AS database_backup_records,
        SUM(
            CASE
                WHEN bdf.file# = 0
                THEN 1
                ELSE 0
            END
        ) AS controlfile_backup_records
    FROM
        v$backup_datafile bdf
    WHERE
        EXISTS (
            SELECT
                1
            FROM
                v$backup_piece bp
            WHERE
                bp.set_stamp = bdf.set_stamp
                AND bp.set_count = bdf.set_count
                AND bp.status = 'A'
                AND bp.deleted = 'NO'
        )
),
spfile_assets AS (
    SELECT
        COUNT(*) AS spfile_backup_records
    FROM
        v$backup_spfile bs
    WHERE
        EXISTS (
            SELECT
                1
            FROM
                v$backup_piece bp
            WHERE
                bp.set_stamp = bs.set_stamp
                AND bp.set_count = bs.set_count
                AND bp.status = 'A'
                AND bp.deleted = 'NO'
        )
),
archivelog_assets AS (
    SELECT
        COUNT(DISTINCT bs.recid) AS archivelog_backup_sets
    FROM
        v$backup_set bs
    WHERE
        bs.backup_type = 'L'
        AND EXISTS (
            SELECT
                1
            FROM
                v$backup_piece bp
            WHERE
                bp.set_stamp = bs.set_stamp
                AND bp.set_count = bs.set_count
                AND bp.status = 'A'
                AND bp.deleted = 'NO'
        )
)
SELECT
    CASE
        WHEN d.log_mode = 'ARCHIVELOG' THEN 'READY'
        ELSE 'LIMITED'
    END AS recovery_mode_state,
    CASE
        WHEN ra.database_backup_records > 0 THEN 'AVAILABLE'
        ELSE 'NOT AVAILABLE'
    END AS database_backup_state,
    CASE
        WHEN ra.controlfile_backup_records > 0 THEN 'AVAILABLE'
        ELSE 'NOT AVAILABLE'
    END AS controlfile_backup_state,
    CASE
        WHEN sa.spfile_backup_records > 0 THEN 'AVAILABLE'
        ELSE 'NOT AVAILABLE'
    END AS spfile_backup_state,
    CASE
        WHEN aa.archivelog_backup_sets > 0 THEN 'AVAILABLE'
        ELSE 'NOT AVAILABLE'
    END AS archivelog_backup_state
FROM
    v$database d
    CROSS JOIN restore_assets ra
    CROSS JOIN spfile_assets sa
    CROSS JOIN archivelog_assets aa;

PROMPT
PROMPT Restore Readiness Inventory Completed
