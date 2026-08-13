-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Schema Validation
-- Script       : 04_Index_Status_Check.sql
-- Purpose      : Validate index status, visibility, type, and overall health
-- Scope        : Current application schema
-- Safety       : Read-only
-- Environment  : Oracle AI Database 26ai Enterprise Edition
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

ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

PROMPT
PROMPT ================================================================================
PROMPT INDEX HEALTH SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN schema_name                 FORMAT A20
COLUMN total_indexes               FORMAT 999,999
COLUMN valid_indexes               FORMAT 999,999
COLUMN unusable_indexes            FORMAT 999,999
COLUMN visible_indexes             FORMAT 999,999
COLUMN invisible_indexes           FORMAT 999,999
COLUMN application_indexes         FORMAT 999,999
COLUMN oracle_managed_lob_indexes  FORMAT 999,999
COLUMN health_status               FORMAT A12
COLUMN report_time                 FORMAT A20

WITH index_health AS
(
    SELECT
        COUNT(*) AS total_indexes,

        SUM(
            CASE
                WHEN status = 'VALID' THEN 1
                ELSE 0
            END
        ) AS valid_indexes,

        SUM(
            CASE
                WHEN status = 'UNUSABLE' THEN 1
                ELSE 0
            END
        ) AS unusable_indexes,

        SUM(
            CASE
                WHEN visibility = 'VISIBLE' THEN 1
                ELSE 0
            END
        ) AS visible_indexes,

        SUM(
            CASE
                WHEN visibility = 'INVISIBLE' THEN 1
                ELSE 0
            END
        ) AS invisible_indexes,

        SUM(
            CASE
                WHEN index_type NOT IN ('LOB', 'IOT - TOP') THEN 1
                ELSE 0
            END
        ) AS application_indexes,

        SUM(
            CASE
                WHEN index_type = 'LOB' THEN 1
                ELSE 0
            END
        ) AS oracle_managed_lob_indexes

    FROM user_indexes
)
SELECT
    USER AS schema_name,
    total_indexes,
    valid_indexes,
    unusable_indexes,
    visible_indexes,
    invisible_indexes,
    application_indexes,
    oracle_managed_lob_indexes,

    CASE
        WHEN unusable_indexes = 0
         AND invisible_indexes = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END AS health_status,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM index_health;

PROMPT
PROMPT ================================================================================
PROMPT INDEX TYPE SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN index_type       FORMAT A28
COLUMN index_count      FORMAT 999,999
COLUMN valid_count      FORMAT 999,999
COLUMN unusable_count   FORMAT 999,999
COLUMN visible_count    FORMAT 999,999
COLUMN invisible_count  FORMAT 999,999

SELECT
    index_type,
    COUNT(*) AS index_count,

    SUM(
        CASE
            WHEN status = 'VALID' THEN 1
            ELSE 0
        END
    ) AS valid_count,

    SUM(
        CASE
            WHEN status = 'UNUSABLE' THEN 1
            ELSE 0
        END
    ) AS unusable_count,

    SUM(
        CASE
            WHEN visibility = 'VISIBLE' THEN 1
            ELSE 0
        END
    ) AS visible_count,

    SUM(
        CASE
            WHEN visibility = 'INVISIBLE' THEN 1
            ELSE 0
        END
    ) AS invisible_count

FROM user_indexes

GROUP BY
    index_type

ORDER BY
    index_type;

PROMPT
PROMPT ================================================================================
PROMPT NAMED APPLICATION INDEX DETAILS
PROMPT ================================================================================
PROMPT

COLUMN table_name       FORMAT A30
COLUMN index_name       FORMAT A40
COLUMN index_type       FORMAT A24
COLUMN uniqueness       FORMAT A10
COLUMN status           FORMAT A10
COLUMN visibility       FORMAT A10
COLUMN partitioned      FORMAT A11
COLUMN generated        FORMAT A10
COLUMN last_analyzed    FORMAT A20

SELECT
    table_name,
    index_name,
    index_type,
    uniqueness,
    status,
    visibility,
    partitioned,
    generated,

    TO_CHAR(
        last_analyzed,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS last_analyzed

FROM user_indexes

WHERE index_type NOT IN
      (
          'LOB',
          'IOT - TOP'
      )
  AND index_name NOT LIKE 'SYS_%'

ORDER BY
    table_name,
    index_name;

PROMPT
PROMPT ================================================================================
PROMPT UNUSABLE OR INVISIBLE APPLICATION INDEXES
PROMPT ================================================================================
PROMPT

COLUMN table_name   FORMAT A30
COLUMN index_name   FORMAT A40
COLUMN index_type   FORMAT A24
COLUMN uniqueness   FORMAT A10
COLUMN status       FORMAT A10
COLUMN visibility   FORMAT A10
COLUMN partitioned  FORMAT A11

SELECT
    table_name,
    index_name,
    index_type,
    uniqueness,
    status,
    visibility,
    partitioned

FROM user_indexes

WHERE index_type NOT IN
      (
          'LOB',
          'IOT - TOP'
      )
  AND
      (
          status = 'UNUSABLE'
          OR visibility = 'INVISIBLE'
      )

ORDER BY
    table_name,
    index_name;

PROMPT
PROMPT ================================================================================
PROMPT INDEX UNIQUENESS SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN uniqueness  FORMAT A12
COLUMN index_count FORMAT 999,999

SELECT
    uniqueness,
    COUNT(*) AS index_count

FROM user_indexes

WHERE index_type NOT IN
      (
          'LOB',
          'IOT - TOP'
      )

GROUP BY
    uniqueness

ORDER BY
    uniqueness;

PROMPT
PROMPT ================================================================================
PROMPT FUNCTION-BASED INDEX SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN table_name  FORMAT A30
COLUMN index_name  FORMAT A40
COLUMN index_type  FORMAT A24
COLUMN uniqueness  FORMAT A10
COLUMN status      FORMAT A10
COLUMN visibility  FORMAT A10

SELECT
    table_name,
    index_name,
    index_type,
    uniqueness,
    status,
    visibility

FROM user_indexes

WHERE index_type LIKE 'FUNCTION-BASED%'

ORDER BY
    table_name,
    index_name;

PROMPT
PROMPT ================================================================================
PROMPT INDEX INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT PASS means no schema index is unusable or invisible.
PROMPT
PROMPT The health summary includes application indexes, constraint indexes,
PROMPT and Oracle-managed LOB indexes.
PROMPT
PROMPT The named application index detail section excludes SYS_ indexes to avoid
PROMPT listing Oracle-generated constraint-supporting index names.
PROMPT
PROMPT The unusable or invisible index check still evaluates all non-LOB indexes,
PROMPT including Oracle-generated constraint-supporting indexes.
PROMPT
PROMPT UNUSABLE indexes cannot provide normal index access until rebuilt or recreated.
PROMPT
PROMPT INVISIBLE indexes remain maintained by Oracle but are normally ignored by
PROMPT the optimizer unless optimizer_use_invisible_indexes is enabled.
PROMPT
PROMPT Oracle-managed LOB indexes are reported separately and excluded from the
PROMPT named application index detail section.
PROMPT
PROMPT FUNCTION-BASED indexes support predicates or uniqueness rules based on
PROMPT indexed expressions rather than only stored column values.
PROMPT
PROMPT LAST_ANALYZED reflects the latest available optimizer statistics.
PROMPT
PROMPT No index, table, constraint, or optimizer statistic is modified.
PROMPT
PROMPT End of index status validation report.