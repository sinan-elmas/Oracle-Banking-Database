-- ============================================================================
-- Oracle Banking Database
-- Module       : Performance / Index Analysis
-- Script       : 01_Index_Usage_Evidence.sql
-- Purpose      : Identify index usage evidence from currently cached
--                SQL execution plans in the shared pool
-- Scope        : Current schema indexes and current shared pool contents
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
PROMPT INDEX USAGE EVIDENCE SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN schema_name          FORMAT A20
COLUMN total_indexes        FORMAT 999,999
COLUMN observed_indexes     FORMAT 999,999
COLUMN not_observed_indexes FORMAT 999,999
COLUMN observation_percent  FORMAT 990.00
COLUMN report_time          FORMAT A20

WITH current_indexes AS
(
    SELECT
        index_name
    FROM user_indexes
    WHERE index_type NOT IN
          (
              'LOB',
              'IOT - TOP'
          )
),
observed_indexes AS
(
    SELECT DISTINCT
        plan.object_name AS index_name
    FROM v$sql_plan plan
    JOIN current_indexes idx
      ON idx.index_name = plan.object_name
    WHERE plan.object_owner = USER
      AND plan.operation LIKE 'INDEX%'
      AND plan.object_name IS NOT NULL
)
SELECT
    USER AS schema_name,

    COUNT(*) AS total_indexes,

    COUNT(
        CASE
            WHEN observed.index_name IS NOT NULL THEN 1
        END
    ) AS observed_indexes,

    COUNT(
        CASE
            WHEN observed.index_name IS NULL THEN 1
        END
    ) AS not_observed_indexes,

    ROUND(
        COUNT(
            CASE
                WHEN observed.index_name IS NOT NULL THEN 1
            END
        ) * 100
        / NULLIF(COUNT(*), 0),
        2
    ) AS observation_percent,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM current_indexes idx

LEFT JOIN observed_indexes observed
       ON observed.index_name = idx.index_name;

PROMPT
PROMPT ================================================================================
PROMPT INDEX USAGE EVIDENCE DETAILS
PROMPT ================================================================================
PROMPT

COLUMN table_name         FORMAT A30
COLUMN index_name         FORMAT A40
COLUMN index_type         FORMAT A22
COLUMN constraint_role    FORMAT A16
COLUMN uniqueness         FORMAT A10
COLUMN visibility         FORMAT A10
COLUMN status             FORMAT A10
COLUMN plan_occurrences   FORMAT 999,999
COLUMN distinct_sql_count FORMAT 999,999
COLUMN last_observed      FORMAT A20
COLUMN observation_status FORMAT A24

WITH constraint_indexes AS
(
    SELECT
        index_name,

        MAX(
            CASE constraint_type
                WHEN 'P' THEN 'PRIMARY KEY'
                WHEN 'U' THEN 'UNIQUE'
            END
        ) AS constraint_role

    FROM user_constraints

    WHERE constraint_type IN ('P', 'U')
      AND index_name IS NOT NULL

    GROUP BY
        index_name
),
plan_usage AS
(
    SELECT
        plan.object_name AS index_name,

        COUNT(*) AS plan_occurrences,

        COUNT(
            DISTINCT plan.sql_id
        ) AS distinct_sql_count,

        MAX(
            sql_data.last_active_time
        ) AS last_observed

    FROM v$sql_plan plan

    LEFT JOIN v$sql sql_data
           ON sql_data.sql_id = plan.sql_id
          AND sql_data.child_number = plan.child_number

    WHERE plan.object_owner = USER
      AND plan.operation LIKE 'INDEX%'
      AND plan.object_name IS NOT NULL

    GROUP BY
        plan.object_name
)
SELECT
    idx.table_name,
    idx.index_name,
    idx.index_type,

    NVL(
        constraint_info.constraint_role,
        'NON-CONSTRAINT'
    ) AS constraint_role,

    idx.uniqueness,
    idx.visibility,
    idx.status,

    NVL(
        usage_info.plan_occurrences,
        0
    ) AS plan_occurrences,

    NVL(
        usage_info.distinct_sql_count,
        0
    ) AS distinct_sql_count,

    TO_CHAR(
        usage_info.last_observed,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS last_observed,

    CASE
        WHEN usage_info.index_name IS NOT NULL
            THEN 'OBSERVED IN SHARED POOL'
        ELSE 'NOT OBSERVED'
    END AS observation_status

FROM user_indexes idx

LEFT JOIN constraint_indexes constraint_info
       ON constraint_info.index_name = idx.index_name

LEFT JOIN plan_usage usage_info
       ON usage_info.index_name = idx.index_name

WHERE idx.index_type NOT IN
      (
          'LOB',
          'IOT - TOP'
      )

ORDER BY
    CASE
        WHEN usage_info.index_name IS NULL THEN 1
        ELSE 0
    END,
    NVL(
        usage_info.distinct_sql_count,
        0
    ) DESC,
    idx.table_name,
    idx.index_name;

PROMPT
PROMPT ================================================================================
PROMPT OBSERVED INDEX ACCESS OPERATIONS
PROMPT ================================================================================
PROMPT

COLUMN index_name         FORMAT A40
COLUMN access_operation   FORMAT A32
COLUMN occurrence_count   FORMAT 999,999
COLUMN distinct_sql_count FORMAT 999,999

SELECT
    plan.object_name AS index_name,

    plan.operation
    ||
    CASE
        WHEN plan.options IS NOT NULL
            THEN ' ' || plan.options
        ELSE ''
    END AS access_operation,

    COUNT(*) AS occurrence_count,

    COUNT(
        DISTINCT plan.sql_id
    ) AS distinct_sql_count

FROM v$sql_plan plan

JOIN user_indexes idx
  ON idx.index_name = plan.object_name

WHERE plan.object_owner = USER
  AND plan.operation LIKE 'INDEX%'
  AND idx.index_type NOT IN
      (
          'LOB',
          'IOT - TOP'
      )

GROUP BY
    plan.object_name,
    plan.operation,
    plan.options

ORDER BY
    plan.object_name,
    occurrence_count DESC,
    access_operation;

PROMPT
PROMPT ================================================================================
PROMPT INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT OBSERVED IN SHARED POOL means the index appears in at least one
PROMPT currently cached SQL execution plan.
PROMPT
PROMPT NOT OBSERVED does not prove that an index is unused.
PROMPT
PROMPT Shared pool contents may be aged out, flushed, or changed after
PROMPT instance restart.
PROMPT
PROMPT Constraint indexes must not be classified as removable only from
PROMPT shared-pool usage observations.
PROMPT
PROMPT A reliable unused-index decision requires a representative workload
PROMPT observation period and stronger evidence.
PROMPT
PROMPT No index is created, altered, monitored, disabled, rebuilt, or dropped
PROMPT by this script.
PROMPT
PROMPT End of index usage evidence report.