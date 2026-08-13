-- ============================================================================
-- Oracle Banking Database
-- Module       : Performance / Index Analysis
-- Script       : 03_Index_Coverage_Analysis.sql
-- Purpose      : Validate index coverage across constraints and schema objects
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
PROMPT INDEX COVERAGE SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN category FORMAT A40
COLUMN total FORMAT 999,999

WITH application_indexes AS
(
    SELECT index_name,
           index_type
    FROM user_indexes
    WHERE index_type NOT IN ('LOB','IOT - TOP')
),
constraint_summary AS
(
    SELECT
        SUM(CASE WHEN constraint_type='P' THEN 1 ELSE 0 END) pk_count,
        SUM(CASE WHEN constraint_type='U' THEN 1 ELSE 0 END) uk_count,
        SUM(CASE WHEN constraint_type='R' THEN 1 ELSE 0 END) fk_count
    FROM user_constraints
),
index_summary AS
(
    SELECT
        COUNT(*) application_indexes,
        SUM(CASE WHEN index_type LIKE 'FUNCTION%' THEN 1 ELSE 0 END) function_indexes,
        SUM(CASE WHEN index_type='BITMAP' THEN 1 ELSE 0 END) bitmap_indexes
    FROM application_indexes
)
SELECT 'PRIMARY KEY CONSTRAINTS', pk_count
FROM constraint_summary

UNION ALL

SELECT 'UNIQUE CONSTRAINTS', uk_count
FROM constraint_summary

UNION ALL

SELECT 'FOREIGN KEY CONSTRAINTS', fk_count
FROM constraint_summary

UNION ALL

SELECT 'FUNCTION-BASED APPLICATION INDEXES', function_indexes
FROM index_summary

UNION ALL

SELECT 'BITMAP APPLICATION INDEXES', bitmap_indexes
FROM index_summary

UNION ALL

SELECT 'APPLICATION / CONSTRAINT INDEXES', application_indexes
FROM index_summary

UNION ALL

SELECT 'ORACLE-MANAGED LOB INDEXES', COUNT(*)
FROM user_indexes
WHERE index_type='LOB'

UNION ALL

SELECT 'ALL USER_INDEXES ROWS', COUNT(*)
FROM user_indexes;

PROMPT
PROMPT ================================================================================
PROMPT FOREIGN KEY LEADING-COLUMN COVERAGE SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN foreign_key_count FORMAT 999,999
COLUMN covered_foreign_keys FORMAT 999,999
COLUMN uncovered_foreign_keys FORMAT 999,999
COLUMN coverage_percent FORMAT 990.00

WITH fk_column_lists AS
(
    SELECT
        c.table_name,
        c.constraint_name,
        COUNT(*) fk_column_count,
        LISTAGG(cc.column_name,',')
            WITHIN GROUP (ORDER BY cc.position) fk_columns
    FROM user_constraints c
    JOIN user_cons_columns cc
      ON cc.constraint_name=c.constraint_name
     AND cc.table_name=c.table_name
    WHERE c.constraint_type='R'
    GROUP BY
        c.table_name,
        c.constraint_name
),
index_prefix_lists AS
(
    SELECT
        fk.table_name,
        fk.constraint_name,
        fk.fk_columns,
        idx.index_name,
        LISTAGG(ic.column_name,',')
            WITHIN GROUP (ORDER BY ic.column_position) index_columns
    FROM fk_column_lists fk
    JOIN user_indexes idx
      ON idx.table_name=fk.table_name
     AND idx.index_type NOT IN ('LOB','IOT - TOP')
    JOIN user_ind_columns ic
      ON ic.index_name=idx.index_name
     AND ic.table_name=idx.table_name
     AND ic.column_position<=fk.fk_column_count
    GROUP BY
        fk.table_name,
        fk.constraint_name,
        fk.fk_columns,
        fk.fk_column_count,
        idx.index_name
    HAVING COUNT(*)=fk.fk_column_count
),
coverage AS
(
    SELECT
        fk.table_name,
        fk.constraint_name,
        MAX(
            CASE
                WHEN ip.index_columns=fk.fk_columns
                THEN 1
                ELSE 0
            END
        ) covered
    FROM fk_column_lists fk
    LEFT JOIN index_prefix_lists ip
      ON ip.table_name=fk.table_name
     AND ip.constraint_name=fk.constraint_name
    GROUP BY
        fk.table_name,
        fk.constraint_name
)
SELECT
    COUNT(*) foreign_key_count,
    SUM(covered) covered_foreign_keys,
    SUM(CASE WHEN covered=0 THEN 1 ELSE 0 END) uncovered_foreign_keys,
    ROUND(SUM(covered)*100/COUNT(*),2) coverage_percent
