/*
  Script  : 03_media_recovery_status.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports media recovery status and files requiring recovery.
  Run As  : SYSDBA
  Usage   : @03_media_recovery_status.sql

  Notes
  -----
  - This script is read-only.
  - Recovery status reflects the current database state.
  - No recovery operations are performed.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 340
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Database And Instance State

SELECT
    d.name AS database_name,
    d.open_mode,
    d.log_mode,
    i.status AS instance_status,
    i.database_status,
    d.current_scn
FROM
    v$database d
    CROSS JOIN v$instance i;

PROMPT
PROMPT Datafile Header Health

SELECT
    h.file#,
    h.tablespace_name,
    h.status,
    h.recover,
    h.fuzzy,
    NVL(h.error, 'NONE') AS header_error,
    h.checkpoint_change#,
    TO_CHAR(h.checkpoint_time, 'DD-MON-YYYY HH24:MI:SS') AS checkpoint_time,
    REGEXP_SUBSTR(h.name, '[^/]+$') AS datafile_name
FROM
    v$datafile_header h
ORDER BY
    h.file#;

PROMPT
PROMPT Datafiles Requiring Restore Or Media Recovery

SELECT
    h.file#,
    h.tablespace_name,
    h.status,
    h.recover,
    h.fuzzy,
    NVL(h.error, 'NONE') AS header_error,
    h.checkpoint_change#,
    TO_CHAR(h.checkpoint_time, 'DD-MON-YYYY HH24:MI:SS') AS checkpoint_time,
    h.name AS datafile_name
FROM
    v$datafile_header h
WHERE
       h.recover = 'YES'
    OR (h.recover IS NULL AND h.error IS NOT NULL)
ORDER BY
    h.file#;

PROMPT
PROMPT Control File Recovery Records

SELECT
    r.file#,
    t.name AS tablespace_name,
    d.status AS datafile_status,
    r.online_status,
    NVL(r.error, 'UNKNOWN') AS recovery_reason,
    r.change# AS recovery_start_scn,
    TO_CHAR(r.time, 'DD-MON-YYYY HH24:MI:SS') AS recovery_start_time,
    d.name AS datafile_name
FROM
    v$recover_file r
    LEFT JOIN v$datafile d
        ON d.file# = r.file#
    LEFT JOIN v$tablespace t
        ON t.ts# = d.ts#
ORDER BY
    r.file#;

PROMPT
PROMPT Datafiles Requiring Status Review

SELECT
    d.file#,
    t.name AS tablespace_name,
    d.status,
    d.enabled,
    d.checkpoint_change#,
    TO_CHAR(d.checkpoint_time, 'DD-MON-YYYY HH24:MI:SS') AS checkpoint_time,
    d.name AS datafile_name
FROM
    v$datafile d
    JOIN v$tablespace t
        ON t.ts# = d.ts#
WHERE
    d.status IN ('RECOVER', 'OFFLINE', 'SYSOFF')
ORDER BY
    d.file#;

PROMPT
PROMPT Active Recovery Progress

WITH recovery_progress AS (
    SELECT
        rp.type,
        rp.item,
        rp.units,
        rp.sofar,
        rp.total,
        CASE
            WHEN rp.total > 0
            THEN ROUND(rp.sofar * 100 / rp.total, 2)
        END AS progress_pct,
        TO_CHAR(rp.start_time, 'DD-MON-YYYY HH24:MI:SS') AS start_time,
        TO_CHAR(rp.timestamp, 'DD-MON-YYYY HH24:MI:SS') AS last_update,
        rp.comments
    FROM
        v$recovery_progress rp
)
SELECT
    type,
    item,
    units,
    sofar,
    total,
    progress_pct,
    start_time,
    last_update,
    comments
FROM
    recovery_progress
UNION ALL
SELECT
    'NO ACTIVE RECOVERY OPERATION' AS type,
    NULL AS item,
    NULL AS units,
    NULL AS sofar,
    NULL AS total,
    NULL AS progress_pct,
    NULL AS start_time,
    NULL AS last_update,
    NULL AS comments
FROM
    dual
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            recovery_progress
    )
ORDER BY
    type,
    item;

PROMPT
PROMPT Media Recovery Status Summary

WITH header_state AS (
    SELECT
        COUNT(*) AS issue_count,
        SUM(
            CASE
                WHEN h.fuzzy = 'YES' THEN 1
                ELSE 0
            END
        ) AS fuzzy_count
    FROM
        v$datafile_header h
    WHERE
           h.recover = 'YES'
        OR (h.recover IS NULL AND h.error IS NOT NULL)
        OR h.fuzzy = 'YES'
),
header_issue_state AS (
    SELECT
        COUNT(*) AS issue_count
    FROM
        v$datafile_header h
    WHERE
           h.recover = 'YES'
        OR (h.recover IS NULL AND h.error IS NOT NULL)
),
recover_file_state AS (
    SELECT
        COUNT(*) AS actionable_count
    FROM
        v$recover_file r
    WHERE
        NVL(r.error, 'UNKNOWN') <> 'OFFLINE NORMAL'
),
datafile_state AS (
    SELECT
        COUNT(*) AS review_count
    FROM
        v$datafile d
    WHERE
        d.status IN ('RECOVER', 'OFFLINE', 'SYSOFF')
),
recovery_progress_state AS (
    SELECT
        COUNT(*) AS progress_record_count
    FROM
        v$recovery_progress
),
database_state AS (
    SELECT
        open_mode
    FROM
        v$database
)
SELECT
    CASE
        WHEN his.issue_count = 0 THEN 'HEALTHY'
        ELSE 'ATTENTION REQUIRED'
    END AS datafile_header_state,
    CASE
        WHEN ds.open_mode = 'READ WRITE'
         AND NVL(hs.fuzzy_count, 0) > 0
         AND his.issue_count = 0
        THEN 'NORMAL FOR OPEN DATABASE'
        WHEN NVL(hs.fuzzy_count, 0) = 0
        THEN 'CONSISTENT'
        ELSE 'REVIEW REQUIRED'
    END AS header_check_state,
    CASE
        WHEN rfs.actionable_count = 0 THEN 'NONE RECORDED'
        ELSE 'RECOVERY REQUIRED'
    END AS media_recovery_state,
    CASE
        WHEN dfs.review_count = 0 THEN 'NORMAL'
        ELSE 'REVIEW REQUIRED'
    END AS datafile_status_state,
    CASE
        WHEN rps.progress_record_count = 0 THEN 'NOT RUNNING'
        ELSE 'IN PROGRESS'
    END AS active_recovery_state,
    CASE
        WHEN his.issue_count = 0
         AND rfs.actionable_count = 0
         AND dfs.review_count = 0
        THEN 'READY'
        ELSE 'ATTENTION REQUIRED'
    END AS database_recovery_readiness
FROM
    header_state hs
    CROSS JOIN header_issue_state his
    CROSS JOIN recover_file_state rfs
    CROSS JOIN datafile_state dfs
    CROSS JOIN recovery_progress_state rps
    CROSS JOIN database_state ds;

PROMPT
PROMPT Media Recovery Status Inventory Completed
