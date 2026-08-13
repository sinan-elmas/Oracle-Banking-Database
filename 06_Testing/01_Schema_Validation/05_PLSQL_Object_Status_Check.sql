-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Schema Validation
-- Script       : 05_PLSQL_Object_Status_Check.sql
-- Purpose      : Validate PL/SQL object status, package completeness,
--                trigger state, and compilation health
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
PROMPT PL/SQL OBJECT HEALTH SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN schema_name              FORMAT A20
COLUMN total_plsql_objects      FORMAT 999,999
COLUMN valid_plsql_objects      FORMAT 999,999
COLUMN invalid_plsql_objects    FORMAT 999,999
COLUMN package_count            FORMAT 999,999
COLUMN package_body_count       FORMAT 999,999
COLUMN standalone_procedures    FORMAT 999,999
COLUMN standalone_functions     FORMAT 999,999
COLUMN trigger_count            FORMAT 999,999
COLUMN health_status            FORMAT A12
COLUMN report_time              FORMAT A20

WITH plsql_objects AS
(
    SELECT
        object_name,
        object_type,
        status
    FROM user_objects
    WHERE object_type IN
          (
              'PACKAGE',
              'PACKAGE BODY',
              'PROCEDURE',
              'FUNCTION',
              'TRIGGER',
              'TYPE',
              'TYPE BODY'
          )
),
plsql_health AS
(
    SELECT
        COUNT(*) AS total_plsql_objects,

        SUM(
            CASE
                WHEN status = 'VALID' THEN 1
                ELSE 0
            END
        ) AS valid_plsql_objects,

        SUM(
            CASE
                WHEN status = 'INVALID' THEN 1
                ELSE 0
            END
        ) AS invalid_plsql_objects,

        SUM(
            CASE
                WHEN object_type = 'PACKAGE' THEN 1
                ELSE 0
            END
        ) AS package_count,

        SUM(
            CASE
                WHEN object_type = 'PACKAGE BODY' THEN 1
                ELSE 0
            END
        ) AS package_body_count,

        SUM(
            CASE
                WHEN object_type = 'PROCEDURE' THEN 1
                ELSE 0
            END
        ) AS standalone_procedures,

        SUM(
            CASE
                WHEN object_type = 'FUNCTION' THEN 1
                ELSE 0
            END
        ) AS standalone_functions,

        SUM(
            CASE
                WHEN object_type = 'TRIGGER' THEN 1
                ELSE 0
            END
        ) AS trigger_count

    FROM plsql_objects
)
SELECT
    USER AS schema_name,
    total_plsql_objects,
    valid_plsql_objects,
    invalid_plsql_objects,
    package_count,
    package_body_count,
    standalone_procedures,
    standalone_functions,
    trigger_count,

    CASE
        WHEN invalid_plsql_objects = 0
         AND package_count = package_body_count
            THEN 'PASS'
        ELSE 'FAIL'
    END AS health_status,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM plsql_health;

PROMPT
PROMPT ================================================================================
PROMPT PL/SQL OBJECT TYPE SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN object_type   FORMAT A24
COLUMN object_count  FORMAT 999,999
COLUMN valid_count   FORMAT 999,999
COLUMN invalid_count FORMAT 999,999

SELECT
    object_type,
    COUNT(*) AS object_count,

    SUM(
        CASE
            WHEN status = 'VALID' THEN 1
            ELSE 0
        END
    ) AS valid_count,

    SUM(
        CASE
            WHEN status = 'INVALID' THEN 1
            ELSE 0
        END
    ) AS invalid_count

FROM user_objects

WHERE object_type IN
      (
          'PACKAGE',
          'PACKAGE BODY',
          'PROCEDURE',
          'FUNCTION',
          'TRIGGER',
          'TYPE',
          'TYPE BODY'
      )

GROUP BY
    object_type

ORDER BY
    CASE object_type
        WHEN 'PACKAGE' THEN 1
        WHEN 'PACKAGE BODY' THEN 2
        WHEN 'PROCEDURE' THEN 3
        WHEN 'FUNCTION' THEN 4
        WHEN 'TRIGGER' THEN 5
        WHEN 'TYPE' THEN 6
        WHEN 'TYPE BODY' THEN 7
        ELSE 8
    END;

PROMPT
PROMPT ================================================================================
PROMPT PACKAGE SPECIFICATION AND BODY MATCH
PROMPT ================================================================================
PROMPT

COLUMN package_name        FORMAT A40
COLUMN specification_state FORMAT A18
COLUMN body_state          FORMAT A18
COLUMN package_status      FORMAT A10

WITH package_specs AS
(
    SELECT
        object_name AS package_name,
        status AS specification_status
    FROM user_objects
    WHERE object_type = 'PACKAGE'
),
package_bodies AS
(
    SELECT
        object_name AS package_name,
        status AS body_status
    FROM user_objects
    WHERE object_type = 'PACKAGE BODY'
)
SELECT
    COALESCE(spec.package_name, body.package_name) AS package_name,

    CASE
        WHEN spec.package_name IS NULL
            THEN 'MISSING'
        ELSE spec.specification_status
    END AS specification_state,

    CASE
        WHEN body.package_name IS NULL
            THEN 'MISSING'
        ELSE body.body_status
    END AS body_state,

    CASE
        WHEN spec.package_name IS NOT NULL
         AND body.package_name IS NOT NULL
         AND spec.specification_status = 'VALID'
         AND body.body_status = 'VALID'
            THEN 'PASS'
        ELSE 'FAIL'
    END AS package_status

