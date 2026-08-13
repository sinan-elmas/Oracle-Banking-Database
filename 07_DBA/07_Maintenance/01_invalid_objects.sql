/*
  Script  : 01_invalid_objects.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports invalid database objects, compilation errors, and
            reviewable recompilation commands.
  Run As  : SYSDBA
  Usage   : @01_invalid_objects.sql

  Notes
  -----
  - This script is read-only.
  - Generated recompilation commands are displayed for review only.
  - Dependencies and compilation errors should be evaluated before execution.
  - Oracle-maintained and application-owned objects are reported separately.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 360
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Invalid Database Objects

SELECT
    o.owner,
    u.oracle_maintained,
    o.object_name,
    o.subobject_name,
    o.object_type,
    o.status,
    TO_CHAR(o.created, 'DD-MON-YYYY HH24:MI:SS') AS created_time,
    TO_CHAR(o.last_ddl_time, 'DD-MON-YYYY HH24:MI:SS') AS last_ddl_time
FROM
    dba_objects o
    JOIN dba_users u
        ON u.username = o.owner
WHERE
    o.status <> 'VALID'
ORDER BY
    u.oracle_maintained,
    o.owner,
    o.object_type,
    o.object_name,
    o.subobject_name;

PROMPT
PROMPT Invalid Object Summary By Owner And Type

SELECT
    o.owner,
    u.oracle_maintained,
    o.object_type,
    COUNT(*) AS invalid_object_count
FROM
    dba_objects o
    JOIN dba_users u
        ON u.username = o.owner
WHERE
    o.status <> 'VALID'
GROUP BY
    o.owner,
    u.oracle_maintained,
    o.object_type
ORDER BY
    u.oracle_maintained,
    o.owner,
    o.object_type;

PROMPT
PROMPT Compilation Errors For Invalid Objects

SELECT
    e.owner,
    e.name AS object_name,
    e.type AS object_type,
    e.sequence,
    e.line,
    e.position,
    e.attribute,
    e.message_number,
    e.text AS error_text
FROM
    dba_errors e
WHERE
    EXISTS (
        SELECT
            1
        FROM
            dba_objects o
        WHERE
            o.owner = e.owner
            AND o.object_name = e.name
            AND o.object_type = e.type
            AND o.status <> 'VALID'
    )
ORDER BY
    e.owner,
    e.name,
    e.type,
    e.sequence;

PROMPT
PROMPT Recompilation Candidates For Review

SELECT
    o.owner,
    o.object_name,
    o.object_type,
    CASE
        WHEN o.object_type = 'PACKAGE'
        THEN 'ALTER PACKAGE "' || o.owner || '"."' || o.object_name || '" COMPILE;'

        WHEN o.object_type = 'PACKAGE BODY'
        THEN 'ALTER PACKAGE "' || o.owner || '"."' || o.object_name || '" COMPILE BODY;'

        WHEN o.object_type = 'PROCEDURE'
        THEN 'ALTER PROCEDURE "' || o.owner || '"."' || o.object_name || '" COMPILE;'

        WHEN o.object_type = 'FUNCTION'
        THEN 'ALTER FUNCTION "' || o.owner || '"."' || o.object_name || '" COMPILE;'

        WHEN o.object_type = 'VIEW'
        THEN 'ALTER VIEW "' || o.owner || '"."' || o.object_name || '" COMPILE;'

        WHEN o.object_type = 'TRIGGER'
        THEN 'ALTER TRIGGER "' || o.owner || '"."' || o.object_name || '" COMPILE;'

        WHEN o.object_type = 'TYPE'
        THEN 'ALTER TYPE "' || o.owner || '"."' || o.object_name || '" COMPILE;'

        WHEN o.object_type = 'TYPE BODY'
        THEN 'ALTER TYPE "' || o.owner || '"."' || o.object_name || '" COMPILE BODY;'

        ELSE 'MANUAL REVIEW REQUIRED'
    END AS recommended_command
FROM
    dba_objects o
    JOIN dba_users u
        ON u.username = o.owner
WHERE
    o.status <> 'VALID'
    AND u.oracle_maintained = 'N'
ORDER BY
    o.owner,
    o.object_type,
    o.object_name;

PROMPT
PROMPT Invalid Object Status Summary

WITH invalid_state AS (
    SELECT
        COUNT(*) AS total_invalid_objects,
        COUNT(
            DISTINCT CASE
                WHEN u.oracle_maintained = 'N' THEN o.owner
            END
        ) AS affected_application_owners,
        NVL(
            SUM(
                CASE
                    WHEN u.oracle_maintained = 'N' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS application_invalid_objects,
        NVL(
            SUM(
                CASE
                    WHEN u.oracle_maintained = 'Y' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS oracle_invalid_objects
    FROM
        dba_objects o
        JOIN dba_users u
            ON u.username = o.owner
    WHERE
        o.status <> 'VALID'
),
error_state AS (
    SELECT
        COUNT(*) AS compilation_error_count
    FROM
        dba_errors e
    WHERE
        EXISTS (
            SELECT
                1
            FROM
                dba_objects o
            WHERE
                o.owner = e.owner
                AND o.object_name = e.name
                AND o.object_type = e.type
                AND o.status <> 'VALID'
        )
)
SELECT
    i.total_invalid_objects,
    i.affected_application_owners,
    i.application_invalid_objects,
    i.oracle_invalid_objects,
    e.compilation_error_count,
    CASE
        WHEN i.total_invalid_objects = 0
        THEN 'HEALTHY'
        WHEN i.application_invalid_objects > 0
        THEN 'APPLICATION REVIEW REQUIRED'
        ELSE 'ORACLE MAINTAINED OBJECT REVIEW REQUIRED'
    END AS invalid_object_state
FROM
    invalid_state i
    CROSS JOIN error_state e;

PROMPT
PROMPT Invalid Object Inventory Completed
