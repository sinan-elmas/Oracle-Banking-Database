-- ============================================================================
-- Script Name : 04_Constraint_and_FK_Index_Review.sql
-- Module      : 05_Performance / 01_Baseline
-- Project     : Oracle Banking Database
-- Database    : Oracle AI Database 26ai Enterprise Edition
-- Version     : 23.26.1.0.0
-- Schema      : BANKING_DB
-- Tool        : Oracle SQL Developer
--
-- Purpose
--   Establishes a read-only constraint inventory and reviews whether foreign
--   keys have matching indexes before index optimization or SQL tuning.
--
-- Reports
--   * Total, supported, and review-required foreign-key counts
--   * Primary-key, unique, and foreign-key constraints
--   * Constraint column lists
--   * Referenced parent tables within the current schema
--   * Selected supporting index for each foreign key
--   * Number of matching supporting indexes
--   * Foreign-key index-review status
--
-- Foreign-Key Index Matching Rules
--   * All foreign-key columns must be present in the leading index columns.
--   * Foreign-key columns may appear in a different order within that prefix.
--   * An index may contain additional trailing columns.
--   * When several indexes qualify, the shortest matching index is displayed.
--   * Index name is used as a tie-breaker.
--   * MATCHING_INDEX_COUNT reports the total number of qualifying indexes.
--
-- Important Notes
--   * This report evaluates visible, valid, nonpartitioned B-tree indexes,
--     including function-based B-tree indexes with matching leading columns.
--   * Invisible and partitioned indexes require separate evaluation.
--   * Cross-schema parent tables are outside the parent-table lookup scope.
--   * A foreign key without a qualifying index is not automatically incorrect.
--   * Index requirements depend on parent-table DML, locking behavior,
--     application workload, selectivity, and execution-plan evidence.
--   * This report does not create or recommend indexes automatically.
--
-- Safety
--   Read-only. No constraint, index, table, or statistics object is modified.
-- ============================================================================

SET PAGESIZE 500
SET LINESIZE 260
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

COLUMN table_name             FORMAT A28
COLUMN constraint_name        FORMAT A35
COLUMN constraint_type        FORMAT A12
COLUMN constraint_status      FORMAT A8
COLUMN validated              FORMAT A13
COLUMN parent_table           FORMAT A28
COLUMN constraint_columns     FORMAT A55
COLUMN supporting_index       FORMAT A38
COLUMN matching_index_count   FORMAT 999
COLUMN fk_index_status        FORMAT A15

PROMPT
PROMPT ================================================================================
PROMPT FOREIGN-KEY INDEX REVIEW SUMMARY
PROMPT ================================================================================
PROMPT

WITH foreign_key_columns AS
(
    SELECT
        constraint_name,
        COUNT(*) AS column_count
    FROM user_cons_columns
    GROUP BY
        constraint_name
),

matching_indexes AS
(
    SELECT
        fk.constraint_name,
        idx.index_name

    FROM user_constraints fk

    JOIN foreign_key_columns fk_count
      ON fk_count.constraint_name = fk.constraint_name

    JOIN user_cons_columns fk_col
      ON fk_col.constraint_name = fk.constraint_name

    JOIN user_indexes idx
      ON idx.table_name = fk.table_name

    JOIN user_ind_columns idx_col
      ON idx_col.index_name = idx.index_name
     AND idx_col.column_name = fk_col.column_name
     AND idx_col.column_position <= fk_count.column_count

    WHERE fk.constraint_type = 'R'
      AND idx.status = 'VALID'
      AND idx.visibility = 'VISIBLE'
      AND idx.partitioned = 'NO'
      AND idx.index_type IN ('NORMAL', 'FUNCTION-BASED NORMAL')

    GROUP BY
        fk.constraint_name,
        idx.index_name,
        fk_count.column_count

    HAVING COUNT(DISTINCT fk_col.column_name) = fk_count.column_count
),

supported_foreign_keys AS
(
    SELECT DISTINCT
        constraint_name
    FROM matching_indexes
)

SELECT
    COUNT(*) AS foreign_key_count,

    COUNT(supported.constraint_name) AS supported_fk_count,

    COUNT(*) - COUNT(supported.constraint_name) AS review_fk_count,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM user_constraints fk

LEFT JOIN supported_foreign_keys supported
       ON supported.constraint_name = fk.constraint_name

WHERE fk.constraint_type = 'R';

PROMPT
PROMPT ================================================================================
PROMPT CONSTRAINT AND FOREIGN-KEY INDEX DETAILS
PROMPT ================================================================================
PROMPT

