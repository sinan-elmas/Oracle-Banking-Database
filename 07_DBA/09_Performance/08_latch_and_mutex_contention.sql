/*
  Script  : 08_latch_and_mutex_contention.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports cumulative latch and mutex contention indicators.
  Run As  : SYSDBA
  Usage   : @08_latch_and_mutex_contention.sql

  Notes
  -----
  - This script is read-only.
  - V$LATCH and V$MUTEX_SLEEP values are cumulative since instance startup.
  - V$MUTEX_SLEEP_HISTORY is a recent circular in-memory history and is not
    a complete historical repository.
  - Nonzero misses, sleeps, or wait time do not independently prove a
    current bottleneck.
  - Results must be evaluated with uptime, active waits, workload volume,
    SQL activity, and repeated samples.
  - MISS_PCT represents misses divided by gets.
  - SLEEPS_PER_MISS represents sleeps divided by misses.
  - SPIN_SUCCESS_PCT represents spin gets divided by misses.
  - No AWR, ASH, ADDM, DBA_HIST_*, or Diagnostics Pack dependency is used.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 500
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Latch And Mutex Metric Scope

SELECT
    'CUMULATIVE SINCE INSTANCE STARTUP'
        AS cumulative_metric_scope,
    'RECENT CIRCULAR BUFFER - NOT COMPLETE HISTORY'
        AS mutex_history_scope,
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
PROMPT Latch Contention Overview

SELECT
    COUNT(*) AS latch_count,
    NVL(SUM(gets), 0) AS total_gets,
    NVL(SUM(misses), 0) AS total_misses,
    NVL(SUM(sleeps), 0) AS total_sleeps,
    NVL(SUM(spin_gets), 0) AS total_spin_gets,
    ROUND(NVL(SUM(wait_time), 0) / 1000000, 4)
        AS total_wait_seconds,
    ROUND(
        NVL(SUM(wait_time), 0)
        / NULLIF(COUNT(*), 0)
        / 1000000,
        6
    ) AS average_wait_seconds_per_latch,
    ROUND(
        NVL(SUM(misses), 0)
        * 100
        / NULLIF(SUM(gets), 0),
        6
    ) AS miss_pct,
    ROUND(
        NVL(SUM(sleeps), 0)
        / NULLIF(SUM(misses), 0),
        6
    ) AS sleeps_per_miss,
    ROUND(
        NVL(SUM(spin_gets), 0)
        * 100
        / NULLIF(SUM(misses), 0),
        2
    ) AS spin_success_pct
FROM
    v$latch;

PROMPT
PROMPT Top Latches By Total Wait Time

SELECT *
FROM (
    SELECT
        name,
        gets,
        misses,
        sleeps,
        spin_gets,
        immediate_gets,
        immediate_misses,
        ROUND(wait_time / 1000000, 4)
            AS total_wait_seconds,
        ROUND(
            misses * 100 / NULLIF(gets, 0),
            6
        ) AS miss_pct,
        ROUND(
            sleeps / NULLIF(misses, 0),
            6
        ) AS sleeps_per_miss,
        ROUND(
            spin_gets * 100 / NULLIF(misses, 0),
            2
        ) AS spin_success_pct,
        ROUND(
            immediate_misses
            * 100
            / NULLIF(immediate_gets, 0),
            6
        ) AS immediate_miss_pct
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
    ROWNUM <= 30;

PROMPT
PROMPT Top Latches By Sleep Count

SELECT *
FROM (
    SELECT
        name,
        gets,
        misses,
        sleeps,
        spin_gets,
        ROUND(wait_time / 1000000, 4)
            AS total_wait_seconds,
        ROUND(
            misses * 100 / NULLIF(gets, 0),
            6
        ) AS miss_pct,
        ROUND(
            sleeps / NULLIF(misses, 0),
            6
        ) AS sleeps_per_miss,
        ROUND(
            wait_time
            / NULLIF(sleeps, 0)
            / 1000,
            4
        ) AS average_wait_ms_per_sleep
    FROM
        v$latch
    WHERE
        sleeps > 0
    ORDER BY
        sleeps DESC,
        wait_time DESC,
        misses DESC,
        name
)
WHERE
    ROWNUM <= 20;

PROMPT
PROMPT Latches With Immediate Misses

SELECT *
FROM (
    SELECT
        name,
        immediate_gets,
        immediate_misses,
        ROUND(
            immediate_misses
            * 100
            / NULLIF(immediate_gets, 0),
            6
        ) AS immediate_miss_pct,
        gets,
        misses,
        sleeps,
        ROUND(wait_time / 1000000, 4)
            AS total_wait_seconds
    FROM
        v$latch
    WHERE
        immediate_misses > 0
    ORDER BY
        immediate_misses DESC,
        immediate_miss_pct DESC,
        name
)
WHERE
    ROWNUM <= 20;

PROMPT
PROMPT Mutex Sleep Summary By Type

WITH mutex_type_state AS (
    SELECT
        mutex_type,
        SUM(sleeps) AS sleeps,
        SUM(wait_time) AS wait_time_micro,
        COUNT(*) AS location_count
    FROM
        v$mutex_sleep
    GROUP BY
        mutex_type
)
SELECT
    mutex_type,
    location_count,
    sleeps,
    ROUND(wait_time_micro / 1000000, 4)
        AS total_wait_seconds,
    ROUND(
        wait_time_micro
        / NULLIF(sleeps, 0)
        / 1000,
        4
    ) AS average_wait_ms_per_sleep,
    ROUND(
        wait_time_micro
        * 100
        / NULLIF(
              SUM(wait_time_micro) OVER (),
              0
          ),
        2
    ) AS pct_of_mutex_wait_time
FROM
    mutex_type_state
WHERE
       sleeps > 0
    OR wait_time_micro > 0
ORDER BY
    wait_time_micro DESC,
    sleeps DESC,
    mutex_type;

PROMPT
PROMPT Top Mutex Locations By Wait Time

SELECT *
FROM (
    SELECT
        mutex_type,
        location,
        sleeps,
        ROUND(wait_time / 1000000, 4)
            AS total_wait_seconds,
        ROUND(
            wait_time
            / NULLIF(sleeps, 0)
            / 1000,
            4
        ) AS average_wait_ms_per_sleep,
        ROUND(
            wait_time
            * 100
            / NULLIF(
                  SUM(wait_time) OVER (),
                  0
              ),
            2
        ) AS pct_of_mutex_wait_time
    FROM
        v$mutex_sleep
    WHERE
           sleeps > 0
        OR wait_time > 0
    ORDER BY
        wait_time DESC,
        sleeps DESC,
        mutex_type,
        location
)
WHERE
    ROWNUM <= 30;

PROMPT
PROMPT Recent Mutex Sleep History - Circular Buffer, Not Complete History

SELECT *
FROM (
    SELECT
        mutex_identifier,
        TO_CHAR(
            sleep_timestamp,
            'DD-MON-YYYY HH24:MI:SS.FF3'
        ) AS sleep_timestamp,
        mutex_type,
        location,
        requesting_session,
        blocking_session,
        gets,
        sleeps,
        mutex_value
    FROM
        v$mutex_sleep_history
    ORDER BY
        sleep_timestamp DESC
)
WHERE
    ROWNUM <= 30;

PROMPT
PROMPT Current Latch And Mutex Wait Sessions

SELECT
    sid,
    serial#,
    username,
    status,
    sql_id,
    event,
    wait_class,
    state AS wait_state,
    seconds_in_wait,
    blocking_session_status,
    blocking_session,
    module,
    action,
    machine,
    program
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
PROMPT Latch And Mutex Contention Summary

WITH uptime_state AS (
    SELECT
        ROUND((SYSDATE - startup_time) * 1440, 2)
            AS uptime_minutes
    FROM
        v$instance
),
latch_ranked AS (
    SELECT
        name,
        wait_time,
        ROW_NUMBER() OVER (
            ORDER BY
                wait_time DESC,
                sleeps DESC,
                misses DESC,
                name
        ) AS latch_rank,
        SUM(wait_time) OVER () AS total_latch_wait_micro
    FROM
        v$latch
),
latch_share_state AS (
    SELECT
        MAX(
            CASE
                WHEN latch_rank = 1 THEN name
            END
        ) AS top_latch_name,
        MAX(
            CASE
                WHEN latch_rank = 1 THEN wait_time
            END
        ) AS top_latch_wait_micro,
        MAX(total_latch_wait_micro)
            AS total_latch_wait_micro,
        ROUND(
            MAX(
                CASE
                    WHEN latch_rank = 1 THEN wait_time
                END
            )
            * 100
            / NULLIF(MAX(total_latch_wait_micro), 0),
            2
        ) AS top_latch_share_pct,
        ROUND(
            SUM(
                CASE
                    WHEN latch_rank <= 5 THEN wait_time
                    ELSE 0
                END
            )
            * 100
            / NULLIF(MAX(total_latch_wait_micro), 0),
            2
        ) AS top_five_latch_share_pct
    FROM
        latch_ranked
),
latch_state AS (
    SELECT
        COUNT(*) AS latch_count,
        NVL(SUM(gets), 0) AS total_gets,
        NVL(SUM(misses), 0) AS total_misses,
        NVL(SUM(sleeps), 0) AS total_sleeps,
        NVL(SUM(spin_gets), 0) AS total_spin_gets,
        NVL(SUM(wait_time), 0) AS total_wait_micro,
        NVL(
            SUM(
                CASE
                    WHEN sleeps > 0 THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS latches_with_sleeps
    FROM
        v$latch
),
mutex_state AS (
    SELECT
        COUNT(*) AS mutex_location_count,
        NVL(SUM(sleeps), 0) AS total_mutex_sleeps,
        NVL(SUM(wait_time), 0) AS total_mutex_wait_micro,
        NVL(
            SUM(
                CASE
                    WHEN sleeps > 0 THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS mutex_locations_with_sleeps
    FROM
        v$mutex_sleep
),
top_mutex_state AS (
    SELECT
        mutex_type AS top_mutex_type,
        wait_time AS top_mutex_wait_micro
    FROM (
        SELECT
            mutex_type,
            wait_time,
            ROW_NUMBER() OVER (
                ORDER BY
                    wait_time DESC,
                    sleeps DESC,
                    mutex_type,
                    location
            ) AS row_number_value
        FROM
            v$mutex_sleep
        WHERE
               wait_time > 0
            OR sleeps > 0
    )
    WHERE
        row_number_value = 1
),
current_wait_state AS (
    SELECT
        COUNT(*) AS current_contention_waiters
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
    ls.latch_count,
    ls.latches_with_sleeps,
    ls.total_misses,
    ls.total_sleeps,
    ROUND(ls.total_wait_micro / 1000000, 4)
        AS total_latch_wait_seconds,
    ROUND(
        ls.total_wait_micro
        / NULLIF(ls.latch_count, 0)
        / 1000000,
        6
    ) AS average_wait_seconds_per_latch,
    ROUND(
        ls.total_misses
        * 100
        / NULLIF(ls.total_gets, 0),
        6
    ) AS latch_miss_pct,
    ROUND(
        ls.total_sleeps
        / NULLIF(ls.total_misses, 0),
        6
    ) AS latch_sleeps_per_miss,
    ROUND(
        ls.total_spin_gets
        * 100
        / NULLIF(ls.total_misses, 0),
        2
    ) AS latch_spin_success_pct,
    lss.top_latch_name,
    ROUND(lss.top_latch_wait_micro / 1000000, 4)
        AS top_latch_total_wait_seconds,
    lss.top_latch_share_pct,
    lss.top_five_latch_share_pct,
    ms.mutex_location_count,
    ms.mutex_locations_with_sleeps,
    ms.total_mutex_sleeps,
    ROUND(ms.total_mutex_wait_micro / 1000000, 4)
        AS total_mutex_wait_seconds,
    tms.top_mutex_type,
    ROUND(tms.top_mutex_wait_micro / 1000000, 4)
        AS top_mutex_wait_seconds,
    cws.current_contention_waiters,
    CASE
        WHEN cws.current_contention_waiters > 0
        THEN 'CURRENT CONTENTION DETECTED'

        WHEN us.uptime_minutes < 30
        THEN 'CACHE WARM-UP PERIOD'

        WHEN us.uptime_minutes < 120
        THEN 'INSTANCE RECENTLY STARTED'

        WHEN ls.total_wait_micro = 0
         AND ms.total_mutex_wait_micro = 0
        THEN 'NO RECORDED CONTENTION WAIT'

        ELSE 'CUMULATIVE CONTENTION DATA AVAILABLE'
    END AS contention_state,
    CASE
        WHEN cws.current_contention_waiters > 0
        THEN 'REVIEW CURRENT LATCH OR MUTEX WAITING SESSIONS'

        WHEN lss.top_latch_name = 'space background task latch'
         AND cws.current_contention_waiters = 0
        THEN 'BACKGROUND SPACE MANAGEMENT ACTIVITY - NO ACTIVE LATCH CONTENTION DETECTED'

        WHEN us.uptime_minutes < 120
        THEN 'INSTANCE RECENTLY STARTED - INTERPRET CUMULATIVE VALUES CAREFULLY'

        WHEN ls.total_wait_micro = 0
         AND ms.total_mutex_wait_micro = 0
        THEN 'NO LATCH OR MUTEX WAIT TIME RECORDED'

        ELSE 'COMPARE RATIOS AND WAIT GROWTH ACROSS MULTIPLE SAMPLES'
    END AS primary_interpretation
FROM
    uptime_state us
    CROSS JOIN latch_state ls
    CROSS JOIN latch_share_state lss
    CROSS JOIN mutex_state ms
    LEFT JOIN top_mutex_state tms
        ON 1 = 1
    CROSS JOIN current_wait_state cws;

PROMPT
PROMPT Latch And Mutex Contention Inventory Completed
