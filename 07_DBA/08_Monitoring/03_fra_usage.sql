/*
  Script  : 03_fra_usage.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports Fast Recovery Area usage and reclaimable space.
  Run As  : SYSDBA
  Usage   : @03_fra_usage.sql

  Notes
  -----
  - This script is read-only.
  - FRA usage reflects the current database state.
  - Reclaimable space depends on Oracle retention policies.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 420
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT FRA Monitoring Thresholds

SELECT
    80 AS warning_threshold_pct,
    90 AS critical_threshold_pct
FROM
    dual;

PROMPT
PROMPT FRA Configuration

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
        'db_recovery_file_dest_size'
    )
ORDER BY
    name;

PROMPT
PROMPT FRA Capacity And Usage

SELECT
    name AS recovery_area,
    ROUND(space_limit / 1024 / 1024, 2) AS configured_size_mb,
    ROUND(space_used / 1024 / 1024, 2) AS used_mb,
    ROUND(space_reclaimable / 1024 / 1024, 2) AS reclaimable_mb,
    ROUND(
        GREATEST(space_used - space_reclaimable, 0)
        / 1024 / 1024,
        2
    ) AS non_reclaimable_used_mb,
    ROUND(
        GREATEST(space_limit - space_used, 0)
        / 1024 / 1024,
        2
    ) AS immediately_free_mb,
    ROUND(
        GREATEST(space_limit - space_used + space_reclaimable, 0)
        / 1024 / 1024,
        2
    ) AS effective_free_mb,
    ROUND(
        space_used * 100 / NULLIF(space_limit, 0),
        2
    ) AS used_pct,
    ROUND(
        space_reclaimable * 100 / NULLIF(space_limit, 0),
        2
    ) AS reclaimable_pct,
    number_of_files
FROM
    v$recovery_file_dest;

PROMPT
PROMPT FRA Usage By File Type

SELECT
    file_type,
    ROUND(percent_space_used, 2) AS percent_space_used,
    ROUND(percent_space_reclaimable, 2) AS percent_space_reclaimable,
    number_of_files
FROM
    v$flash_recovery_area_usage
ORDER BY
    percent_space_used DESC,
    file_type;

PROMPT
PROMPT FRA File Type Usage In Megabytes

WITH recovery_area AS (
    SELECT
        space_limit
    FROM
        v$recovery_file_dest
),
usage_detail AS (
    SELECT
        file_type,
        percent_space_used,
        percent_space_reclaimable,
        number_of_files
    FROM
        v$flash_recovery_area_usage
)
SELECT
    u.file_type,
    ROUND(
        r.space_limit * u.percent_space_used / 100 / 1024 / 1024,
        2
    ) AS estimated_used_mb,
    ROUND(
        r.space_limit * u.percent_space_reclaimable / 100 / 1024 / 1024,
        2
    ) AS estimated_reclaimable_mb,
    u.number_of_files
FROM
    recovery_area r
    CROSS JOIN usage_detail u
ORDER BY
    estimated_used_mb DESC,
    u.file_type;

PROMPT
PROMPT FRA Components Requiring Review

SELECT
    file_type,
    ROUND(percent_space_used, 2) AS percent_space_used,
    ROUND(percent_space_reclaimable, 2) AS percent_space_reclaimable,
    number_of_files,
    CASE
        WHEN percent_space_used >= 50
         AND percent_space_reclaimable < 10
        THEN 'HIGH NON-RECLAIMABLE FRA CONSUMPTION'

        WHEN percent_space_used >= 50
         AND percent_space_reclaimable >= 10
        THEN 'HIGH USAGE WITH RECLAIMABLE SPACE'

        WHEN number_of_files > 0
        THEN 'INFORMATIONAL'

        ELSE 'NO FILES'
    END AS monitoring_assessment
FROM
    v$flash_recovery_area_usage
WHERE
       percent_space_used >= 50
    OR percent_space_reclaimable >= 10
ORDER BY
    percent_space_used DESC,
    file_type;

PROMPT
PROMPT FRA Alert Summary

WITH fra_state AS (
    SELECT
        name,
        space_limit,
        space_used,
        space_reclaimable,
        number_of_files,
        ROUND(
            space_used * 100 / NULLIF(space_limit, 0),
            2
        ) AS used_pct,
        ROUND(
            GREATEST(space_used - space_reclaimable, 0)
            * 100
            / NULLIF(space_limit, 0),
            2
        ) AS non_reclaimable_used_pct
    FROM
        v$recovery_file_dest
),
configuration_state AS (
    SELECT
        MAX(
            CASE
                WHEN name = 'db_recovery_file_dest'
                 AND value IS NOT NULL
                THEN 1
                ELSE 0
            END
        ) AS destination_configured,
        MAX(
            CASE
                WHEN name = 'db_recovery_file_dest_size'
                 AND TO_NUMBER(value) > 0
                THEN 1
                ELSE 0
            END
        ) AS size_configured
    FROM
        v$parameter
    WHERE
        name IN (
            'db_recovery_file_dest',
            'db_recovery_file_dest_size'
        )
)
SELECT
    CASE
        WHEN cs.destination_configured = 1
         AND cs.size_configured = 1
        THEN 'CONFIGURED'
        ELSE 'NOT CONFIGURED'
    END AS fra_configuration_state,
    NVL(fs.used_pct, 0) AS fra_used_pct,
    NVL(fs.non_reclaimable_used_pct, 0) AS non_reclaimable_used_pct,
    ROUND(
        NVL(fs.space_reclaimable, 0) / 1024 / 1024,
        2
    ) AS reclaimable_mb,
    NVL(fs.number_of_files, 0) AS number_of_files,
    CASE
        WHEN cs.destination_configured = 0
          OR cs.size_configured = 0
        THEN 'NOT CONFIGURED'

        WHEN NVL(fs.used_pct, 0) >= 90
        THEN 'CRITICAL'

        WHEN NVL(fs.used_pct, 0) >= 80
        THEN 'WARNING'

        ELSE 'HEALTHY'
    END AS fra_alert_state,
    CASE
        WHEN cs.destination_configured = 0
          OR cs.size_configured = 0
        THEN 'FRA CONFIGURATION REQUIRES REVIEW'

        WHEN NVL(fs.used_pct, 0) >= 90
        THEN 'CRITICAL FRA CAPACITY USAGE DETECTED'

        WHEN NVL(fs.used_pct, 0) >= 80
        THEN 'FRA WARNING THRESHOLD REACHED'

        WHEN NVL(fs.used_pct, 0) >= 70
         AND NVL(fs.space_reclaimable, 0) = 0
        THEN 'MONITOR FRA GROWTH - NO RECLAIMABLE SPACE'

        ELSE 'NO FRA CAPACITY ALERT'
    END AS primary_monitoring_message
FROM
    configuration_state cs
    LEFT JOIN fra_state fs
        ON 1 = 1;

PROMPT
PROMPT FRA Usage Inventory Completed