FROM coverage;

PROMPT
PROMPT ================================================================================
PROMPT FOREIGN KEY LEADING-COLUMN COVERAGE DETAILS
PROMPT ================================================================================
PROMPT

COLUMN table_name FORMAT A30
COLUMN constraint_name FORMAT A35
COLUMN foreign_key_columns FORMAT A40
COLUMN covering_index FORMAT A40
COLUMN coverage_status FORMAT A24

WITH fk_column_lists AS
(
    SELECT
        c.table_name,
        c.constraint_name,
        COUNT(*) fk_column_count,
        LISTAGG(cc.column_name,', ')
            WITHIN GROUP (ORDER BY cc.position) fk_columns_display,
        LISTAGG(cc.column_name,',')
            WITHIN GROUP (ORDER BY cc.position) fk_columns_key
    FROM user_constraints c
    JOIN user_cons_columns cc
      ON cc.constraint_name=c.constraint_name
     AND cc.table_name=c.table_name
    WHERE c.constraint_type='R'
    GROUP BY
        c.table_name,
        c.constraint_name
),
matched_indexes AS
(
    SELECT
        fk.table_name,
        fk.constraint_name,
        idx.index_name,
        ROW_NUMBER() OVER
        (
            PARTITION BY fk.table_name,fk.constraint_name
            ORDER BY idx.index_name
        ) rn
    FROM fk_column_lists fk
    JOIN user_indexes idx
      ON idx.table_name=fk.table_name
     AND idx.index_type NOT IN ('LOB','IOT - TOP')
    JOIN
    (
        SELECT
            table_name,
            index_name,
            LISTAGG(column_name,',')
                WITHIN GROUP (ORDER BY column_position) idx_columns
        FROM user_ind_columns
        GROUP BY
            table_name,
            index_name
    ) ic
      ON ic.table_name=idx.table_name
     AND ic.index_name=idx.index_name
    WHERE (
          ic.idx_columns = fk.fk_columns_key
       OR ic.idx_columns LIKE fk.fk_columns_key || ',%'
      )
)
SELECT
    fk.table_name,
    fk.constraint_name,
    fk.fk_columns_display foreign_key_columns,
    mi.index_name covering_index,
    CASE
        WHEN mi.index_name IS NOT NULL
        THEN 'LEADING COLUMNS COVERED'
        ELSE 'NO LEADING INDEX'
    END coverage_status
FROM fk_column_lists fk
LEFT JOIN matched_indexes mi
  ON mi.table_name=fk.table_name
 AND mi.constraint_name=fk.constraint_name
 AND mi.rn=1
ORDER BY
    CASE
        WHEN mi.index_name IS NULL THEN 1
        ELSE 0
    END,
    fk.table_name,
    fk.constraint_name;

PROMPT
PROMPT ================================================================================
PROMPT APPLICATION INDEX STRUCTURE
PROMPT ================================================================================
PROMPT

COLUMN table_name FORMAT A30
COLUMN index_name FORMAT A40
COLUMN index_type FORMAT A22
COLUMN uniqueness FORMAT A10
COLUMN number_of_columns FORMAT 999

SELECT
    idx.table_name,
    idx.index_name,
    idx.index_type,
    idx.uniqueness,
    COUNT(ic.column_name) number_of_columns
FROM user_indexes idx
JOIN user_ind_columns ic
  ON ic.table_name=idx.table_name
 AND ic.index_name=idx.index_name
WHERE idx.index_type NOT IN ('LOB','IOT - TOP')
GROUP BY
    idx.table_name,
    idx.index_name,
    idx.index_type,
    idx.uniqueness
ORDER BY
    number_of_columns DESC,
    idx.table_name,
    idx.index_name;

PROMPT
PROMPT ================================================================================
PROMPT INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT Foreign-key coverage requires the foreign-key column list to match
PROMPT the leading columns of an index in the same order.
PROMPT
PROMPT Oracle-managed LOB indexes are excluded from application analysis.
PROMPT
PROMPT Foreign-key indexes improve join performance and reduce locking
PROMPT during parent-row UPDATE and DELETE operations.
PROMPT
PROMPT No index is created, altered, rebuilt, disabled or dropped.
PROMPT
PROMPT End of index coverage analysis.