-- ============================================================================
-- Script Name : 03_Table_Statistics_Baseline.sql
-- Module      : 05_Performance / 01_Baseline
-- Project     : Oracle Banking Database
-- Database    : Oracle AI Database 26ai Enterprise Edition
-- Version     : 23.26.1.0.0
-- Schema      : BANKING_DB
-- Tool        : Oracle SQL Developer
--
-- Purpose
--   Establishes a read-only baseline of table optimizer statistics in the
--   current application schema before execution-plan analysis or SQL tuning.
--
-- Reports
--   * Tables with missing optimizer statistics
--   * Tables with stale optimizer statistics
--   * Tables with locked optimizer statistics
--   * Statistics age, sample size, and estimated row count
--   * Global and user-entered statistics indicators
--
-- Important Notes
--   * NUM_ROWS, BLOCKS, AVG_ROW_LEN, and SAMPLE_SIZE are optimizer statistics.
--   * STALE_STATS is based on Oracle's table-modification monitoring data and
--     the applicable DBMS_STATS stale-percent preference.
--   * A statistics lock does not indicate an error; it may be intentional.
--   * This script reports table-level statistics only.
--   * Partition and subpartition statistics are outside this baseline report.
--
-- Safety
--   Read-only. No statistics are gathered, locked, unlocked, or modified.
-- ============================================================================

SET PAGESIZE 500
SET LINESIZE 260
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

COLUMN schema_name         FORMAT A20
COLUMN table_name          FORMAT A35
COLUMN estimated_rows      FORMAT 999,999,999
COLUMN sample_size         FORMAT 999,999,999
COLUMN sample_percent      FORMAT 999,990.00
COLUMN estimated_blocks    FORMAT 999,999,999
COLUMN average_row_bytes   FORMAT 999,999,999
COLUMN last_analyzed       FORMAT A20
COLUMN statistics_age_days FORMAT 999,990.0
COLUMN stale_stats         FORMAT A7
COLUMN statistics_lock     FORMAT A10
COLUMN global_stats        FORMAT A7
COLUMN user_stats          FORMAT A7
COLUMN statistics_status   FORMAT A17

PROMPT
PROMPT ================================================================================
PROMPT TABLE STATISTICS BASELINE
PROMPT ================================================================================
PROMPT

WITH table_statistics AS
(
    SELECT
        tab.table_name,
        stats.num_rows,
        stats.sample_size,
        stats.blocks,
        stats.avg_row_len,
        stats.last_analyzed,
        stats.stale_stats,
        stats.stattype_locked,
        stats.global_stats,
        stats.user_stats
    FROM user_tables tab
    LEFT JOIN user_tab_statistics stats
           ON stats.table_name = tab.table_name
          AND stats.partition_name IS NULL
          AND stats.subpartition_name IS NULL
)
SELECT
    USER AS schema_name,
    COUNT(*) AS table_count,

    SUM(
        CASE
            WHEN last_analyzed IS NULL THEN 1
            ELSE 0
        END
    ) AS missing_stats_count,

    SUM(
        CASE
            WHEN stale_stats = 'YES' THEN 1
            ELSE 0
        END
    ) AS stale_stats_count,

    SUM(
        CASE
            WHEN stattype_locked IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS locked_stats_count,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM table_statistics

GROUP BY
    USER;

PROMPT
PROMPT ================================================================================
PROMPT TABLE STATISTICS DETAILS
PROMPT ================================================================================
PROMPT

WITH table_statistics AS
(
    SELECT
        tab.table_name,
        stats.num_rows,
        stats.sample_size,
        stats.blocks,
        stats.avg_row_len,
        stats.last_analyzed,
        stats.stale_stats,
        stats.stattype_locked,
        stats.global_stats,
        stats.user_stats
    FROM user_tables tab
    LEFT JOIN user_tab_statistics stats
           ON stats.table_name = tab.table_name
          AND stats.partition_name IS NULL
          AND stats.subpartition_name IS NULL
)
SELECT
    table_name,

    num_rows AS estimated_rows,
    sample_size,

    CASE
        WHEN num_rows > 0
         AND sample_size IS NOT NULL
            THEN ROUND(
                LEAST(sample_size, num_rows)
                / num_rows
                * 100,
                2
            )
        ELSE
            NULL
    END AS sample_percent,

    blocks AS estimated_blocks,
    avg_row_len AS average_row_bytes,

    TO_CHAR(
        last_analyzed,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS last_analyzed,

    CASE
        WHEN last_analyzed IS NULL
            THEN NULL
        ELSE
            ROUND(
                SYSDATE - last_analyzed,
                1
            )
    END AS statistics_age_days,

    NVL(
        stale_stats,
        'UNKNOWN'
    ) AS stale_stats,

    NVL(
        stattype_locked,
        'NONE'
    ) AS statistics_lock,

    NVL(
        global_stats,
        'UNKNOWN'
    ) AS global_stats,

    NVL(
        user_stats,
        'UNKNOWN'
    ) AS user_stats,

    CASE
        WHEN last_analyzed IS NULL
            THEN 'MISSING STATS'
        WHEN stattype_locked IS NOT NULL
         AND stale_stats = 'YES'
            THEN 'LOCKED + STALE'
        WHEN stattype_locked IS NOT NULL
            THEN 'LOCKED'
        WHEN stale_stats = 'YES'
            THEN 'STALE'
        ELSE
            'OK'
    END AS statistics_status

FROM table_statistics

ORDER BY
    CASE
        WHEN last_analyzed IS NULL THEN 1
        WHEN stattype_locked IS NOT NULL
         AND stale_stats = 'YES' THEN 2
        WHEN stale_stats = 'YES' THEN 3
        WHEN stattype_locked IS NOT NULL THEN 4
        ELSE 5
    END,
    statistics_age_days DESC NULLS LAST,
    table_name;

PROMPT
PROMPT ================================================================================
PROMPT STATISTICS INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT MISSING STATS means LAST_ANALYZED is NULL at table level.
PROMPT STALE means Oracle considers the current optimizer statistics stale.
PROMPT LOCKED means statistics changes are restricted until explicitly unlocked.
PROMPT SAMPLE_PERCENT is derived from SAMPLE_SIZE and optimizer NUM_ROWS.
PROMPT GLOBAL_STATS and USER_STATS describe how the statistics were established.
PROMPT Statistics age alone does not prove that statistics require collection.
PROMPT

PROMPT End of table statistics baseline report.
