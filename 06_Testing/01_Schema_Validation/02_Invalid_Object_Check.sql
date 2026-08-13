-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Schema Validation
-- Script       : 02_Invalid_Object_Check.sql
-- Purpose      : Identify invalid schema objects and summarize object health
-- Scope        : Current application schema
-- Safety       : Read-only
-- Environment  : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- ============================================================================

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 500
SET LINESIZE 220
SET FEEDBACK ON
SET VERIFY OFF
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

PROMPT
PROMPT ================================================================================
PROMPT INVALID OBJECT HEALTH SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN schema_name          FORMAT A20
COLUMN checked_object_count FORMAT 999,999
COLUMN valid_object_count   FORMAT 999,999
COLUMN invalid_object_count FORMAT 999,999
COLUMN health_status        FORMAT A12
COLUMN report_time          FORMAT A20

WITH relevant_objects AS
(
    SELECT
        object_name,
        object_type,
        status
    FROM user_objects
    WHERE object_type IN
          (
              'VIEW',
              'PACKAGE',
              'PACKAGE BODY',
              'PROCEDURE',
              'FUNCTION',
              'TRIGGER',
              'TYPE',
              'TYPE BODY'
          )
)
SELECT
    USER AS schema_name,
    COUNT(*) AS checked_object_count,

    SUM(
        CASE
            WHEN status = 'VALID' THEN 1
            ELSE 0
        END
    ) AS valid_object_count,

    SUM(
        CASE
            WHEN status = 'INVALID' THEN 1
            ELSE 0
        END
    ) AS invalid_object_count,

    CASE
        WHEN SUM(
                 CASE
                     WHEN status = 'INVALID' THEN 1
                     ELSE 0
                 END
             ) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS health_status,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM relevant_objects;

PROMPT
PROMPT ================================================================================
PROMPT INVALID OBJECTS BY TYPE
PROMPT ================================================================================
PROMPT

COLUMN object_type   FORMAT A24
COLUMN invalid_count FORMAT 999,999

SELECT
    object_type,
    COUNT(*) AS invalid_count

FROM user_objects

WHERE status = 'INVALID'
  AND object_type IN
      (
          'VIEW',
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
    object_type;

PROMPT
PROMPT ================================================================================
PROMPT INVALID OBJECT DETAILS
PROMPT ================================================================================
PROMPT

COLUMN object_name   FORMAT A40
COLUMN object_type   FORMAT A24
COLUMN status        FORMAT A10
COLUMN created       FORMAT A20
COLUMN last_ddl_time FORMAT A20

SELECT
    object_name,
    object_type,
    status,

    TO_CHAR(
        created,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS created,

    TO_CHAR(
        last_ddl_time,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS last_ddl_time

FROM user_objects

WHERE status = 'INVALID'
  AND object_type IN
      (
          'VIEW',
          'PACKAGE',
          'PACKAGE BODY',
          'PROCEDURE',
          'FUNCTION',
          'TRIGGER',
          'TYPE',
          'TYPE BODY'
      )

ORDER BY
    object_type,
    object_name;

PROMPT
PROMPT ================================================================================
PROMPT COMPILATION ERROR SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN object_name  FORMAT A40
COLUMN object_type  FORMAT A24
COLUMN error_count  FORMAT 999,999
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

GROUP BY
    name,
    type

ORDER BY
    type,
    name;

PROMPT
PROMPT ================================================================================
PROMPT COMPILATION ERROR DETAILS
PROMPT ================================================================================
PROMPT

COLUMN object_name   FORMAT A40
COLUMN object_type   FORMAT A24
COLUMN line_number   FORMAT 999,999
COLUMN position      FORMAT 999,999
COLUMN error_type    FORMAT A10
COLUMN error_text    FORMAT A100

SELECT
    name AS object_name,
    type AS object_type,
    line AS line_number,
    position,
    attribute AS error_type,
    text AS error_text

FROM user_errors

ORDER BY
    name,
    type,
    sequence;

PROMPT
PROMPT ================================================================================
PROMPT INVALID OBJECT INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT PASS means no invalid executable or dependent schema object was detected.
PROMPT
PROMPT INVALID objects may indicate compilation failures, unresolved dependencies,
PROMPT missing referenced objects, or invalid dependent views.
PROMPT
PROMPT USER_ERRORS reports compilation errors and warnings for stored PL/SQL,
PROMPT triggers, views, and object types where applicable.
PROMPT
PROMPT No object is compiled, altered, created, or dropped by this script.
PROMPT
PROMPT End of invalid object validation report.