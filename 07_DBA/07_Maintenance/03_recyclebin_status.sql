/*
  Script  : 03_recyclebin_status.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports recycle bin objects, occupied space, and purge candidates.
  Run As  : SYSDBA
  Usage   : @03_recyclebin_status.sql

  Notes
  -----
  - This script is read-only.
  - Suggested PURGE commands are displayed for review only.
  - PURGE is irreversible and prevents Flashback Drop recovery.
  - Object ownership, dependencies, business requirements, and backup
    availability must be reviewed before executing any PURGE command.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 380
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Application Recycle Bin Objects

SELECT
    r.owner,
    u.oracle_maintained,
    r.object_name,
    r.original_name,
    r.type AS object_type,
    r.operation,
    r.ts_name AS tablespace_name,
    r.can_undrop,
    r.can_purge,
    ROUND(
        r.space * NVL(t.block_size, 0) / 1024 / 1024,
        2
    ) AS space_mb,
    r.createtime,
    r.droptime
FROM
    dba_recyclebin r
    JOIN dba_users u
        ON u.username = r.owner
    LEFT JOIN dba_tablespaces t
        ON t.tablespace_name = r.ts_name
WHERE
    u.oracle_maintained = 'N'
ORDER BY
    r.owner,
    r.dropscn DESC,
    r.original_name;

PROMPT
PROMPT Application Recycle Bin Summary By Owner

SELECT
    r.owner,
    COUNT(*) AS recyclebin_object_count,
    ROUND(
        NVL(SUM(r.space * NVL(t.block_size, 0)), 0) / 1024 / 1024,
        2
    ) AS total_space_mb,
    NVL(
        SUM(
            CASE
                WHEN r.can_undrop = 'YES' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS undrop_capable_objects,
    NVL(
        SUM(
            CASE
                WHEN r.can_purge = 'YES' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS purge_capable_objects
FROM
    dba_recyclebin r
    JOIN dba_users u
        ON u.username = r.owner
    LEFT JOIN dba_tablespaces t
        ON t.tablespace_name = r.ts_name
WHERE
    u.oracle_maintained = 'N'
GROUP BY
    r.owner
ORDER BY
    total_space_mb DESC,
    r.owner;

PROMPT
PROMPT Table Purge Candidates For Review

SELECT
    r.owner,
    r.object_name AS recyclebin_name,
    r.original_name,
    r.type AS object_type,
    r.ts_name AS tablespace_name,
    ROUND(
        r.space * NVL(t.block_size, 0) / 1024 / 1024,
        2
    ) AS space_mb,
    r.droptime,
    'PURGE TABLE "' || r.owner || '"."' || r.object_name || '";'
        AS suggested_command,
    'IRREVERSIBLE - REVIEW BEFORE EXECUTION' AS safety_warning
FROM
    dba_recyclebin r
    JOIN dba_users u
        ON u.username = r.owner
    LEFT JOIN dba_tablespaces t
        ON t.tablespace_name = r.ts_name
WHERE
    u.oracle_maintained = 'N'
    AND r.type = 'TABLE'
    AND r.can_undrop = 'YES'
    AND r.can_purge = 'YES'
ORDER BY
    r.space DESC,
    r.owner,
    r.dropscn DESC;

PROMPT
PROMPT Recycle Bin Status Summary

WITH application_recyclebin AS (
    SELECT
        COUNT(*) AS object_count,
        NVL(
            SUM(r.space * NVL(t.block_size, 0)),
            0
        ) AS total_space_bytes,
        NVL(
            SUM(
                CASE
                    WHEN r.can_purge = 'YES' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS purge_capable_object_count,
        NVL(
            SUM(
                CASE
                    WHEN r.type = 'TABLE'
                     AND r.can_undrop = 'YES'
                     AND r.can_purge = 'YES'
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS AS table_purge_candidate_count
    FROM
        dba_recyclebin r
        JOIN dba_users u
            ON u.username = r.owner
        LEFT JOIN dba_tablespaces t
            ON t.tablespace_name = r.ts_name
    WHERE
        u.oracle_maintained = 'N'
),
oracle_recyclebin AS (
    SELECT
        COUNT(*) AS object_count
    FROM
        dba_recyclebin r
        JOIN dba_users u
            ON u.username = r.owner
    WHERE
        u.oracle_maintained = 'Y'
)
SELECT
    a.object_count AS application_recyclebin_objects,
    ROUND(a.total_space_bytes / 1024 / 1024, 2) AS application_space_mb,
    a.purge_capable_object_count,
    a.table_purge_candidate_count,,
    o.object_count AS oracle_maintained_recyclebin_objects,
    CASE
        WHEN a.object_count = 0
        THEN 'EMPTY'
        WHEN a.total_space_bytes >= 1024 * 1024 * 100
        THEN 'REVIEW RECOMMENDED'
        ELSE 'INFORMATIONAL'
    END AS recyclebin_state
FROM
    application_recyclebin a
    CROSS JOIN oracle_recyclebin o;

PROMPT
PROMPT Recycle Bin Inventory Completed
