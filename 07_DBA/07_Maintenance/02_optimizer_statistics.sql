/*
  Script  : 02_optimizer_statistics.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports missing, stale, and locked optimizer statistics.
  Run As  : SYSDBA
  Usage   : @02_optimizer_statistics.sql

  Notes
  -----
  - This script is read-only.
  - Application-owned and Oracle-maintained objects are evaluated separately.
  - Stale statistics depend on Oracle modification monitoring information.
  - Locked statistics may be intentional and are not automatically treated as errors.
  - No statistics are gathered, deleted, locked, or unlocked.
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
PROMPT Application Tables With Stale Optimizer Statistics

SELECT
    s.owner,
    s.table_name,
    s.partition_name,
    s.subpartition_name,
    s.stale_stats,
    s.stattype_locked,
    TO_CHAR(s.last_analyzed, 'DD-MON-YYYY HH24:MI:SS') AS last_analyzed
FROM
    dba_tab_statistics s
    JOIN dba_users u
        ON u.username = s.owner
    JOIN dba_tables t
        ON t.owner = s.owner
       AND t.table_name = s.table_name
WHERE
    u.oracle_maintained = 'N'
    AND t.temporary = 'N'
    AND s.object_type IN ('TABLE', 'PARTITION', 'SUBPARTITION')
    AND s.stale_stats = 'YES'
ORDER BY
    s.owner,
    s.table_name,
    s.partition_name,
    s.subpartition_name;

PROMPT
PROMPT Application Tables With Missing Optimizer Statistics

SELECT
    s.owner,
    s.table_name,
    s.partition_name,
    s.subpartition_name,
    s.stattype_locked
FROM
    dba_tab_statistics s
    JOIN dba_users u
        ON u.username = s.owner
    JOIN dba_tables t
        ON t.owner = s.owner
       AND t.table_name = s.table_name
WHERE
    u.oracle_maintained = 'N'
    AND t.temporary = 'N'
    AND s.object_type IN ('TABLE', 'PARTITION', 'SUBPARTITION')
    AND s.last_analyzed IS NULL
ORDER BY
    s.owner,
    s.table_name,
    s.partition_name,
    s.subpartition_name;

PROMPT
PROMPT Application Tables With Locked Optimizer Statistics

SELECT
    s.owner,
    s.table_name,
    s.partition_name,
    s.subpartition_name,
    s.stattype_locked,
    s.stale_stats,
    TO_CHAR(s.last_analyzed, 'DD-MON-YYYY HH24:MI:SS') AS last_analyzed,
    CASE
        WHEN s.last_analyzed IS NULL
        THEN 'LOCKED WITH MISSING STATISTICS'
        WHEN s.stale_stats = 'YES'
        THEN 'LOCKED WITH STALE STATISTICS'
        ELSE 'LOCKED - INFORMATIONAL'
    END AS maintenance_assessment
FROM
    dba_tab_statistics s
    JOIN dba_users u
        ON u.username = s.owner
    JOIN dba_tables t
        ON t.owner = s.owner
       AND t.table_name = s.table_name
WHERE
    u.oracle_maintained = 'N'
    AND t.temporary = 'N'
    AND s.object_type IN ('TABLE', 'PARTITION', 'SUBPARTITION')
    AND s.stattype_locked IS NOT NULL
ORDER BY
    s.owner,
    s.table_name,
    s.partition_name,
    s.subpartition_name;

PROMPT
PROMPT Application Statistics Summary By Owner

SELECT
    s.owner,
    COUNT(*) AS statistics_records,
    NVL(
        SUM(
            CASE
                WHEN s.stale_stats = 'YES' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS stale_statistics,
    NVL(
        SUM(
            CASE
                WHEN s.last_analyzed IS NULL THEN 1
                ELSE 0
            END
        ),
        0
    ) AS missing_statistics,
    NVL(
        SUM(
            CASE
                WHEN s.stattype_locked IS NOT NULL THEN 1
                ELSE 0
            END
        ),
        0
    ) AS locked_statistics,
    NVL(
        SUM(
            CASE
                WHEN s.stattype_locked IS NOT NULL
                 AND (
                        s.last_analyzed IS NULL
                     OR s.stale_stats = 'YES'
                 )
                THEN 1
                ELSE 0
            END
        ),
        0
    ) AS locked_attention_required
FROM
    dba_tab_statistics s
    JOIN dba_users u
        ON u.username = s.owner
    JOIN dba_tables t
        ON t.owner = s.owner
       AND t.table_name = s.table_name
WHERE
    u.oracle_maintained = 'N'
    AND t.temporary = 'N'
    AND s.object_type IN ('TABLE', 'PARTITION', 'SUBPARTITION')
GROUP BY
    s.owner
ORDER BY
    s.owner;

PROMPT
PROMPT Oracle Maintained Statistics Information

SELECT
    COUNT(*) AS oracle_maintained_records,
    NVL(
        SUM(
            CASE
                WHEN s.stale_stats = 'YES' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS oracle_maintained_stale,
    NVL(
        SUM(
            CASE
                WHEN s.last_analyzed IS NULL THEN 1
                ELSE 0
            END
        ),
        0
    ) AS oracle_maintained_missing,
    NVL(
        SUM(
            CASE
                WHEN s.stattype_locked IS NOT NULL THEN 1
                ELSE 0
            END
        ),
        0
    ) AS oracle_maintained_locked
FROM
    dba_tab_statistics s
    JOIN dba_users u
        ON u.username = s.owner
    LEFT JOIN dba_tables t
        ON t.owner = s.owner
       AND t.table_name = s.table_name
WHERE
    u.oracle_maintained = 'Y'
    AND NVL(t.temporary, 'N') = 'N'
    AND s.object_type IN ('TABLE', 'PARTITION', 'SUBPARTITION');

PROMPT
PROMPT Optimizer Statistics Status Summary

WITH application_statistics AS (
    SELECT
        COUNT(*) AS application_statistics_records,
        NVL(
            SUM(
                CASE
                    WHEN s.stale_stats = 'YES' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS application_stale_statistics,
        NVL(
            SUM(
                CASE
                    WHEN s.last_analyzed IS NULL THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS application_missing_statistics,
        NVL(
            SUM(
                CASE
                    WHEN s.stattype_locked IS NOT NULL THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS application_locked_statistics,
        NVL(
            SUM(
                CASE
                    WHEN s.stattype_locked IS NOT NULL
                     AND (
                            s.last_analyzed IS NULL
                         OR s.stale_stats = 'YES'
                     )
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS locked_attention_required
    FROM
        dba_tab_statistics s
        JOIN dba_users u
            ON u.username = s.owner
        JOIN dba_tables t
            ON t.owner = s.owner
           AND t.table_name = s.table_name
    WHERE
        u.oracle_maintained = 'N'
        AND t.temporary = 'N'
        AND s.object_type IN ('TABLE', 'PARTITION', 'SUBPARTITION')
),
oracle_statistics AS (
    SELECT
        NVL(
            SUM(
                CASE
                    WHEN s.stale_stats = 'YES' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS oracle_maintained_stale_statistics
    FROM
        dba_tab_statistics s
        JOIN dba_users u
            ON u.username = s.owner
        LEFT JOIN dba_tables t
            ON t.owner = s.owner
           AND t.table_name = s.table_name
    WHERE
        u.oracle_maintained = 'Y'
        AND NVL(t.temporary, 'N') = 'N'
        AND s.object_type IN ('TABLE', 'PARTITION', 'SUBPARTITION')
)
SELECT
    a.application_statistics_records,
    a.application_stale_statistics,
    a.application_missing_statistics,
    a.application_locked_statistics,
    a.locked_attention_required,
    o.oracle_maintained_stale_statistics,
    CASE
        WHEN a.application_missing_statistics > 0
        THEN 'APPLICATION MISSING STATISTICS'
        WHEN a.application_stale_statistics > 0
        THEN 'APPLICATION STALE STATISTICS'
        WHEN a.locked_attention_required > 0
        THEN 'LOCKED STATISTICS REVIEW REQUIRED'
        ELSE 'HEALTHY'
    END AS statistics_state
FROM
    application_statistics a
    CROSS JOIN oracle_statistics o;

PROMPT
PROMPT Optimizer Statistics Inventory Completed
