-- ============================================================================
-- Oracle Banking Database
-- Module       : Performance / Index Analysis
-- Script       : 02_Index_Selectivity_Analysis.sql
-- Purpose      : Review index selectivity and optimizer statistics
-- Scope        : Application and constraint indexes
-- Safety       : Read-only
-- Database     : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- ============================================================================

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 500
SET LINESIZE 240
SET FEEDBACK ON
SET VERIFY OFF
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT ================================================================================
PROMPT INDEX SELECTIVITY ANALYSIS
PROMPT ================================================================================
PROMPT

COLUMN table_name          FORMAT A30
COLUMN index_name          FORMAT A40
COLUMN uniqueness          FORMAT A10
COLUMN status              FORMAT A10
COLUMN num_rows            FORMAT 999,999,999
COLUMN distinct_keys       FORMAT 999,999,999
COLUMN leaf_blocks         FORMAT 999,999
COLUMN clustering_factor   FORMAT 999,999,999
COLUMN selectivity_percent FORMAT 990.9999

SELECT
    idx.table_name,
    idx.index_name,
    idx.uniqueness,
    idx.status,
    tbl.num_rows,
    idx.distinct_keys,
    idx.leaf_blocks,
    idx.clustering_factor,

    ROUND(
        idx.distinct_keys * 100
        / NULLIF(tbl.num_rows, 0),
        4
    ) AS selectivity_percent

FROM user_indexes idx

JOIN user_tables tbl
  ON tbl.table_name = idx.table_name

WHERE idx.index_type NOT IN
      (
          'LOB',
          'IOT - TOP'
      )

ORDER BY
    selectivity_percent DESC NULLS LAST,
    idx.table_name,
    idx.index_name;

PROMPT
PROMPT ================================================================================
PROMPT INDEX CATEGORY SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN selectivity_category FORMAT A25
COLUMN index_count          FORMAT 999,999

WITH index_stats AS
(
    SELECT
        CASE
            WHEN tbl.num_rows IS NULL
              OR idx.distinct_keys IS NULL
                THEN NULL

            ELSE ROUND(
                idx.distinct_keys * 100
                / NULLIF(tbl.num_rows, 0),
                4
            )
        END AS selectivity_percent

    FROM user_indexes idx

    JOIN user_tables tbl
      ON tbl.table_name = idx.table_name

    WHERE idx.index_type NOT IN
          (
              'LOB',
              'IOT - TOP'
          )
),
categorized_indexes AS
(
    SELECT
        CASE
            WHEN selectivity_percent IS NULL
                THEN 'STATISTICS UNAVAILABLE'

            WHEN selectivity_percent >= 90
                THEN 'HIGH SELECTIVITY'

            WHEN selectivity_percent >= 10
                THEN 'MEDIUM SELECTIVITY'

            ELSE 'LOW SELECTIVITY'
        END AS selectivity_category

    FROM index_stats
)
SELECT
    selectivity_category,
    COUNT(*) AS index_count

FROM categorized_indexes

GROUP BY
    selectivity_category

ORDER BY
    CASE selectivity_category
        WHEN 'HIGH SELECTIVITY'       THEN 1
        WHEN 'MEDIUM SELECTIVITY'     THEN 2
        WHEN 'LOW SELECTIVITY'        THEN 3
        WHEN 'STATISTICS UNAVAILABLE' THEN 4
        ELSE 5
    END;

PROMPT
PROMPT ================================================================================
PROMPT INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT SELECTIVITY_PERCENT is calculated as DISTINCT_KEYS / TABLE_NUM_ROWS * 100.
PROMPT
PROMPT High selectivity generally improves index efficiency for selective access.
PROMPT
PROMPT Low selectivity does not automatically indicate an unnecessary index.
PROMPT
PROMPT Foreign-key and lookup columns commonly exhibit low selectivity.
PROMPT
PROMPT CLUSTERING_FACTOR should be evaluated relative to table blocks and rows.
PROMPT
PROMPT A clustering factor closer to the table block count generally indicates
PROMPT better physical row ordering for index range access.
PROMPT
PROMPT A clustering factor closer to the table row count may increase the cost
PROMPT of table access by index ROWID.
PROMPT
PROMPT Oracle Cost-Based Optimizer evaluates selectivity together with
PROMPT cardinality, clustering factor, predicates, and workload characteristics.
PROMPT
PROMPT STATISTICS UNAVAILABLE indicates missing table or index statistics.
PROMPT
PROMPT No index or optimizer statistic is modified by this script.
PROMPT
PROMPT End of index selectivity analysis.