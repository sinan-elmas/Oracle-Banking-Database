-- ============================================================================
-- Script Name : 01_PLSQL_Runtime_Inventory.sql
-- Module      : 05_Performance / 05_PLSQL_Performance_Review
-- Project     : Oracle Banking Database
-- Database    : Oracle AI Database 26ai Enterprise Edition
-- Version     : 23.26.1.0.0
-- Schema      : BANKING_DB
-- Tool        : Oracle SQL Developer
--
-- Purpose
--   Establishes a read-only PL/SQL inventory before runtime SQL activity and
--   performance assessment.
--
-- Reports
--   * Package specification and body status
--   * PL/SQL compiler settings
--   * Public subprogram counts
--   * Source-code size indicators
--   * Trigger scope and status
--   * Direct package dependencies
--   * Inventory summary and review flags
--
-- Important Notes
--   * Source line and byte counts are maintainability indicators; they do not
--     prove that an object is slow.
--   * Public subprogram counts describe exposed APIs, not runtime frequency.
--   * Performance conclusions require runtime evidence from V$SQL or other
--     measured sources.
--   * This script does not execute application procedures or modify objects.
--
-- Safety
--   Read-only. No DDL, DML, recompilation, statistics collection, or object
--   modification.
-- ============================================================================

SET PAGESIZE 500
SET LINESIZE 220
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

COLUMN schema_name          FORMAT A20
COLUMN object_name          FORMAT A40
COLUMN object_type          FORMAT A14
COLUMN status               FORMAT A8
COLUMN plsql_code_type      FORMAT A15
COLUMN plsql_optimize_level FORMAT 9
COLUMN plsql_debug          FORMAT A11
COLUMN plsql_warnings       FORMAT A30
COLUMN public_subprograms   FORMAT 999
COLUMN source_lines         FORMAT 999,999
COLUMN source_kb            FORMAT 999,990.00
COLUMN review_flag          FORMAT A18

PROMPT
PROMPT ================================================================================
PROMPT PL/SQL RUNTIME INVENTORY - REPORT SCOPE
PROMPT ================================================================================
PROMPT

SELECT
    USER AS schema_name,
    COUNT(DISTINCT CASE
        WHEN object_type = 'PACKAGE'
        THEN object_name
    END) AS package_count,
    COUNT(DISTINCT CASE
        WHEN object_type = 'PACKAGE BODY'
        THEN object_name
    END) AS package_body_count,
    COUNT(DISTINCT CASE
        WHEN object_type = 'TRIGGER'
        THEN object_name
    END) AS trigger_count,
    TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') AS report_time
FROM user_objects
WHERE object_type IN (
    'PACKAGE',
    'PACKAGE BODY',
    'TRIGGER'
);

PROMPT
PROMPT ================================================================================
PROMPT PACKAGE COMPILATION AND COMPILER SETTINGS
PROMPT ================================================================================
PROMPT

