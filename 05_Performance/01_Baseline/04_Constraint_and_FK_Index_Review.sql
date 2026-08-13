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
--   Establishes a read-only constraint inventory and evaluates whether each
--   foreign key is supported by an index whose leading columns match the
--   foreign-key columns in the same order.
--
-- Reports
--   * Primary-key, unique, and foreign-key constraints
--   * Constraint column lists
--   * Referenced parent tables
--   * Selected supporting index for each foreign key
--   * Number of matching supporting indexes
--   * Foreign-key index-review status
--
-- Foreign-Key Index Matching Rules
--   * Index columns must match all foreign-key columns by position.
--   * Foreign-key columns must be the leading columns of the index.
--   * An index may contain additional trailing columns.
--   * When several indexes qualify, the shortest matching index is displayed.
--   * MATCHING_INDEX_COUNT reports the total number of qualifying indexes.
--
-- Important Notes
--   * A foreign key without a supporting index is not automatically incorrect.
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
PROMPT CONSTRAINT AND FOREIGN-KEY INDEX BASELINE
PROMPT ================================================================================
PROMPT

WITH constraint_column_lists AS
(
    SELECT
        cols.constraint_name,

        LISTAGG(
            cols.column_name,
            ', '
        ) WITHIN GROUP
          (
              ORDER BY cols.position
          ) AS constraint_columns,

        COUNT(*) AS constraint_column_count

    FROM user_cons_columns cols

    GROUP BY
        cols.constraint_name
),

index_column_counts AS
(
    SELECT
        cols.index_name,
        COUNT(*) AS index_column_count

    FROM user_ind_columns cols

    GROUP BY
        cols.index_name
),

foreign_key_index_candidates AS
(
    SELECT
        fk.constraint_name,
        idx.index_name,
        idx.index_type,
        idx.uniqueness,
        idx_cols.index_column_count,
        fk_cols.constraint_column_count,

        ROW_NUMBER() OVER
        (
            PARTITION BY fk.constraint_name
            ORDER BY
                CASE
                    WHEN idx_cols.index_column_count =
                         fk_cols.constraint_column_count
                        THEN 0
                    ELSE 1
                END,
                idx_cols.index_column_count,
                idx.index_name
        ) AS candidate_rank,

        COUNT(*) OVER
        (
            PARTITION BY fk.constraint_name
        ) AS matching_index_count

    FROM user_constraints fk

    JOIN constraint_column_lists fk_cols
      ON fk_cols.constraint_name = fk.constraint_name

    JOIN user_indexes idx
      ON idx.table_name = fk.table_name
     AND idx.status = 'VALID'
     AND idx.visibility = 'VISIBLE'

    JOIN index_column_counts idx_cols
      ON idx_cols.index_name = idx.index_name
     AND idx_cols.index_column_count >= fk_cols.constraint_column_count

    WHERE fk.constraint_type = 'R'

      AND NOT EXISTS
          (
              SELECT
                  1
              FROM user_cons_columns fk_col
              WHERE fk_col.constraint_name = fk.constraint_name

                AND NOT EXISTS
                    (
                        SELECT
                            1
                        FROM user_ind_columns idx_col
                        WHERE idx_col.index_name = idx.index_name
                          AND idx_col.column_position = fk_col.position
                          AND idx_col.column_name = fk_col.column_name
                    )
          )
),

selected_foreign_key_indexes AS
(
    SELECT
        constraint_name,
        index_name,
        matching_index_count

    FROM foreign_key_index_candidates

    WHERE candidate_rank = 1
)

SELECT
    con.table_name,
    con.constraint_name,

    CASE con.constraint_type
        WHEN 'P' THEN 'PRIMARY KEY'
        WHEN 'U' THEN 'UNIQUE'
        WHEN 'R' THEN 'FOREIGN KEY'
        ELSE con.constraint_type
    END AS constraint_type,

    con.status AS constraint_status,
    con.validated,

    parent_con.table_name AS parent_table,

    cols.constraint_columns,

    selected_idx.index_name AS supporting_index,

    CASE
        WHEN con.constraint_type = 'R'
            THEN NVL(selected_idx.matching_index_count, 0)
        ELSE
            NULL
    END AS matching_index_count,

    CASE
        WHEN con.constraint_type <> 'R'
            THEN '-'
        WHEN selected_idx.index_name IS NOT NULL
            THEN 'SUPPORTED'
        ELSE
            'REVIEW'
    END AS fk_index_status

FROM user_constraints con

LEFT JOIN user_constraints parent_con
       ON parent_con.constraint_name = con.r_constraint_name
      AND con.constraint_type = 'R'

LEFT JOIN constraint_column_lists cols
       ON cols.constraint_name = con.constraint_name

LEFT JOIN selected_foreign_key_indexes selected_idx
       ON selected_idx.constraint_name = con.constraint_name

WHERE con.constraint_type IN ('P', 'U', 'R')

ORDER BY
    con.table_name,
    CASE con.constraint_type
        WHEN 'P' THEN 1
        WHEN 'U' THEN 2
        WHEN 'R' THEN 3
        ELSE 4
    END,
    con.constraint_name;

PROMPT
PROMPT ================================================================================
PROMPT FOREIGN-KEY INDEX REVIEW SUMMARY
PROMPT ================================================================================
PROMPT

WITH constraint_column_counts AS
(
    SELECT
        constraint_name,
        COUNT(*) AS constraint_column_count

    FROM user_cons_columns

    GROUP BY
        constraint_name
),

index_column_counts AS
(
    SELECT
        index_name,
        COUNT(*) AS index_column_count

    FROM user_ind_columns

    GROUP BY
        index_name
),

supported_foreign_keys AS
(
    SELECT DISTINCT
        fk.constraint_name

    FROM user_constraints fk

    JOIN constraint_column_counts fk_cols
      ON fk_cols.constraint_name = fk.constraint_name

    JOIN user_indexes idx
      ON idx.table_name = fk.table_name
     AND idx.status = 'VALID'
     AND idx.visibility = 'VISIBLE'

    JOIN index_column_counts idx_cols
      ON idx_cols.index_name = idx.index_name
     AND idx_cols.index_column_count >= fk_cols.constraint_column_count

    WHERE fk.constraint_type = 'R'

      AND NOT EXISTS
          (
              SELECT
                  1
              FROM user_cons_columns fk_col
              WHERE fk_col.constraint_name = fk.constraint_name

                AND NOT EXISTS
                    (
                        SELECT
                            1
                        FROM user_ind_columns idx_col
                        WHERE idx_col.index_name = idx.index_name
                          AND idx_col.column_position = fk_col.position
                          AND idx_col.column_name = fk_col.column_name
                    )
          )
)

SELECT
    COUNT(*) AS foreign_key_count,

    SUM(
        CASE
            WHEN supported.constraint_name IS NOT NULL
                THEN 1
            ELSE 0
        END
    ) AS supported_fk_count,

    SUM(
        CASE
            WHEN supported.constraint_name IS NULL
                THEN 1
            ELSE 0
        END
    ) AS review_fk_count,

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
PROMPT INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT SUPPORTED means that at least one visible and valid index has matching
PROMPT foreign-key columns as its leading columns in the same order.
PROMPT
PROMPT REVIEW means that no qualifying supporting index was detected.
PROMPT REVIEW does not automatically mean that an index must be created.
PROMPT
PROMPT MATCHING_INDEX_COUNT may be greater than one when several existing
PROMPT indexes share the same foreign-key leading-column prefix.
PROMPT
PROMPT Index recommendations require workload and execution-plan evidence.
PROMPT

PROMPT End of constraint and foreign-key index baseline report.
