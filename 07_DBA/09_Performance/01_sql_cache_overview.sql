/*
  Script  : 01_sql_cache_overview.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports shared SQL area, shared pool, library cache, parsing,
            reload, invalidation, and cursor version indicators.
  Run As  : SYSDBA
  Usage   : @01_sql_cache_overview.sql

  Notes
  -----
  - This script is read-only.
  - V$SQLAREA and V$SQL metrics are cumulative while cursors remain
    in the shared SQL area.
  - Values may reset or disappear after instance restart, cursor aging,
    cursor invalidation, or shared pool flushing.
  - Oracle-maintained workload is not hidden by this overview.
  - The first 30 minutes after startup are treated as a cache warm-up period.
  - No AWR, ASH, ADDM, DBA_HIST_*, or Diagnostics Pack dependency is used.
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
PROMPT SQL Cache Metric Scope

SELECT
    'CUMULATIVE WHILE CURSOR REMAINS IN SHARED SQL AREA'
        AS metric_scope,
    TO_CHAR(i.startup_time, 'DD-MON-YYYY HH24:MI:SS')
        AS instance_startup_time,
    TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
        AS report_time,
    ROUND((SYSDATE - i.startup_time) * 1440, 2)
        AS instance_uptime_minutes,
    CASE
        WHEN (SYSDATE - i.startup_time) * 1440 < 30
        THEN 'CACHE WARM-UP PERIOD'
        ELSE 'STEADY-STATE REVIEW'
    END AS interpretation_window
FROM
    v$instance i;

PROMPT
PROMPT Shared Pool Memory Overview

WITH shared_pool_state AS (
    SELECT
        SUM(bytes) AS total_shared_pool_bytes,
        SUM(
            CASE
                WHEN name = 'free memory' THEN bytes
                ELSE 0
            END
        ) AS free_shared_pool_bytes
    FROM
        v$sgastat
    WHERE
        pool = 'shared pool'
)
SELECT
    ROUND(total_shared_pool_bytes / 1024 / 1024, 2)
        AS shared_pool_total_mb,
    ROUND(free_shared_pool_bytes / 1024 / 1024, 2)
        AS shared_pool_free_mb,
    ROUND(
        (total_shared_pool_bytes - free_shared_pool_bytes)
        / 1024 / 1024,
        2
    ) AS shared_pool_used_mb,
    ROUND(
        free_shared_pool_bytes
        * 100
        / NULLIF(total_shared_pool_bytes, 0),
        2
    ) AS shared_pool_free_pct
FROM
    shared_pool_state;

PROMPT
PROMPT Largest Shared Pool Components

SELECT *
FROM (
    SELECT
        name,
        ROUND(bytes / 1024 / 1024, 2) AS component_mb,
        ROUND(
            bytes
            * 100
            / NULLIF(SUM(bytes) OVER (), 0),
            2
        ) AS shared_pool_pct
    FROM
        v$sgastat
    WHERE
        pool = 'shared pool'
    ORDER BY
        bytes DESC,
        name
)
WHERE
    ROWNUM <= 20;

PROMPT
PROMPT Shared SQL Area Summary

SELECT
    COUNT(*) AS parent_cursor_count,
    NVL(SUM(version_count), 0) AS child_cursor_count,
    NVL(
        SUM(
            CASE
                WHEN version_count >= 20 THEN 1
                ELSE 0
            END
        ),
        0
    ) AS high_version_parent_count,
    ROUND(NVL(SUM(sharable_mem), 0) / 1024 / 1024, 2)
        AS sharable_memory_mb,
    NVL(SUM(executions), 0) AS executions,
    NVL(SUM(parse_calls), 0) AS parse_calls,
    NVL(SUM(loads), 0) AS loads,
    NVL(SUM(invalidations), 0) AS invalidations,
    NVL(SUM(users_executing), 0) AS current_users_executing
FROM
    v$sqlarea;

PROMPT
PROMPT Library Cache Namespace Statistics

SELECT
    namespace,
    gets,
    gethits,
    ROUND(gethitratio * 100, 2) AS get_hit_pct,
    pins,
    pinhits,
    ROUND(pinhitratio * 100, 2) AS pin_hit_pct,
    reloads,
    ROUND(
        reloads * 100 / NULLIF(pins, 0),
        4
    ) AS reload_to_pin_pct,
    invalidations
FROM
    v$librarycache
WHERE
       gets > 0
    OR pins > 0
    OR reloads > 0
    OR invalidations > 0
ORDER BY
    reloads DESC,
    invalidations DESC,
    namespace;

PROMPT
PROMPT Instance Parse And Cursor Statistics

WITH selected_statistics AS (
    SELECT
        name,
        value
    FROM
        v$sysstat
    WHERE
        name IN (
            'execute count',
            'parse count (total)',
            'parse count (hard)',
            'session cursor cache hits',
            'opened cursors cumulative',
            'opened cursors current'
        )
),
statistics_pivot AS (
    SELECT
        NVL(MAX(CASE WHEN name = 'execute count' THEN value END), 0)
            AS execute_count,
        NVL(MAX(CASE WHEN name = 'parse count (total)' THEN value END), 0)
            AS parse_count_total,
        NVL(MAX(CASE WHEN name = 'parse count (hard)' THEN value END), 0)
            AS parse_count_hard,
        NVL(MAX(CASE WHEN name = 'session cursor cache hits' THEN value END), 0)
            AS session_cursor_cache_hits,
        NVL(MAX(CASE WHEN name = 'opened cursors cumulative' THEN value END), 0)
            AS opened_cursors_cumulative,
        NVL(MAX(CASE WHEN name = 'opened cursors current' THEN value END), 0)
            AS opened_cursors_current
    FROM
        selected_statistics
)
SELECT
    execute_count,
    parse_count_total,
    parse_count_hard,
    ROUND(
        parse_count_hard
        * 100
        / NULLIF(parse_count_total, 0),
        2
    ) AS hard_parse_pct_of_parses,
    ROUND(
        parse_count_total
        * 100
        / NULLIF(execute_count, 0),
        2
    ) AS parse_to_execute_pct,
    session_cursor_cache_hits,
    opened_cursors_cumulative,
    opened_cursors_current
FROM
    statistics_pivot;

PROMPT
PROMPT SQL Statements With High Version Count

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        parsing_schema_name,
        module,
        action,
        version_count,
        loaded_versions,
        open_versions,
        kept_versions,
        loads,
        invalidations,
        executions,
        parse_calls,
        ROUND(sharable_mem / 1024 / 1024, 2)
            AS sharable_memory_mb,
        TO_CHAR(last_active_time, 'DD-MON-YYYY HH24:MI:SS')
            AS last_active_time,
        SUBSTR(
            REPLACE(
                REPLACE(sql_text, CHR(10), ' '),
                CHR(13),
                ' '
            ),
            1,
            500
        ) AS sql_text
    FROM
        v$sqlarea
    WHERE
        version_count >= 20
    ORDER BY
        version_count DESC,
        sharable_mem DESC,
        sql_id
)
WHERE
    ROWNUM <= 30;

PROMPT
PROMPT SQL Cache Overview Summary

WITH uptime_state AS (
    SELECT
        ROUND((SYSDATE - startup_time) * 1440, 2)
            AS uptime_minutes
    FROM
        v$instance
),
shared_pool_state AS (
    SELECT
        SUM(bytes) AS total_shared_pool_bytes,
        SUM(
            CASE
                WHEN name = 'free memory' THEN bytes
                ELSE 0
            END
        ) AS free_shared_pool_bytes
    FROM
        v$sgastat
    WHERE
        pool = 'shared pool'
),
library_cache_state AS (
    SELECT
        NVL(SUM(pins), 0) AS total_pins,
        NVL(SUM(reloads), 0) AS total_reloads,
        NVL(SUM(invalidations), 0) AS total_invalidations
    FROM
        v$librarycache
),
parse_state AS (
    SELECT
        NVL(
            MAX(
                CASE
                    WHEN name = 'parse count (total)' THEN value
                END
            ),
            0
        ) AS parse_count_total,
        NVL(
            MAX(
                CASE
                    WHEN name = 'parse count (hard)' THEN value
                END
            ),
            0
        ) AS parse_count_hard
    FROM
        v$sysstat
    WHERE
        name IN (
            'parse count (total)',
            'parse count (hard)'
        )
),
cursor_state AS (
    SELECT
        COUNT(*) AS parent_cursor_count,
        NVL(SUM(version_count), 0) AS child_cursor_count,
        NVL(
            SUM(
                CASE
                    WHEN version_count >= 20 THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS high_version_parent_count,
        NVL(SUM(invalidations), 0) AS sql_invalidations
    FROM
        v$sqlarea
),
calculated_state AS (
    SELECT
        u.uptime_minutes,
        c.parent_cursor_count,
        c.child_cursor_count,
        c.high_version_parent_count,
        c.sql_invalidations,
        ROUND(
            sp.free_shared_pool_bytes
            * 100
            / NULLIF(sp.total_shared_pool_bytes, 0),
            2
        ) AS shared_pool_free_pct,
        ROUND(
            lc.total_reloads
            * 100
            / NULLIF(lc.total_pins, 0),
            4
        ) AS library_cache_reload_pct,
        lc.total_invalidations AS library_cache_invalidations,
        ROUND(
            ps.parse_count_hard
            * 100
            / NULLIF(ps.parse_count_total, 0),
            2
        ) AS hard_parse_pct
    FROM
        uptime_state u
        CROSS JOIN shared_pool_state sp
        CROSS JOIN library_cache_state lc
        CROSS JOIN parse_state ps
        CROSS JOIN cursor_state c
)
SELECT
    uptime_minutes,
    parent_cursor_count,
    child_cursor_count,
    high_version_parent_count,
    sql_invalidations,
    shared_pool_free_pct,
    library_cache_reload_pct,
    library_cache_invalidations,
    hard_parse_pct,
    CASE
        WHEN uptime_minutes < 30
        THEN 'CACHE WARM-UP PERIOD'

        WHEN high_version_parent_count > 0
          OR library_cache_reload_pct >= 1
          OR hard_parse_pct >= 20
          OR shared_pool_free_pct < 10
        THEN 'REVIEW RECOMMENDED'

        ELSE 'HEALTHY'
    END AS sql_cache_review_state,
    CASE
        WHEN uptime_minutes < 30
        THEN 'INSTANCE UPTIME IS BELOW 30 MINUTES'

        WHEN high_version_parent_count > 0
        THEN 'HIGH VERSION COUNT SQL DETECTED'

        WHEN library_cache_reload_pct >= 1
        THEN 'LIBRARY CACHE RELOAD RATE EXCEEDS 1 PERCENT'

        WHEN hard_parse_pct >= 20
        THEN 'HARD PARSE RATE EXCEEDS 20 PERCENT'

        WHEN shared_pool_free_pct < 10
        THEN 'SHARED POOL FREE MEMORY BELOW 10 PERCENT'

        ELSE 'NO SQL CACHE REVIEW INDICATOR DETECTED'
    END AS primary_interpretation
FROM
    calculated_state;

PROMPT
PROMPT SQL Cache Overview Completed
