/*
  Script  : 07_system_wait_events.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports cumulative instance-level foreground wait events and
            foreground wait-class activity.
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
        THEN 'CACHE WARM-UP PERIOD'
        WHEN (SYSDATE - i.startup_time) * 1440 < 120
        THEN 'INSTANCE RECENTLY STARTED'
        ELSE 'NORMAL INTERPRETATION WINDOW'
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
        ROUND((SYSDATE - startup_time) * 86400, 2)
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
        ) AS event_rank,
        SUM(time_waited_micro_fg) OVER ()
            AS total_non_idle_wait_micro
    FROM
        v$system_event
    WHERE
        wait_class <> 'Idle'
        AND total_waits_fg > 0
),
wait_state AS (
    SELECT
        COUNT(DISTINCT wait_class) AS wait_class_count,
        COUNT(*) AS foreground_event_count,
        NVL(SUM(total_waits_fg), 0)
            AS total_foreground_waits,
        NVL(SUM(total_timeouts_fg), 0)
            AS total_foreground_timeouts,
        NVL(SUM(time_waited_micro_fg), 0)
            AS total_foreground_wait_micro,
        NVL(
            MAX(
                CASE
                    WHEN total_waits_fg >= 10
                    THEN time_waited_micro_fg
                         / NULLIF(total_waits_fg, 0)
                END
            ),
            0
        ) AS highest_average_wait_micro
    FROM
        event_state
),
top_event_state AS (
    SELECT
        event AS top_wait_event,
        wait_class AS top_wait_class,
        total_waits_fg AS top_event_waits,
        time_waited_micro_fg AS top_event_wait_micro,
        ROUND(
            time_waited_micro_fg
            * 100
            / NULLIF(total_non_idle_wait_micro, 0),
            2
        ) AS top_event_share_pct
    FROM
        event_state
    WHERE
        event_rank = 1
),
top_five_state AS (
    SELECT
        ROUND(
            SUM(time_waited_micro_fg)
            * 100
            / NULLIF(MAX(total_non_idle_wait_micro), 0),
            2
        ) AS top_five_event_share_pct
    FROM
        event_state
    WHERE
        event_rank <= 5
)
SELECT
    us.uptime_minutes,
    CASE
        WHEN us.uptime_minutes < 30
        THEN 'CACHE WARM-UP PERIOD'
        WHEN us.uptime_minutes < 120
        THEN 'INSTANCE RECENTLY STARTED'
        ELSE 'NORMAL INTERPRETATION WINDOW'
    END AS interpretation_window,
    ws.foreground_event_count,
    ws.total_foreground_waits,
    ws.total_foreground_timeouts,
    ROUND(ws.total_foreground_wait_micro / 1000000, 4)
        AS total_foreground_wait_seconds,
    ROUND(
        ws.total_foreground_wait_micro
        / NULLIF(ws.total_foreground_waits, 0)
        / 1000,
        4
    ) AS overall_average_wait_ms,
    ROUND(
        ws.total_foreground_wait_micro
        / 1000000
        / NULLIF(us.uptime_seconds, 0)
        * 100,
        2
    ) AS wait_time_pct_of_single_instance_uptime,
    ROUND(ws.highest_average_wait_micro / 1000, 4)
        AS highest_event_average_wait_ms,
    ws.wait_class_count,
    tes.top_wait_event,
    tes.top_wait_class,
    tes.top_event_waits,
    ROUND(tes.top_event_wait_micro / 1000000, 4)
        AS top_event_total_wait_seconds,
    tes.top_event_share_pct,
    tfs.top_five_event_share_pct,
    CASE
        WHEN ws.foreground_event_count = 0
        THEN 'NO FOREGROUND WAIT RECORDED'
        WHEN us.uptime_minutes < 30
        THEN 'CACHE WARM-UP PERIOD'
        WHEN us.uptime_minutes < 120
        THEN 'INSTANCE RECENTLY STARTED'
        ELSE 'CUMULATIVE WAIT DATA AVAILABLE'
    END AS system_wait_state,
    CASE
        WHEN ws.foreground_event_count = 0
        THEN 'NO NON-IDLE FOREGROUND WAIT EVENT RECORDED'

        WHEN tes.top_wait_event = 'control file heartbeat'
         AND ws.total_foreground_wait_micro / 1000000 < 30
        THEN 'LIGHT WORKLOAD: CONTROL FILE HEARTBEAT DOMINATES CUMULATIVE WAIT TIME'

        WHEN us.uptime_minutes < 30
        THEN 'WAIT DATA IS IN CACHE WARM-UP PERIOD'

        WHEN us.uptime_minutes < 120
        THEN 'INSTANCE RECENTLY STARTED - REVIEW WITH CURRENT SESSION CONTEXT'

        ELSE 'REVIEW TOP EVENTS WITH CURRENT SESSION AND WORKLOAD CONTEXT'
    END AS primary_interpretation
FROM
    uptime_state us
    CROSS JOIN wait_state ws
    LEFT JOIN top_event_state tes
        ON 1 = 1
    CROSS JOIN top_five_state tfs;

PROMPT
PROMPT System Wait Event Inventory Completed
