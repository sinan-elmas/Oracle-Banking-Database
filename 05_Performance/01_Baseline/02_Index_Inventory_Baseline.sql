-- ============================================================================
-- Script Name : 02_Index_Inventory_Baseline.sql
-- Module      : 05_Performance / 01_Baseline
-- Project     : Oracle Banking Database
-- Database    : Oracle AI Database 26ai Enterprise Edition
-- Version     : 23.26.1.0.0
-- Schema      : BANKING_DB
-- Tool        : Oracle SQL Developer
--
-- Purpose
--   Establishes a read-only inventory of indexes in the current application
--   schema before index optimization or SQL tuning work is performed.
--
-- Reports
--   * Total index count and allocated index space
--   * Index type, uniqueness, visibility, status, and partitioning
--   * Indexed columns and column order
--   * Primary-key and unique-constraint association
--   * Optimizer statistics and index segment size
--
-- Important Notes
--   * INDEX_COLUMNS lists columns in their defined index order.
--   * Function-based indexes are identified through INDEX_TYPE.
--   * System-generated column names may appear for function-based indexes.
--   * INDEX_SEGMENT_MB includes index, index partition, and index subpartition
--     segments associated with the index name.
--   * NUM_ROWS, DISTINCT_KEYS, LEAF_BLOCKS, and CLUSTERING_FACTOR are optimizer
--     statistics and may not represent the current real-time state.
--   * This script does not determine whether an index is useful or redundant.
--     Those decisions require execution-plan and workload evidence.
--
-- Safety
--   Read-only. No index, statistics, table, or constraint is modified.
-- ============================================================================

SET PAGESIZE 500
SET LINESIZE 300
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

COLUMN schema_name       FORMAT A20
COLUMN table_name        FORMAT A30
COLUMN index_name        FORMAT A40
COLUMN index_type        FORMAT A22
COLUMN uniqueness        FORMAT A10
COLUMN status            FORMAT A10
COLUMN visibility        FORMAT A10
COLUMN partitioned       FORMAT A11
COLUMN constraint_type   FORMAT A16
COLUMN constraint_name   FORMAT A35
COLUMN index_columns     FORMAT A75
COLUMN index_segment_mb  FORMAT 999,999,990.00
COLUMN num_rows          FORMAT 999,999,999
COLUMN distinct_keys     FORMAT 999,999,999
COLUMN leaf_blocks       FORMAT 999,999,999
COLUMN clustering_factor FORMAT 999,999,999
COLUMN last_analyzed     FORMAT A20

PROMPT
PROMPT ================================================================================
PROMPT INDEX INVENTORY BASELINE
PROMPT ================================================================================
PROMPT

WITH index_segment_sizes AS
(
    SELECT
        segment_name AS index_name,
        SUM(bytes) AS segment_bytes
    FROM user_segments
    WHERE segment_type IN
          (
              'INDEX',
              'INDEX PARTITION',
              'INDEX SUBPARTITION'
          )
    GROUP BY
        segment_name
)
SELECT
    USER AS schema_name,
    COUNT(*) AS index_count,
    ROUND(
        NVL(SUM(seg.segment_bytes), 0) / 1024 / 1024,
        2
    ) AS total_index_mb,
    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time
FROM user_indexes idx
LEFT JOIN index_segment_sizes seg
       ON seg.index_name = idx.index_name
GROUP BY
    USER;

PROMPT
PROMPT ================================================================================
PROMPT INDEX INVENTORY DETAILS
PROMPT ================================================================================
PROMPT

WITH index_column_list AS
(
    SELECT
        col.index_name,

        LISTAGG(
            col.column_name
            ||
            CASE
                WHEN col.descend = 'DESC'
                    THEN ' DESC'
                ELSE ''
            END,
            ', ' ON OVERFLOW TRUNCATE '...' WITHOUT COUNT
        ) WITHIN GROUP
          (
              ORDER BY col.column_position
          ) AS index_columns

    FROM user_ind_columns col

    GROUP BY
        col.index_name
),

constraint_indexes AS
(
    SELECT
        con.index_name,

        MAX(
            CASE con.constraint_type
                WHEN 'P' THEN 'PRIMARY KEY'
                WHEN 'U' THEN 'UNIQUE'
            END
        ) AS constraint_type,

        MAX(con.constraint_name) AS constraint_name

    FROM user_constraints con

    WHERE con.constraint_type IN ('P', 'U')
      AND con.index_name IS NOT NULL

    GROUP BY
        con.index_name
),

index_segment_sizes AS
(
    SELECT
        segment_name AS index_name,
        SUM(bytes) AS segment_bytes

    FROM user_segments

    WHERE segment_type IN
          (
              'INDEX',
              'INDEX PARTITION',
              'INDEX SUBPARTITION'
          )

    GROUP BY
        segment_name
)

SELECT
    idx.table_name,
    idx.index_name,
    idx.index_type,
    idx.uniqueness,
    idx.status,
    idx.visibility,
    idx.partitioned,

    NVL(
        con.constraint_type,
        'NON-CONSTRAINT'
    ) AS constraint_type,

    con.constraint_name,
    cols.index_columns,

    ROUND(
        NVL(seg.segment_bytes, 0) / 1024 / 1024,
        2
    ) AS index_segment_mb,

    idx.num_rows,
    idx.distinct_keys,
    idx.leaf_blocks,
    idx.clustering_factor,

    TO_CHAR(
        idx.last_analyzed,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS last_analyzed

FROM user_indexes idx

LEFT JOIN index_column_list cols
       ON cols.index_name = idx.index_name

LEFT JOIN constraint_indexes con
       ON con.index_name = idx.index_name

LEFT JOIN index_segment_sizes seg
       ON seg.index_name = idx.index_name

ORDER BY
    idx.table_name,
    idx.index_name;

PROMPT
PROMPT ================================================================================
PROMPT INDEX INVENTORY INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT UNIQUE indexes may support primary-key or unique constraints.
PROMPT NON-CONSTRAINT indexes were created independently of PK or UK constraints.
PROMPT A VISIBLE and VALID index is available for normal optimizer consideration.
PROMPT Function-based indexes are identified through INDEX_TYPE.
PROMPT INDEX_SEGMENT_MB includes index partitions and subpartitions when present.
PROMPT High CLUSTERING_FACTOR values require table and workload context.
PROMPT Index usefulness or redundancy cannot be concluded from inventory alone.
PROMPT

PROMPT End of index inventory baseline report.
