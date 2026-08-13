/*
  Script  : 02_tablespace_usage.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports current tablespace utilization and available capacity.
  Run As  : SYSDBA
  Usage   : @02_tablespace_usage.sql

  Notes
  -----
  - This script is read-only.
  - Usage percentages reflect the current allocation.
  - Capacity values may change due to AUTOEXTEND settings.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 440
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Tablespace Monitoring Thresholds

SELECT
    80 AS warning_threshold_pct,
    90 AS critical_threshold_pct
FROM
    dual;

PROMPT
PROMPT Tablespace Capacity Overview

WITH
file_rows AS (
    SELECT
        tablespace_name,
        bytes,
        autoextensible,
        GREATEST(NVL(maxbytes, bytes), bytes) AS maxbytes
    FROM
        dba_data_files

    UNION ALL

    SELECT
        tablespace_name,
        bytes,
        autoextensible,
        GREATEST(NVL(maxbytes, bytes), bytes) AS maxbytes
    FROM
        dba_temp_files
),
file_state AS (
    SELECT
        tablespace_name,
        COUNT(*) AS file_count,
        SUM(bytes) AS allocated_bytes,
        SUM(
            CASE
                WHEN autoextensible = 'YES' THEN maxbytes
                ELSE bytes
            END
        ) AS effective_max_bytes,
        SUM(CASE WHEN autoextensible = 'YES' THEN 1 ELSE 0 END)
            AS autoextend_file_count
    FROM
        file_rows
    GROUP BY
        tablespace_name
),
permanent_free_state AS (
    SELECT
        tablespace_name,
        SUM(bytes) AS free_bytes
    FROM
        dba_free_space
    GROUP BY
        tablespace_name
),
temporary_space_state AS (
    SELECT
        tablespace_name,
        MAX(tablespace_size) AS tablespace_size_bytes,
        MAX(allocated_space) AS allocated_space_bytes,
        MAX(free_space) AS free_space_bytes
    FROM
        dba_temp_free_space
    GROUP BY
        tablespace_name
),
metric_state AS (
    SELECT
        m.tablespace_name,
        m.used_space * t.block_size AS metric_used_bytes,
        m.tablespace_size * t.block_size AS metric_capacity_bytes,
        m.used_percent AS metric_used_pct
    FROM
        dba_tablespace_usage_metrics m
        JOIN dba_tablespaces t
            ON t.tablespace_name = m.tablespace_name
),
capacity_state AS (
    SELECT
        t.tablespace_name,
        t.contents,
        t.status,
        t.bigfile,
        NVL(fs.file_count, 0) AS file_count,
        NVL(fs.allocated_bytes, 0) AS allocated_bytes,
        NVL(fs.effective_max_bytes, fs.allocated_bytes) AS effective_max_bytes,
        NVL(fs.autoextend_file_count, 0) AS autoextend_file_count,
        CASE
            WHEN ms.tablespace_name IS NOT NULL
            THEN ms.metric_used_bytes

            WHEN t.contents = 'TEMPORARY'
            THEN GREATEST(
                     NVL(ts.tablespace_size_bytes, fs.allocated_bytes)
                     - NVL(ts.free_space_bytes, 0),
                     0
                 )

            ELSE GREATEST(
                     NVL(fs.allocated_bytes, 0)
                     - NVL(pf.free_bytes, 0),
                     0
                 )
        END AS used_bytes,
        CASE
            WHEN ms.tablespace_name IS NOT NULL
            THEN ms.metric_capacity_bytes

            WHEN t.contents = 'TEMPORARY'
            THEN NVL(
                     fs.effective_max_bytes,
                     ts.tablespace_size_bytes
                 )

            ELSE NVL(
                     fs.effective_max_bytes,
                     fs.allocated_bytes
                 )
        END AS alert_capacity_bytes,
        CASE
            WHEN ms.tablespace_name IS NOT NULL
            THEN ROUND(ms.metric_used_pct, 2)

            WHEN t.contents = 'TEMPORARY'
            THEN ROUND(
                     GREATEST(
                         NVL(ts.tablespace_size_bytes, fs.allocated_bytes)
                         - NVL(ts.free_space_bytes, 0),
                         0
                     )
                     * 100
                     / NULLIF(
                           NVL(
                               fs.effective_max_bytes,
                               ts.tablespace_size_bytes
                           ),
                           0
                       ),
                     2
                 )

            ELSE ROUND(
                     GREATEST(
                         NVL(fs.allocated_bytes, 0)
                         - NVL(pf.free_bytes, 0),
                         0
                     )
                     * 100
                     / NULLIF(
                           NVL(
                               fs.effective_max_bytes,
                               fs.allocated_bytes
                           ),
                           0
                       ),
                     2
                 )
        END AS used_pct,
        CASE
            WHEN ms.tablespace_name IS NOT NULL
            THEN 'ORACLE METRIC'
            ELSE 'CALCULATED FALLBACK'
        END AS usage_source
    FROM
        dba_tablespaces t
        LEFT JOIN file_state fs
            ON fs.tablespace_name = t.tablespace_name
        LEFT JOIN permanent_free_state pf
            ON pf.tablespace_name = t.tablespace_name
        LEFT JOIN temporary_space_state ts
            ON ts.tablespace_name = t.tablespace_name
        LEFT JOIN metric_state ms
            ON ms.tablespace_name = t.tablespace_name
)
SELECT
    tablespace_name,
    contents,
    status,
    bigfile,
    file_count,
    ROUND(allocated_bytes / 1024 / 1024, 2) AS allocated_mb,
    ROUND(effective_max_bytes / 1024 / 1024, 2) AS effective_max_mb,
    ROUND(alert_capacity_bytes / 1024 / 1024, 2) AS alert_capacity_mb,
    ROUND(used_bytes / 1024 / 1024, 2) AS used_mb,
    ROUND(
        GREATEST(alert_capacity_bytes - used_bytes, 0)
        / 1024 / 1024,
        2
    ) AS available_mb,
    NVL(used_pct, 0) AS used_pct,
    autoextend_file_count,
    usage_source,
    CASE
        WHEN status <> 'ONLINE' THEN 'STATUS REVIEW'
        WHEN NVL(used_pct, 0) >= 90 THEN 'CRITICAL'
        WHEN NVL(used_pct, 0) >= 80 THEN 'WARNING'
        ELSE 'NORMAL'
    END AS alert_level
FROM
    capacity_state
ORDER BY
    NVL(used_pct, 0) DESC,
    tablespace_name;

PROMPT
PROMPT Tablespaces At Warning Or Critical Level

WITH
file_rows AS (
    SELECT
        tablespace_name,
        bytes,
        autoextensible,
        GREATEST(NVL(maxbytes, bytes), bytes) AS maxbytes
    FROM
        dba_data_files

    UNION ALL

    SELECT
        tablespace_name,
        bytes,
        autoextensible,
        GREATEST(NVL(maxbytes, bytes), bytes) AS maxbytes
    FROM
        dba_temp_files
),
file_state AS (
    SELECT
        tablespace_name,
        SUM(bytes) AS allocated_bytes,
        SUM(
            CASE
                WHEN autoextensible = 'YES' THEN maxbytes
                ELSE bytes
            END
        ) AS effective_max_bytes
    FROM
        file_rows
    GROUP BY
        tablespace_name
),
permanent_free_state AS (
    SELECT
        tablespace_name,
        SUM(bytes) AS free_bytes
    FROM
        dba_free_space
    GROUP BY
        tablespace_name
),
temporary_space_state AS (
    SELECT
        tablespace_name,
        MAX(tablespace_size) AS tablespace_size_bytes,
        MAX(free_space) AS free_space_bytes
    FROM
        dba_temp_free_space
    GROUP BY
        tablespace_name
),
metric_state AS (
    SELECT
        m.tablespace_name,
        m.used_space * t.block_size AS metric_used_bytes,
        m.tablespace_size * t.block_size AS metric_capacity_bytes,
        m.used_percent AS metric_used_pct
    FROM
        dba_tablespace_usage_metrics m
        JOIN dba_tablespaces t
            ON t.tablespace_name = m.tablespace_name
),
capacity_state AS (
    SELECT
        t.tablespace_name,
        t.contents,
        t.status,
        CASE
            WHEN ms.tablespace_name IS NOT NULL
            THEN ms.metric_used_bytes
            WHEN t.contents = 'TEMPORARY'
            THEN GREATEST(
                     NVL(ts.tablespace_size_bytes, fs.allocated_bytes)
                     - NVL(ts.free_space_bytes, 0),
                     0
                 )
            ELSE GREATEST(
                     NVL(fs.allocated_bytes, 0)
                     - NVL(pf.free_bytes, 0),
                     0
                 )
        END AS used_bytes,
        CASE
            WHEN ms.tablespace_name IS NOT NULL
            THEN ms.metric_capacity_bytes
            ELSE NVL(fs.effective_max_bytes, fs.allocated_bytes)
        END AS capacity_bytes,
        CASE
            WHEN ms.tablespace_name IS NOT NULL
            THEN ROUND(ms.metric_used_pct, 2)
            WHEN t.contents = 'TEMPORARY'
            THEN ROUND(
                     GREATEST(
                         NVL(ts.tablespace_size_bytes, fs.allocated_bytes)
                         - NVL(ts.free_space_bytes, 0),
                         0
                     )
                     * 100
                     / NULLIF(
                           NVL(fs.effective_max_bytes, ts.tablespace_size_bytes),
                           0
                       ),
                     2
                 )
            ELSE ROUND(
                     GREATEST(
                         NVL(fs.allocated_bytes, 0)
                         - NVL(pf.free_bytes, 0),
                         0
                     )
                     * 100
                     / NULLIF(
                           NVL(fs.effective_max_bytes, fs.allocated_bytes),
                           0
                       ),
                     2
                 )
        END AS used_pct,
        CASE
            WHEN ms.tablespace_name IS NOT NULL
            THEN 'ORACLE METRIC'
            ELSE 'CALCULATED FALLBACK'
        END AS usage_source
    FROM
        dba_tablespaces t
        LEFT JOIN file_state fs
            ON fs.tablespace_name = t.tablespace_name
        LEFT JOIN permanent_free_state pf
            ON pf.tablespace_name = t.tablespace_name
        LEFT JOIN temporary_space_state ts
            ON ts.tablespace_name = t.tablespace_name
        LEFT JOIN metric_state ms
            ON ms.tablespace_name = t.tablespace_name
)
SELECT
    tablespace_name,
    contents,
    status,
    ROUND(capacity_bytes / 1024 / 1024, 2) AS capacity_mb,
    ROUND(used_bytes / 1024 / 1024, 2) AS used_mb,
    ROUND(
        GREATEST(capacity_bytes - used_bytes, 0)
        / 1024 / 1024,
        2
    ) AS available_mb,
    used_pct,
    usage_source,
    CASE
        WHEN used_pct >= 90
        THEN 'CRITICAL - CAPACITY ACTION REQUIRED'
        ELSE 'WARNING - MONITOR GROWTH'
    END AS maintenance_assessment
FROM
    capacity_state
WHERE
    used_pct >= 80
ORDER BY
    used_pct DESC,
    tablespace_name;

PROMPT
PROMPT Tablespaces Requiring Status Review

SELECT
    tablespace_name,
    contents,
    status,
    logging,
    force_logging,
    extent_management,
    segment_space_management,
    bigfile,
    CASE
        WHEN status = 'OFFLINE'
        THEN 'OFFLINE - CONFIRM INTENT'
        WHEN status = 'READ ONLY'
        THEN 'READ ONLY - CONFIRM INTENT'
        ELSE 'REVIEW REQUIRED'
    END AS maintenance_assessment
FROM
    dba_tablespaces
WHERE
    status <> 'ONLINE'
ORDER BY
    tablespace_name;

PROMPT
PROMPT Autoextend Coverage By Tablespace

WITH files AS (
    SELECT
        tablespace_name,
        autoextensible,
        bytes,
        GREATEST(NVL(maxbytes, bytes), bytes) AS maxbytes
    FROM
        dba_data_files

    UNION ALL

    SELECT
        tablespace_name,
        autoextensible,
        bytes,
        GREATEST(NVL(maxbytes, bytes), bytes) AS maxbytes
    FROM
        dba_temp_files
)
SELECT
    t.tablespace_name,
    t.contents,
    COUNT(f.tablespace_name) AS file_count,
    NVL(
        SUM(
            CASE
                WHEN f.autoextensible = 'YES' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS autoextend_enabled_files,
    NVL(
        SUM(
            CASE
                WHEN f.autoextensible = 'NO' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS autoextend_disabled_files,
    ROUND(NVL(SUM(f.bytes), 0) / 1024 / 1024, 2) AS allocated_mb,
    ROUND(
        NVL(
            SUM(
                CASE
                    WHEN f.autoextensible = 'YES' THEN f.maxbytes
                    ELSE f.bytes
                END
            ),
            0
        ) / 1024 / 1024,
        2
    ) AS effective_max_mb,
    CASE
        WHEN COUNT(f.tablespace_name) = 0
        THEN 'NO FILE RECORD'

        WHEN SUM(
                 CASE
                     WHEN f.autoextensible = 'YES' THEN 1
                     ELSE 0
                 END
             ) = COUNT(f.tablespace_name)
        THEN 'ALL FILES AUTOEXTEND'

        WHEN SUM(
                 CASE
                     WHEN f.autoextensible = 'YES' THEN 1
                     ELSE 0
                 END
             ) = 0
        THEN 'AUTOEXTEND DISABLED'

        ELSE 'MIXED AUTOEXTEND STATE'
    END AS autoextend_state
FROM
    dba_tablespaces t
    LEFT JOIN files f
        ON f.tablespace_name = t.tablespace_name
GROUP BY
    t.tablespace_name,
    t.contents
ORDER BY
    t.tablespace_name;

PROMPT
PROMPT Tablespace Alert Summary

WITH
file_rows AS (
    SELECT
        tablespace_name,
        bytes,
        autoextensible,
        GREATEST(NVL(maxbytes, bytes), bytes) AS maxbytes
    FROM
        dba_data_files

    UNION ALL

    SELECT
        tablespace_name,
        bytes,
        autoextensible,
        GREATEST(NVL(maxbytes, bytes), bytes) AS maxbytes
    FROM
        dba_temp_files
),
file_state AS (
    SELECT
        tablespace_name,
        SUM(bytes) AS allocated_bytes,
        SUM(
            CASE
                WHEN autoextensible = 'YES' THEN maxbytes
                ELSE bytes
            END
        ) AS effective_max_bytes
    FROM
        file_rows
    GROUP BY
        tablespace_name
),
permanent_free_state AS (
    SELECT
        tablespace_name,
        SUM(bytes) AS free_bytes
    FROM
        dba_free_space
    GROUP BY
        tablespace_name
),
temporary_space_state AS (
    SELECT
        tablespace_name,
        MAX(tablespace_size) AS tablespace_size_bytes,
        MAX(free_space) AS free_space_bytes
    FROM
        dba_temp_free_space
    GROUP BY
        tablespace_name
),
metric_state AS (
    SELECT
        m.tablespace_name,
        m.used_percent AS metric_used_pct
    FROM
        dba_tablespace_usage_metrics m
),
capacity_state AS (
    SELECT
        t.tablespace_name,
        t.status,
        CASE
            WHEN ms.tablespace_name IS NOT NULL
            THEN ROUND(ms.metric_used_pct, 2)

            WHEN t.contents = 'TEMPORARY'
            THEN ROUND(
                     GREATEST(
                         NVL(ts.tablespace_size_bytes, fs.allocated_bytes)
                         - NVL(ts.free_space_bytes, 0),
                         0
                     )
                     * 100
                     / NULLIF(
                           NVL(fs.effective_max_bytes, ts.tablespace_size_bytes),
                           0
                       ),
                     2
                 )

            ELSE ROUND(
                     GREATEST(
                         NVL(fs.allocated_bytes, 0)
                         - NVL(pf.free_bytes, 0),
                         0
                     )
                     * 100
                     / NULLIF(
                           NVL(fs.effective_max_bytes, fs.allocated_bytes),
                           0
                       ),
                     2
                 )
        END AS used_pct
    FROM
        dba_tablespaces t
        LEFT JOIN file_state fs
            ON fs.tablespace_name = t.tablespace_name
        LEFT JOIN permanent_free_state pf
            ON pf.tablespace_name = t.tablespace_name
        LEFT JOIN temporary_space_state ts
            ON ts.tablespace_name = t.tablespace_name
        LEFT JOIN metric_state ms
            ON ms.tablespace_name = t.tablespace_name
),
alert_state AS (
    SELECT
        COUNT(*) AS monitored_tablespace_count,
        NVL(
            SUM(
                CASE
                    WHEN NVL(used_pct, 0) >= 90 THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS critical_tablespace_count,
        NVL(
            SUM(
                CASE
                    WHEN NVL(used_pct, 0) >= 80
                     AND NVL(used_pct, 0) < 90
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS warning_tablespace_count,
        NVL(
            SUM(
                CASE
                    WHEN status <> 'ONLINE' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS non_online_tablespace_count,
        NVL(MAX(NVL(used_pct, 0)), 0) AS highest_used_pct
    FROM
        capacity_state
)
SELECT
    monitored_tablespace_count,
    critical_tablespace_count,
    warning_tablespace_count,
    non_online_tablespace_count,
    highest_used_pct,
    CASE
        WHEN critical_tablespace_count > 0
        THEN 'CRITICAL'

        WHEN warning_tablespace_count > 0
          OR non_online_tablespace_count > 0
        THEN 'REVIEW REQUIRED'

        ELSE 'HEALTHY'
    END AS tablespace_alert_state
FROM
    alert_state;

PROMPT
PROMPT Tablespace Alert Inventory Completed
