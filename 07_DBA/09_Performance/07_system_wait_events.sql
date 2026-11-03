
/*
  Script  : 07_system_wait_events.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports cumulative instance-level foreground wait events,
            foreground wait-class activity, timeouts, and summary metrics.
  Run As  : SYSDBA
  Usage   : @07_system_wait_events.sql

  Notes
  -----
  - This script is read-only.
  - V$SYSTEM_EVENT and V$SYSTEM_WAIT_CLASS values are cumulative since
    instance startup and reset after restart.
  - Foreground-specific metrics are used for the main analysis.
  - Idle wait classes are excluded.
  - High cumulative wait time does not independently prove a current bottleneck.
  - Results must be interpreted with uptime, workload volume, timeout counts,
    average wait time, and active-session evidence.
  - Uptime windows are descriptive time categories, not performance diagnoses.
  - Cumulative foreground wait seconds can exceed instance uptime seconds
    because multiple sessions may wait concurrently.
  - No AWR, ASH, ADDM, DBA_HIST_*, or Diagnostics Pack dependency is used.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 460
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT System Wait Event Metric Scope

SELECT
    'CUMULATIVE FOREGROUND WAITS SINCE INSTANCE STARTUP'
        AS metric_scope,
    TO_CHAR(i.startup_time, 'DD-MON-YYYY HH24:MI:SS')
        AS instance_startup_time,
    TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
        AS report_time,
    ROUND((SYSDATE - i.startup_time) * 1440, 2)
        AS instance_uptime_minutes,
    CASE
        WHEN (SYSDATE - i.startup_time) * 1440 < 30
        THEN 'FIRST 30 MINUTES'
        WHEN (SYSDATE - i.startup_time) * 1440 < 120
        THEN 'FIRST 2 HOURS'
        ELSE 'UPTIME 2 HOURS OR MORE'
    END AS interpretation_window
FROM
    v$instance i;

PROMPT
PROMPT Foreground Wait Class Summary

WITH wait_class_state AS (
    SELECT
        wait_class,
        total_waits_fg,
        time_waited_fg,
        SUM(time_waited_fg) OVER () AS total_non_idle_time_waited_fg
    FROM
        v$system_wait_class
    WHERE
        wait_class <> 'Idle'
        AND (
               total_waits_fg > 0
            OR time_waited_fg > 0
        )
)
SELECT
    wait_class,
    total_waits_fg,
    ROUND(time_waited_fg / 100, 4)
        AS total_wait_seconds,
    ROUND(
        time_waited_fg
        / NULLIF(total_waits_fg, 0)
        * 10,
        4
    ) AS average_wait_ms,
    ROUND(
        time_waited_fg
        * 100
        / NULLIF(total_non_idle_time_waited_fg, 0),
        2
    ) AS pct_of_non_idle_wait_time
FROM
    wait_class_state
ORDER BY
    time_waited_fg DESC,
    wait_class;

PROMPT
PROMPT Top Foreground Wait Events By Total Wait Time

SELECT *
FROM (
    SELECT
        event,
        wait_class,
        total_waits_fg,
        total_timeouts_fg,
        ROUND(time_waited_micro_fg / 1000000, 4)
            AS total_wait_seconds,
        ROUND(
            time_waited_micro_fg
            / NULLIF(total_waits_fg, 0)
            / 1000,
            4
        ) AS average_wait_ms,
        ROUND(
            total_timeouts_fg
            * 100
            / NULLIF(total_waits_fg, 0),
            2
        ) AS timeout_pct,
        ROUND(
            time_waited_micro_fg
            * 100
            / NULLIF(
                  SUM(time_waited_micro_fg) OVER (),
                  0
              ),
            2
        ) AS pct_of_reported_wait_time
    FROM
        v$system_event
    WHERE
        wait_class <> 'Idle'
        AND total_waits_fg > 0
    ORDER BY
        time_waited_micro_fg DESC,
        total_waits_fg DESC,
        event
)
WHERE
    ROWNUM <= 30;

PROMPT
PROMPT Top Foreground Wait Events By Average Wait

SELECT *
FROM (
    SELECT
        event,
        wait_class,
        total_waits_fg,
        total_timeouts_fg,
        ROUND(time_waited_micro_fg / 1000000, 4)
            AS total_wait_seconds,
        ROUND(
            time_waited_micro_fg
            / NULLIF(total_waits_fg, 0)
            / 1000,
            4
        ) AS average_wait_ms,
        ROUND(
            total_timeouts_fg
            * 100
            / NULLIF(total_waits_fg, 0),
            2
        ) AS timeout_pct
    FROM
        v$system_event
    WHERE
        wait_class <> 'Idle'
        AND total_waits_fg >= 10
        AND time_waited_micro_fg > 0
    ORDER BY
        time_waited_micro_fg
        / NULLIF(total_waits_fg, 0) DESC,
        time_waited_micro_fg DESC,
        event
)
WHERE
    ROWNUM <= 20;

PROMPT
PROMPT Foreground Wait Events With Timeouts

SELECT *
FROM (
    SELECT
        event,
        wait_class,
        total_waits_fg,
        total_timeouts_fg,
        ROUND(
            total_timeouts_fg
            * 100
            / NULLIF(total_waits_fg, 0),
            2
        ) AS timeout_pct,
        ROUND(time_waited_micro_fg / 1000000, 4)
            AS total_wait_seconds,
        ROUND(
            time_waited_micro_fg
            / NULLIF(total_waits_fg, 0)
            / 1000,
            4
        ) AS average_wait_ms
    FROM
        v$system_event
    WHERE
        wait_class <> 'Idle'
        AND total_timeouts_fg > 0
    ORDER BY
        total_timeouts_fg DESC,
        timeout_pct DESC,
        event
)
WHERE
    ROWNUM <= 20;

PROMPT
PROMPT System Wait Event Summary

WITH uptime_state AS (
    SELECT
        (SYSDATE - startup_time) * 86400
            AS uptime_seconds,
        ROUND((SYSDATE - startup_time) * 1440, 2)
            AS uptime_minutes
    FROM
        v$instance
),
event_state AS (
    SELECT
        event,
        wait_class,
        total_waits_fg,
        total_timeouts_fg,
        time_waited_micro_fg,
        ROW_NUMBER() OVER (
            ORDER BY
                time_waited_micro_fg DESC,
                total_waits_fg DESC,
                event
        ) AS event_rank
    FROM
        v$system_event
    WHERE
        wait_class <> 'Idle'
        AND total_waits_fg > 0
),
wait_state AS (
    SELECT
        COUNT(*) AS foreground_event_count,
        NVL(SUM(total_waits_fg), 0)
            AS total_foreground_waits,
        NVL(SUM(total_timeouts_fg), 0)
            AS total_foreground_timeouts,
        NVL(SUM(time_waited_micro_fg), 0)
            AS total_foreground_wait_micro
    FROM
        event_state
),
top_event_state AS (
    SELECT
        event AS top_wait_event,
        wait_class AS top_wait_class
    FROM
        event_state
    WHERE
        event_rank = 1
)
SELECT
    us.uptime_minutes,
    CASE
        WHEN us.uptime_minutes < 30
        THEN 'FIRST 30 MINUTES'
        WHEN us.uptime_minutes < 120
        THEN 'FIRST 2 HOURS'
        ELSE 'UPTIME 2 HOURS OR MORE'
    END AS interpretation_window,
    ws.foreground_event_count,
    ws.total_foreground_waits,
    ws.total_foreground_timeouts,
    ROUND(ws.total_foreground_wait_micro / 1000000, 4)
        AS total_fg_wait_sec,
    ROUND(
        ws.total_foreground_wait_micro
        / NULLIF(ws.total_foreground_waits, 0)
        / 1000,
        4
    ) AS avg_fg_wait_ms,
    ROUND(
        ws.total_foreground_wait_micro
        / 1000000
        / NULLIF(us.uptime_seconds, 0),
        4
    ) AS fg_wait_sec_per_uptime_sec,
    tes.top_wait_event
FROM
    uptime_state us
    CROSS JOIN wait_state ws
    LEFT JOIN top_event_state tes
        ON 1 = 1;

PROMPT
PROMPT System Wait Event Inventory Completed