WITH constraint_columns AS
(
    SELECT
        constraint_name,

        LISTAGG(
            column_name,
            ', '
        ) WITHIN GROUP
          (
              ORDER BY position
          ) AS column_list,

        COUNT(*) AS column_count

    FROM user_cons_columns

    GROUP BY
        constraint_name
),

index_column_counts AS
(
    SELECT
        index_name,
        COUNT(*) AS column_count

    FROM user_ind_columns

    GROUP BY
        index_name
),

matching_indexes AS
(
    SELECT
        fk.constraint_name,
        idx.index_name,
        idx_count.column_count AS index_column_count

    FROM user_constraints fk

    JOIN constraint_columns fk_count
      ON fk_count.constraint_name = fk.constraint_name

    JOIN user_cons_columns fk_col
      ON fk_col.constraint_name = fk.constraint_name

    JOIN user_indexes idx
      ON idx.table_name = fk.table_name

    JOIN index_column_counts idx_count
      ON idx_count.index_name = idx.index_name

    JOIN user_ind_columns idx_col
      ON idx_col.index_name = idx.index_name
     AND idx_col.column_name = fk_col.column_name
     AND idx_col.column_position <= fk_count.column_count

    WHERE fk.constraint_type = 'R'
      AND idx.status = 'VALID'
      AND idx.visibility = 'VISIBLE'
      AND idx.partitioned = 'NO'
      AND idx.index_type IN ('NORMAL', 'FUNCTION-BASED NORMAL')

    GROUP BY
        fk.constraint_name,
        idx.index_name,
        idx_count.column_count,
        fk_count.column_count

    HAVING COUNT(DISTINCT fk_col.column_name) = fk_count.column_count
),

ranked_indexes AS
(
    SELECT
        constraint_name,
        index_name,

        ROW_NUMBER() OVER
        (
            PARTITION BY constraint_name
            ORDER BY
                index_column_count,
                index_name
        ) AS candidate_rank,

        COUNT(*) OVER
        (
            PARTITION BY constraint_name
        ) AS matching_index_count

    FROM matching_indexes
)

SELECT
    con.table_name,
    con.constraint_name,

    CASE con.constraint_type
        WHEN 'P' THEN 'PRIMARY KEY'
        WHEN 'U' THEN 'UNIQUE'
        WHEN 'R' THEN 'FOREIGN KEY'
    END AS constraint_type,

    con.status AS constraint_status,
    con.validated,

    parent_con.table_name AS parent_table,

    cols.column_list AS constraint_columns,

    idx.index_name AS supporting_index,

    CASE
        WHEN con.constraint_type = 'R'
            THEN NVL(idx.matching_index_count, 0)
    END AS matching_index_count,

    CASE
        WHEN con.constraint_type <> 'R'
            THEN '-'
        WHEN idx.index_name IS NOT NULL
            THEN 'SUPPORTED'
        ELSE
            'REVIEW'
    END AS fk_index_status

FROM user_constraints con

LEFT JOIN user_constraints parent_con
       ON parent_con.constraint_name = con.r_constraint_name
      AND parent_con.owner = con.r_owner
      AND con.constraint_type = 'R'

LEFT JOIN constraint_columns cols
       ON cols.constraint_name = con.constraint_name

LEFT JOIN ranked_indexes idx
       ON idx.constraint_name = con.constraint_name
      AND idx.candidate_rank = 1

WHERE con.constraint_type IN ('P', 'U', 'R')

ORDER BY
    con.table_name,

    CASE con.constraint_type
        WHEN 'P' THEN 1
        WHEN 'U' THEN 2
        WHEN 'R' THEN 3
    END,

    con.constraint_name;

PROMPT
PROMPT ================================================================================
PROMPT INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT SUPPORTED means that at least one qualifying index contains all
PROMPT foreign-key columns within its leading column prefix.
PROMPT Foreign-key columns do not need to appear in the same order.
PROMPT
PROMPT REVIEW means that no qualifying supporting index was detected.
PROMPT REVIEW does not automatically mean that an index must be created.
PROMPT
PROMPT Only visible, valid, nonpartitioned normal and function-based
PROMPT B-tree indexes are evaluated by this report.
PROMPT Invisible, partitioned, and other index types require separate review.
PROMPT
PROMPT MATCHING_INDEX_COUNT may be greater than one when several existing
PROMPT indexes contain the same foreign-key leading-column set.
PROMPT
PROMPT SUPPORTING_INDEX displays the qualifying index with the fewest columns.
PROMPT Parent-table lookup is limited to the current schema.
PROMPT
PROMPT Index recommendations require workload and execution-plan evidence.
PROMPT

PROMPT End of constraint and foreign-key index baseline report.
