
/*
  Script  : 06_active_session_waits.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports active foreground sessions, non-idle waits,
            recent wait history, blocking information, and
            blocking/blocked session relationships.
  Run As  : SYSDBA
  Usage   : @06_active_session_waits.sql

  Notes
  -----
  - This script is read-only.
  - Active application sessions are reported separately from
    Oracle-maintained foreground sessions.
  - Background processes are excluded from the main reports.
  - The current SQLcl session is excluded from session reports.
  - The recent wait history report includes both ACTIVE and
    INACTIVE application sessions.
  - V$SESSION_WAIT_HISTORY contains only a short in-memory
    wait history, not a complete historical repository.
  - Blocking relationships are reported separately, including
    INACTIVE blocking sessions when available.
  - SYS foreground activity is not hidden automatically from
    the Oracle-maintained session report.
  - No AWR, ASH, ADDM, DBA_HIST_*, or Diagnostics Pack
    dependency is used.
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
PROMPT ============================================================
PROMPT 1. Active Session Wait Metric Scope
PROMPT ============================================================

SELECT
    'CURRENT SESSION STATE AND SHORT IN-MEMORY WAIT HISTORY'
        AS metric_scope,
    TO_CHAR(i.startup_time, 'DD-MON-YYYY HH24:MI:SS')
        AS instance_startup_time,
    TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
        AS report_time,
    ROUND((SYSDATE - i.startup_time) * 1440, 2)
        AS instance_uptime_minutes
FROM
    v$instance i;


PROMPT
PROMPT ============================================================
PROMPT 2. Active Application Foreground Sessions
PROMPT ============================================================

WITH current_session AS (
    SELECT
        sid AS current_sid
    FROM
        v$mystat
    WHERE
        ROWNUM = 1
),
active_sessions AS (
    SELECT
        s.sid,
        s.serial#,
        s.username,
        s.sql_id,
        s.event,
        s.wait_class,
        s.state,
        s.seconds_in_wait,
        s.blocking_session
    FROM
        v$session s
        JOIN dba_users u
            ON u.username = s.username
        CROSS JOIN current_session cs
    WHERE
        s.type = 'USER'
        AND s.status = 'ACTIVE'
        AND s.sid <> cs.current_sid
        AND u.oracle_maintained = 'N'
)
SELECT
    sid,
    serial#,
    username,
    sql_id,
    CASE
        WHEN state = 'WAITING'
         AND wait_class <> 'Idle'
        THEN 'CURRENTLY WAITING'

        WHEN state = 'WAITING'
         AND wait_class = 'Idle'
        THEN 'IDLE WAIT'

        WHEN state LIKE 'WAITED%'
        THEN 'ON CPU / LAST WAIT'

        ELSE 'ON CPU / RUNNABLE'
    END AS activity_state,
    SUBSTR(event, 1, 35) AS event,
    wait_class,
    state AS wait_state,
    seconds_in_wait,
    blocking_session
FROM
    active_sessions
ORDER BY
    CASE
        WHEN state = 'WAITING'
         AND wait_class <> 'Idle'
        THEN 1
        ELSE 2
    END,
    seconds_in_wait DESC,
    sid;


PROMPT
PROMPT ============================================================
PROMPT 3. Active Application Sessions Currently Waiting
PROMPT ============================================================

WITH current_session AS (
    SELECT
        sid AS current_sid
    FROM
        v$mystat
    WHERE
        ROWNUM = 1
)
SELECT
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    SUBSTR(s.event, 1, 35) AS event,
    s.wait_class,
    s.state AS wait_state,
    s.seconds_in_wait,
    ROUND(s.wait_time_micro / 1000000, 3) AS wait_sec,
    s.blocking_session
FROM
    v$session s
    JOIN dba_users u
        ON u.username = s.username
    CROSS JOIN current_session cs
WHERE
    s.type = 'USER'
    AND s.status = 'ACTIVE'
    AND s.sid <> cs.current_sid
    AND u.oracle_maintained = 'N'
    AND s.state = 'WAITING'
    AND s.wait_class <> 'Idle'
ORDER BY
    s.seconds_in_wait DESC,
    s.sid;


PROMPT
PROMPT ============================================================
PROMPT 4. Recent Wait History For Application Sessions
PROMPT ============================================================

WITH current_session AS (
    SELECT
        sid AS current_sid
    FROM
        v$mystat
    WHERE
        ROWNUM = 1
),
application_sessions AS (
    SELECT
        s.sid,
        s.serial#,
        s.username,
        s.status,
        s.sql_id
    FROM
        v$session s
        JOIN dba_users u
            ON u.username = s.username
        CROSS JOIN current_session cs
    WHERE
        s.type = 'USER'
        AND s.sid <> cs.current_sid
        AND u.oracle_maintained = 'N'
)
SELECT
    s.sid,
    s.serial#,
    s.username,
    s.status AS session_status,
    s.sql_id,
    h.seq# AS wait_seq,
    SUBSTR(h.event, 1, 35) AS wait_event,
    ROUND(h.wait_time / 1000000, 3) AS wait_sec
FROM
    application_sessions s
    JOIN v$session_wait_history h
        ON h.sid = s.sid
WHERE
    h.wait_time > 0
    AND h.event NOT IN (
        'SQL*Net message from client',
        'SQL*Net message to client'
    )
ORDER BY
    s.sid,
    h.seq#;


PROMPT
PROMPT ============================================================
PROMPT 5. Active Oracle Maintained Foreground Sessions
PROMPT ============================================================

WITH current_session AS (
    SELECT
        sid AS current_sid
    FROM
        v$mystat
    WHERE
        ROWNUM = 1
)
SELECT
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    SUBSTR(s.event, 1, 35) AS event,
    s.wait_class,
    s.state AS wait_state,
    s.seconds_in_wait,
    s.blocking_session
FROM
    v$session s
    JOIN dba_users u
        ON u.username = s.username
    CROSS JOIN current_session cs
WHERE
    s.type = 'USER'
    AND s.status = 'ACTIVE'
    AND s.sid <> cs.current_sid
    AND u.oracle_maintained = 'Y'
ORDER BY
    CASE
        WHEN s.state = 'WAITING'
         AND s.wait_class <> 'Idle'
        THEN 1
        ELSE 2
    END,
    s.seconds_in_wait DESC,
    s.sid;


PROMPT
PROMPT ============================================================
PROMPT 6. Active Session Wait Summary
PROMPT ============================================================

WITH current_session AS (
    SELECT
        sid AS current_sid
    FROM
        v$mystat
    WHERE
        ROWNUM = 1
),
session_state AS (
    SELECT
        CASE
            WHEN u.oracle_maintained = 'Y'
            THEN 'ORACLE MAINTAINED'
            ELSE 'APPLICATION'
        END AS workload_category,
        s.state,
        s.wait_class,
        s.blocking_session_status
    FROM
        v$session s
        JOIN dba_users u
            ON u.username = s.username
        CROSS JOIN current_session cs
    WHERE
        s.type = 'USER'
        AND s.status = 'ACTIVE'
        AND s.sid <> cs.current_sid
),
summary_state AS (
    SELECT
        NVL(
            SUM(
                CASE
                    WHEN workload_category = 'APPLICATION'
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS active_application_sessions,

        NVL(
            SUM(
                CASE
                    WHEN workload_category = 'ORACLE MAINTAINED'
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS active_oracle_sessions,

        NVL(
            SUM(
                CASE
                    WHEN workload_category = 'APPLICATION'
                     AND state = 'WAITING'
                     AND wait_class <> 'Idle'
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS waiting_application_sessions,

        NVL(
            SUM(
                CASE
                    WHEN workload_category = 'ORACLE MAINTAINED'
                     AND state = 'WAITING'
                     AND wait_class <> 'Idle'
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS waiting_oracle_sessions,

        NVL(
            SUM(
                CASE
                    WHEN blocking_session_status = 'VALID'
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS blocked_active_sessions
    FROM
        session_state
)
SELECT
    active_application_sessions,
    active_oracle_sessions,
    waiting_application_sessions,
    waiting_oracle_sessions,
    blocked_active_sessions,
    CASE
        WHEN blocked_active_sessions > 0
        THEN 'BLOCKING DETECTED'

        WHEN waiting_application_sessions > 0
        THEN 'APPLICATION WAITS DETECTED'

        WHEN waiting_oracle_sessions > 0
        THEN 'ORACLE MAINTAINED WAITS DETECTED'

        WHEN active_application_sessions > 0
          OR active_oracle_sessions > 0
        THEN 'ACTIVE SESSIONS - NO NON-IDLE WAIT'

        ELSE 'NO ACTIVE FOREGROUND SESSION'
    END AS active_session_wait_state
FROM
    summary_state;


PROMPT
PROMPT ============================================================
PROMPT 7. Blocking and Blocked Application Sessions
PROMPT ============================================================

WITH current_session AS (
    SELECT
        sid AS current_sid
    FROM
        v$mystat
    WHERE
        ROWNUM = 1
)
SELECT
    w.sid AS waiting_sid,
    w.username AS waiting_user,
    SUBSTR(w.event, 1, 30) AS wait_event,
    w.seconds_in_wait AS wait_sec,
    b.sid AS blocking_sid,
    b.username AS blocking_user,
    b.status AS blocking_status,
    CASE
        WHEN t.addr IS NOT NULL
        THEN 'YES'
        ELSE 'NO'
    END AS open_tx
FROM
    v$session w
    JOIN dba_users u
        ON u.username = w.username
    CROSS JOIN current_session cs
    LEFT JOIN v$session b
        ON b.sid = w.blocking_session
    LEFT JOIN v$transaction t
        ON t.addr = b.taddr
WHERE
    w.type = 'USER'
    AND w.sid <> cs.current_sid
    AND u.oracle_maintained = 'N'
    AND w.blocking_session_status = 'VALID'
ORDER BY
    w.seconds_in_wait DESC,
    w.sid;

PROMPT
PROMPT ============================================================
PROMPT Active Session Wait Inventory Completed
PROMPT ============================================================