WITH package_objects AS
(
    SELECT
        object_name,
        object_type,
        status,
        last_ddl_time
    FROM user_objects
    WHERE object_type IN (
        'PACKAGE',
        'PACKAGE BODY'
    )
),
source_metrics AS
(
    SELECT
        name AS object_name,
        type AS object_type,
        COUNT(*) AS source_lines,
        SUM(LENGTHB(text)) AS source_bytes
    FROM user_source
    WHERE type IN (
        'PACKAGE',
        'PACKAGE BODY'
    )
    GROUP BY
        name,
        type
),
public_api AS
(
    SELECT
        object_name,
        COUNT(*) AS public_subprograms
    FROM user_procedures
    WHERE object_type = 'PACKAGE'
      AND procedure_name IS NOT NULL
    GROUP BY
        object_name
)
SELECT
    obj.object_name,
    obj.object_type,
    obj.status,

    settings.plsql_code_type,
    settings.plsql_optimize_level,
    settings.plsql_debug,
    settings.plsql_warnings,

    CASE
        WHEN obj.object_type = 'PACKAGE'
        THEN NVL(api.public_subprograms, 0)
        ELSE NULL
    END AS public_subprograms,

    NVL(src.source_lines, 0) AS source_lines,

    ROUND(
        NVL(src.source_bytes, 0) / 1024,
        2
    ) AS source_kb,

    TO_CHAR(
        obj.last_ddl_time,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS last_ddl_time,

    CASE
        WHEN obj.status <> 'VALID'
            THEN 'INVALID'
        WHEN settings.plsql_optimize_level IS NULL
            THEN 'SETTINGS REVIEW'
        WHEN settings.plsql_optimize_level < 2
            THEN 'OPTIMIZE REVIEW'
        WHEN settings.plsql_debug = 'TRUE'
            THEN 'DEBUG ENABLED'
        ELSE
            'NO FLAG'
    END AS review_flag

FROM package_objects obj

LEFT JOIN user_plsql_object_settings settings
       ON settings.name = obj.object_name
      AND settings.type = obj.object_type

LEFT JOIN source_metrics src
       ON src.object_name = obj.object_name
      AND src.object_type = obj.object_type

LEFT JOIN public_api api
       ON api.object_name = obj.object_name

ORDER BY
    obj.object_name,
    CASE obj.object_type
        WHEN 'PACKAGE' THEN 1
        WHEN 'PACKAGE BODY' THEN 2
        ELSE 3
    END;

PROMPT
PROMPT ================================================================================
PROMPT PACKAGE API INVENTORY
PROMPT ================================================================================
PROMPT

COLUMN package_name        FORMAT A40
COLUMN subprogram_name     FORMAT A40
COLUMN subprogram_type     FORMAT A14
COLUMN overload            FORMAT A8
COLUMN argument_count      FORMAT 999
COLUMN in_arguments        FORMAT 999
COLUMN out_arguments       FORMAT 999

WITH argument_summary AS
(
    SELECT
        package_name,
        object_name AS subprogram_name,
        overload,
        COUNT(*) AS argument_count,
        SUM(
            CASE
                WHEN in_out IN ('IN', 'IN/OUT')
                THEN 1
                ELSE 0
            END
        ) AS in_arguments,
        SUM(
            CASE
                WHEN in_out IN ('OUT', 'IN/OUT')
                THEN 1
                ELSE 0
            END
        ) AS out_arguments
    FROM user_arguments
    WHERE package_name IS NOT NULL
      AND data_level = 0
      AND position > 0
    GROUP BY
        package_name,
        object_name,
        overload
)
SELECT
    proc.object_name AS package_name,
    proc.procedure_name AS subprogram_name,
    CASE
        WHEN proc.procedure_name IS NULL
            THEN 'PACKAGE'
        ELSE 'SUBPROGRAM'
    END AS subprogram_type,
    NVL(proc.overload, '-') AS overload,
    NVL(args.argument_count, 0) AS argument_count,
    NVL(args.in_arguments, 0) AS in_arguments,
    NVL(args.out_arguments, 0) AS out_arguments
FROM user_procedures proc
LEFT JOIN argument_summary args
       ON args.package_name = proc.object_name
      AND args.subprogram_name = proc.procedure_name
      AND NVL(args.overload, '#') = NVL(proc.overload, '#')
WHERE proc.object_type = 'PACKAGE'
  AND proc.procedure_name IS NOT NULL
ORDER BY
    proc.object_name,
    proc.subprogram_id,
    proc.procedure_name;

PROMPT
PROMPT ================================================================================
PROMPT TRIGGER INVENTORY
PROMPT ================================================================================
PROMPT

COLUMN trigger_name       FORMAT A40
COLUMN trigger_type       FORMAT A28
COLUMN triggering_event   FORMAT A30
COLUMN table_owner        FORMAT A20
COLUMN table_name         FORMAT A35
COLUMN base_object_type   FORMAT A18
COLUMN action_type        FORMAT A12
COLUMN status             FORMAT A10
COLUMN source_lines       FORMAT 999,999
COLUMN source_kb          FORMAT 999,990.00

WITH trigger_source AS
(
    SELECT
        name AS trigger_name,
        COUNT(*) AS source_lines,
        SUM(LENGTHB(text)) AS source_bytes
    FROM user_source
    WHERE type = 'TRIGGER'
    GROUP BY
        name
)
SELECT
    trg.trigger_name,
    trg.trigger_type,
    trg.triggering_event,
    trg.table_owner,
    trg.table_name,
    trg.base_object_type,
    trg.action_type,
    trg.status,
    NVL(src.source_lines, 0) AS source_lines,
    ROUND(
        NVL(src.source_bytes, 0) / 1024,
        2
    ) AS source_kb
FROM user_triggers trg
LEFT JOIN trigger_source src
       ON src.trigger_name = trg.trigger_name
ORDER BY
    trg.trigger_name;

PROMPT
PROMPT ================================================================================
PROMPT DIRECT PACKAGE DEPENDENCY INVENTORY
PROMPT ================================================================================
PROMPT

COLUMN package_name       FORMAT A40
COLUMN referenced_owner   FORMAT A20
COLUMN referenced_name    FORMAT A40
COLUMN referenced_type    FORMAT A20
COLUMN dependency_count   FORMAT 999

SELECT
    name AS package_name,
    referenced_owner,
    referenced_name,
    referenced_type,
    COUNT(*) AS dependency_count
FROM user_dependencies
WHERE type IN (
    'PACKAGE',
    'PACKAGE BODY'
)
  AND referenced_type IN (
    'TABLE',
    'VIEW',
    'SEQUENCE',
    'PACKAGE',
    'SYNONYM',
    'TYPE'
)
GROUP BY
    name,
    referenced_owner,
    referenced_name,
    referenced_type
ORDER BY
    name,
    referenced_type,
    referenced_owner,
    referenced_name;

PROMPT
PROMPT ================================================================================
PROMPT PL/SQL INVENTORY SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN metric_name    FORMAT A42
COLUMN metric_value   FORMAT 999,999
COLUMN metric_status  FORMAT A12

WITH metrics AS
(
    SELECT
        'PACKAGE_SPECIFICATIONS' AS metric_name,
        COUNT(*) AS metric_value,
        9 AS expected_value
    FROM user_objects
    WHERE object_type = 'PACKAGE'

    UNION ALL

    SELECT
        'PACKAGE_BODIES',
        COUNT(*),
        9
    FROM user_objects
    WHERE object_type = 'PACKAGE BODY'

    UNION ALL

    SELECT
        'VALID_PACKAGE_SPECIFICATIONS',
        COUNT(*),
        9
    FROM user_objects
    WHERE object_type = 'PACKAGE'
      AND status = 'VALID'

    UNION ALL

    SELECT
        'VALID_PACKAGE_BODIES',
        COUNT(*),
        9
    FROM user_objects
    WHERE object_type = 'PACKAGE BODY'
      AND status = 'VALID'

    UNION ALL

    SELECT
        'TRIGGERS',
        COUNT(*),
        7
    FROM user_triggers

    UNION ALL

    SELECT
        'ENABLED_TRIGGERS',
        COUNT(*),
        7
    FROM user_triggers
    WHERE status = 'ENABLED'

    UNION ALL

    SELECT
        'PLSQL_COMPILATION_ERRORS',
        COUNT(*),
        0
    FROM user_errors
    WHERE type IN (
        'PACKAGE',
        'PACKAGE BODY',
        'TRIGGER'
    )

    UNION ALL

    SELECT
        'LOW_OPTIMIZATION_LEVEL_OBJECTS',
        COUNT(*),
        0
    FROM user_plsql_object_settings
    WHERE type IN (
        'PACKAGE',
        'PACKAGE BODY'
    )
      AND plsql_optimize_level < 2

    UNION ALL

    SELECT
        'DEBUG_ENABLED_OBJECTS',
        COUNT(*),
        0
    FROM user_plsql_object_settings
    WHERE type IN (
        'PACKAGE',
        'PACKAGE BODY'
    )
      AND plsql_debug = 'TRUE'
)
SELECT
    metric_name,
    metric_value,
    CASE
        WHEN metric_value = expected_value
            THEN 'PASS'
        ELSE
            'REVIEW'
    END AS metric_status
FROM metrics
ORDER BY
    CASE metric_name
        WHEN 'PACKAGE_SPECIFICATIONS' THEN 1
        WHEN 'PACKAGE_BODIES' THEN 2
        WHEN 'VALID_PACKAGE_SPECIFICATIONS' THEN 3
        WHEN 'VALID_PACKAGE_BODIES' THEN 4
        WHEN 'TRIGGERS' THEN 5
        WHEN 'ENABLED_TRIGGERS' THEN 6
        WHEN 'PLSQL_COMPILATION_ERRORS' THEN 7
        WHEN 'LOW_OPTIMIZATION_LEVEL_OBJECTS' THEN 8
        WHEN 'DEBUG_ENABLED_OBJECTS' THEN 9
        ELSE 99
    END;

PROMPT
PROMPT ================================================================================
PROMPT INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT REVIEW flags identify metadata conditions that require inspection.
PROMPT They do not prove the existence of a runtime performance problem.
PROMPT Source size and public API counts are inventory characteristics only.
PROMPT Runtime conclusions must be based on measured SQL execution activity.
PROMPT

PROMPT End of PL/SQL runtime inventory report