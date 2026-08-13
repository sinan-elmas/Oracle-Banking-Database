/*
  Script  : 01_backup_readiness.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports the database backup readiness and backup-related configuration.
  Run As  : SYSDBA
  Usage   : @01_backup_readiness.sql

  Notes
  -----
  - This script is read-only.
  - It reports ARCHIVELOG mode, FORCE LOGGING, FRA configuration,
    and other backup prerequisites.
  - Results represent the current database configuration.
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
PROMPT Database Backup Readiness

SELECT
    d.name AS database_name,
    d.open_mode,
    d.log_mode,
    d.force_logging,
    d.flashback_on,
    i.archiver,
    i.status AS instance_status,
    i.database_status
FROM
    v$database d
    CROSS JOIN v$instance i;

PROMPT
PROMPT Fast Recovery Area Configuration

SELECT
    name AS recovery_area,
    ROUND(space_limit / 1024 / 1024, 2) AS configured_size_mb,
    ROUND(space_used / 1024 / 1024, 2) AS used_mb,
    ROUND(space_reclaimable / 1024 / 1024, 2) AS reclaimable_mb,
    ROUND((space_limit - space_used) / 1024 / 1024, 2) AS free_mb,
    ROUND(space_used / NULLIF(space_limit, 0) * 100, 2) AS used_pct,
    number_of_files
FROM
    v$recovery_file_dest;

PROMPT
PROMPT Recovery Destination Parameters

SELECT
    name,
    display_value,
    isdefault,
    issys_modifiable
FROM
    v$parameter
WHERE
    name IN (
        'db_recovery_file_dest',
        'db_recovery_file_dest_size',
        'log_archive_dest_1',
        'log_archive_format'
    )
ORDER BY
    CASE name
        WHEN 'db_recovery_file_dest' THEN 1
        WHEN 'db_recovery_file_dest_size' THEN 2
        WHEN 'log_archive_dest_1' THEN 3
        WHEN 'log_archive_format' THEN 4
        ELSE 5
    END;

PROMPT
PROMPT Block Change Tracking

SELECT
    status,
    filename,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM
    v$block_change_tracking;

PROMPT
PROMPT Explicit RMAN Configuration Records

SELECT
    name,
    value
FROM
    v$rman_configuration
ORDER BY
    name;

PROMPT
PROMPT Control File And SPFILE Readiness

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

PROMPT
PROMPT Backup Readiness Summary

SELECT
    CASE
        WHEN d.log_mode = 'ARCHIVELOG' THEN 'READY'
        ELSE 'NOT READY'
    END AS archivelog_readiness,
    CASE
        WHEN d.force_logging = 'YES' THEN 'ENABLED'
        ELSE 'DISABLED'
    END AS force_logging_status,
    CASE
        WHEN r.name IS NOT NULL
         AND r.space_limit > 0
        THEN 'CONFIGURED'
        ELSE 'NOT CONFIGURED'
    END AS fra_status,
    CASE
        WHEN b.status = 'ENABLED' THEN 'ENABLED'
        ELSE 'DISABLED'
    END AS block_change_tracking_status,
    CASE
        WHEN EXISTS (
            SELECT
                1
            FROM
                v$rman_configuration rc
            WHERE
                UPPER(rc.name) LIKE '%CONTROLFILE AUTOBACKUP%'
                AND UPPER(rc.value) LIKE '%ON%'
        )
        THEN 'EXPLICITLY ENABLED'
        WHEN EXISTS (
            SELECT
                1
            FROM
                v$rman_configuration rc
            WHERE
                UPPER(rc.name) LIKE '%CONTROLFILE AUTOBACKUP%'
                AND UPPER(rc.value) LIKE '%OFF%'
        )
        THEN 'EXPLICITLY DISABLED'
        ELSE 'DEFAULT OR NOT RECORDED - VERIFY WITH RMAN SHOW ALL'
    END AS controlfile_autobackup_state
FROM
    v$database d
    LEFT JOIN v$recovery_file_dest r
        ON 1 = 1
    CROSS JOIN v$block_change_tracking b;

PROMPT
PROMPT Backup Readiness Inventory Completed
