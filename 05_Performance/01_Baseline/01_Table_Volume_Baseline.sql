-- ============================================================================
-- Script Name : 01_Table_Volume_Baseline.sql
-- Module      : 05_Performance / 01_Baseline
-- Project     : Oracle Banking Database
-- Database    : Oracle AI Database 26ai Enterprise Edition
-- Version     : 23.26.1.0.0
-- Schema      : BANKING_DB
-- Tool        : Oracle SQL Developer
--
-- Purpose
--   Establishes a read-only table-volume baseline for the current application
--   schema before execution-plan analysis, index optimization, or SQL tuning.
--
-- Reports
--   * Optimizer row-count estimates
--   * Table block counts
--   * Base table segment sizes
--   * Optimizer statistics status and age
--   * Temporary and partitioned table attributes
--
-- Important Notes
--   * NUM_ROWS and BLOCKS are optimizer statistics, not real-time counts.
--   * TABLE_SEGMENT_MB includes the base table segment only.
--   * Index, LOB, partition, and subpartition segments are not included in
--     TABLE_SEGMENT_MB.
--   * NULL statistics indicate that optimizer statistics may not have been
--     gathered for the related table.
--
-- Safety
--   Read-only. No DDL, DML, statistics collection, or object modification.
-- ============================================================================

SET PAGESIZE 500
SET LINESIZE 180
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

COLUMN schema_name         FORMAT A20
COLUMN table_name          FORMAT A35
COLUMN estimated_rows      FORMAT 999,999,999
COLUMN estimated_blocks    FORMAT 999,999,999
COLUMN table_segment_mb    FORMAT 999,999,990.00
COLUMN last_analyzed       FORMAT A20
COLUMN statistics_age_days FORMAT 999,990.0
COLUMN stale_stats         FORMAT A11
COLUMN temporary           FORMAT A9
COLUMN partitioned         FORMAT A11

PROMPT
PROMPT ================================================================================
PROMPT TABLE VOLUME BASELINE
PROMPT ================================================================================
PROMPT

SELECT
    USER AS schema_name,
    COUNT(*) AS table_count,
    TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') AS report_time
FROM user_tables
GROUP BY
    USER;

PROMPT
PROMPT ================================================================================
PROMPT TABLE VOLUME DETAILS
PROMPT ================================================================================
PROMPT

WITH table_segment_sizes AS
(
    SELECT
        segment_name AS table_name,
        SUM(bytes) AS segment_bytes
    FROM user_segments
    WHERE segment_type = 'TABLE'
    GROUP BY
        segment_name
)
SELECT
    tab.table_name,

    stats.num_rows AS estimated_rows,
    stats.blocks AS estimated_blocks,

    ROUND(
        NVL(seg.segment_bytes, 0) / 1024 / 1024,
        2
    ) AS table_segment_mb,

    TO_CHAR(
        stats.last_analyzed,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS last_analyzed,

    CASE
        WHEN stats.last_analyzed IS NULL
            THEN NULL
        ELSE
            ROUND(SYSDATE - stats.last_analyzed, 1)
    END AS statistics_age_days,

    NVL(stats.stale_stats, 'UNKNOWN') AS stale_stats,

    tab.temporary,
    tab.partitioned

FROM user_tables tab

LEFT JOIN user_tab_statistics stats
       ON stats.table_name = tab.table_name
      AND stats.partition_name IS NULL
      AND stats.subpartition_name IS NULL

LEFT JOIN table_segment_sizes seg
       ON seg.table_name = tab.table_name

ORDER BY
    table_segment_mb DESC,
    estimated_rows DESC NULLS LAST,
    tab.table_name;

PROMPT
PROMPT ================================================================================
PROMPT BASELINE INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT NUM_ROWS and BLOCKS reflect the latest optimizer statistics.
PROMPT TABLE_SEGMENT_MB excludes indexes, LOB segments, and partition segments.
PROMPT STALE_STATS = YES indicates that Oracle considers the statistics stale.
PROMPT NULL LAST_ANALYZED values indicate missing or unavailable table statistics.
PROMPT

PROMPT End of table volume baseline report.
