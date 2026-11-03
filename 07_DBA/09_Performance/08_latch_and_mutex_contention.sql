
/*
  Script  : 08_latch_and_mutex_contention.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports basic latch and mutex contention indicators.
  Run As  : SYSDBA
  Usage   : @08_latch_and_mutex_contention.sql

  Notes
  -----
  - This script is read-only.
  - V$LATCH and V$MUTEX_SLEEP values are cumulative since instance startup.
  - Nonzero misses, sleeps, or wait time do not independently prove a
    current performance bottleneck.
  - Results should be evaluated with instance uptime, active session waits,
    workload volume, and repeated samples.
  - MISS_PCT represents misses divided by gets.
  - No AWR, ASH, ADDM, DBA_HIST_*, or Diagnostics Pack dependency is used.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 220
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Latch And Mutex Metric Scope

SELECT
    TO_CHAR(startup_time, 'DD-MON-YYYY HH24:MI:SS')
        AS instance_startup_time,
    ROUND((SYSDATE - startup_time) * 1440, 2)
        AS instance_uptime_minutes
FROM
    v$instance;


PROMPT
PROMPT Latch Contention Overview

SELECT
    COUNT(*) AS latch_count,
    NVL(SUM(gets), 0) AS total_gets,
    NVL(SUM(misses), 0) AS total_misses,
    NVL(SUM(sleeps), 0) AS total_sleeps,
    ROUND(NVL(SUM(wait_time), 0) / 1000000, 4)
        AS total_wait_seconds,
    ROUND(
        NVL(SUM(misses), 0) * 100
        / NULLIF(SUM(gets), 0),
        4
    ) AS miss_pct
FROM
    v$latch;


PROMPT
PROMPT Top Latches By Total Wait Time

SELECT *
FROM (
    SELECT
        name AS latch_name,
        gets,
        misses,
        sleeps,
        ROUND(wait_time / 1000000, 4)
            AS total_wait_seconds,
        ROUND(
            misses * 100
            / NULLIF(gets, 0),
            4
        ) AS miss_pct
    FROM
        v$latch
    WHERE
           wait_time > 0
        OR misses > 0
        OR sleeps > 0
    ORDER BY
        wait_time DESC,
        sleeps DESC,
        misses DESC,
        name
)
WHERE
    ROWNUM <= 10;


PROMPT
PROMPT Mutex Sleep Summary By Type

SELECT
    mutex_type,
    SUM(sleeps) AS total_sleeps,
    ROUND(
        SUM(wait_time) / 1000000,
        4
    ) AS total_wait_seconds
FROM
    v$mutex_sleep
GROUP BY
    mutex_type
HAVING
       SUM(sleeps) > 0
    OR SUM(wait_time) > 0
ORDER BY
    SUM(wait_time) DESC,
    SUM(sleeps) DESC,
    mutex_type;


PROMPT
PROMPT Current Latch And Mutex Wait Sessions

SELECT
    sid,
    serial#,
    username,
    sql_id,
    event,
    wait_class,
    seconds_in_wait,
    blocking_session
FROM
    v$session
WHERE
    type = 'USER'
    AND status = 'ACTIVE'
    AND state = 'WAITING'
    AND wait_class <> 'Idle'
    AND (
           event LIKE 'latch:%'
        OR event LIKE 'library cache:%'
        OR event LIKE 'cursor:%'
    )
ORDER BY
    seconds_in_wait DESC,
    sid;


PROMPT
PROMPT Latch And Mutex Contention Inventory Completed