FROM package_specs spec

FULL OUTER JOIN package_bodies body
  ON body.package_name = spec.package_name

ORDER BY
    package_name;

PROMPT
PROMPT ================================================================================
PROMPT PACKAGE MISMATCH OR INVALID STATUS
PROMPT ================================================================================
PROMPT

COLUMN package_name        FORMAT A40
COLUMN specification_state FORMAT A18
COLUMN body_state          FORMAT A18
COLUMN package_status      FORMAT A10

WITH package_specs AS
(
    SELECT
        object_name AS package_name,
        status AS specification_status
    FROM user_objects
    WHERE object_type = 'PACKAGE'
),
package_bodies AS
(
    SELECT
        object_name AS package_name,
        status AS body_status
    FROM user_objects
    WHERE object_type = 'PACKAGE BODY'
),
package_health AS
(
    SELECT
        COALESCE(spec.package_name, body.package_name) AS package_name,

        CASE
            WHEN spec.package_name IS NULL
                THEN 'MISSING'
            ELSE spec.specification_status
        END AS specification_state,

        CASE
            WHEN body.package_name IS NULL
                THEN 'MISSING'
            ELSE body.body_status
        END AS body_state,

        CASE
            WHEN spec.package_name IS NOT NULL
             AND body.package_name IS NOT NULL
             AND spec.specification_status = 'VALID'
             AND body.body_status = 'VALID'
                THEN 'PASS'
            ELSE 'FAIL'
        END AS package_status

    FROM package_specs spec

    FULL OUTER JOIN package_bodies body
      ON body.package_name = spec.package_name
)
SELECT
    package_name,
    specification_state,
    body_state,
    package_status

FROM package_health

WHERE package_status <> 'PASS'

ORDER BY
    package_name;

PROMPT
PROMPT ================================================================================
PROMPT TRIGGER STATUS SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN trigger_status FORMAT A12
COLUMN trigger_count  FORMAT 999,999

SELECT
    status AS trigger_status,
    COUNT(*) AS trigger_count

FROM user_triggers

GROUP BY
    status

ORDER BY
    status;

PROMPT
PROMPT ================================================================================
PROMPT TRIGGER DETAILS
PROMPT ================================================================================
PROMPT

COLUMN trigger_name       FORMAT A40
COLUMN table_name         FORMAT A30
COLUMN trigger_type       FORMAT A28
COLUMN triggering_event   FORMAT A30
COLUMN status             FORMAT A12
COLUMN action_type        FORMAT A14

SELECT
    trigger_name,
    table_name,
    trigger_type,
    triggering_event,
    status,
    action_type

FROM user_triggers

ORDER BY
    table_name,
    trigger_name;

PROMPT
PROMPT ================================================================================
PROMPT DISABLED TRIGGERS
PROMPT ================================================================================
PROMPT

COLUMN trigger_name     FORMAT A40
COLUMN table_name       FORMAT A30
COLUMN trigger_type     FORMAT A28
COLUMN triggering_event FORMAT A30
COLUMN status           FORMAT A12

SELECT
    trigger_name,
    table_name,
    trigger_type,
    triggering_event,
    status

FROM user_triggers

WHERE status <> 'ENABLED'

ORDER BY
    table_name,
    trigger_name;

PROMPT
PROMPT ================================================================================
PROMPT PL/SQL COMPILATION ERROR SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN object_name   FORMAT A40
COLUMN object_type   FORMAT A24
COLUMN error_count   FORMAT 999,999
COLUMN warning_count FORMAT 999,999

SELECT
    name AS object_name,
    type AS object_type,

    SUM(
        CASE
            WHEN attribute = 'ERROR' THEN 1
            ELSE 0
        END
    ) AS error_count,

    SUM(
        CASE
            WHEN attribute = 'WARNING' THEN 1
            ELSE 0
        END
    ) AS warning_count

FROM user_errors

WHERE type IN
      (
          'PACKAGE',
          'PACKAGE BODY',
          'PROCEDURE',
          'FUNCTION',
          'TRIGGER',
          'TYPE',
          'TYPE BODY'
      )

GROUP BY
    name,
    type

ORDER BY
    type,
    name;

PROMPT
PROMPT ================================================================================
PROMPT PL/SQL OBJECT INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT PASS means all reviewed PL/SQL objects are valid and every package
PROMPT specification has a matching valid package body.
PROMPT
PROMPT Package specification and body counts should normally match for packages
PROMPT that contain executable implementation code.
PROMPT
PROMPT A missing or invalid package body causes the package health check to fail.
PROMPT
PROMPT ENABLED triggers are active and may execute during matching database events.
PROMPT
PROMPT DISABLED triggers remain defined but do not execute.
PROMPT
PROMPT USER_ERRORS reports stored-object compilation errors and warnings.
PROMPT
PROMPT This script validates object metadata only; package and trigger behavior
PROMPT is tested separately in the PL/SQL testing section.
PROMPT
PROMPT No package, trigger, function, procedure, type, or application data is modified.
PROMPT
PROMPT End of PL/SQL object status validation report.