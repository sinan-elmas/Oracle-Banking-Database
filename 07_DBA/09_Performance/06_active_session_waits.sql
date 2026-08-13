/*
  Script  : 06_active_session_waits.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports active foreground sessions, non-idle waits, recent wait
            history, SQL context, and blocking information.
  Run As  : SYSDBA
  Usage   : @06_active_session_waits.sql

  Notes
  -----
  - This script is read-only.
  - The primary report focuses on active foreground sessions owned by
    non-Oracle-maintained users.
  - Oracle-maintained foreground sessions are reported separately.
  - Background processes and idle waits are excluded from the main analysis.
  - SYS foreground activity is not hidden automatically.
  - V$SESSION_WAIT_HISTORY contains only a short in-memory wait history;
    it is not a complete historical repository.
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
PROMPT Active Session Wait Metric Scope

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
PROMPT Active Application Foreground Sessions

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
        s.status,
        s.sql_id,
        s.sql_child_number,
        q.plan_hash_value,
        s.event,
        s.wait_class,
        s.state,
        s.seconds_in_wait,
        s.wait_time_micro,
        s.time_since_last_wait_micro,
        s.blocking_session_status,
        s.blocking_session,
        s.final_blocking_session_status,
        s.final_blocking_session,
        s.module,
        s.action,
        s.machine,
        s.program,
        s.client_identifier,
        s.logon_time,
        q.executions,
        q.rows_processed,
        q.last_active_time,
        q.sql_text
    FROM
        v$session s
        JOIN dba_users u
            ON u.username = s.username
        LEFT JOIN v$sql q
            ON q.sql_id = s.sql_id
           AND q.child_number = s.sql_child_number
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
    status,
    sql_id,
    sql_child_number,
    plan_hash_value,
    CASE
        WHEN state = 'WAITING'
         AND wait_class <> 'Idle'
        THEN 'CURRENTLY WAITING'

        WHEN state = 'WAITING'
         AND wait_class = 'Idle'
        THEN 'IDLE WAIT'

        WHEN state LIKE 'WAITED%'
        THEN 'ON CPU OR RUNNABLE - LAST WAIT SHOWN'

        ELSE 'ON CPU OR RUNNABLE'
    END AS session_activity_state,
    event,
    wait_class,
    state AS wait_state,
    seconds_in_wait,
    ROUND(wait_time_micro / 1000000, 6)
        AS wait_time_seconds,
    ROUND(time_since_last_wait_micro / 1000000, 6)
        AS seconds_since_last_wait,
    blocking_session_status,
    blocking_session,
    final_blocking_session_status,
    final_blocking_session,
    module,
    action,
    machine,
    program,
    client_identifier,
    TO_CHAR(logon_time, 'DD-MON-YYYY HH24:MI:SS')
        AS logon_time,
    executions,
    rows_processed,
    TO_CHAR(last_active_time, 'DD-MON-YYYY HH24:MI:SS')
        AS last_active_time,
    SUBSTR(
        REPLACE(
            REPLACE(sql_text, CHR(10), ' '),
            CHR(13),
            ' '
        ),
        1,
        500
    ) AS sql_text
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
PROMPT Active Application Sessions Currently Waiting

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
    s.sql_child_number,
    q.plan_hash_value,
    s.event,
    s.wait_class,
    s.state AS wait_state,
    s.seconds_in_wait,
    ROUND(s.wait_time_micro / 1000000, 6)
        AS current_wait_seconds,
    s.p1text,
    s.p1,
    s.p2text,
    s.p2,
    s.p3text,
    s.p3,
    s.blocking_session_status,
    s.blocking_session,
    s.final_blocking_session_status,
    s.final_blocking_session,
    s.module,
    s.action,
    s.machine,
    s.program,
    SUBSTR(
        REPLACE(
            REPLACE(q.sql_text, CHR(10), ' '),
            CHR(13),
            ' '
        ),
        1,
        500
    ) AS sql_text
FROM
    v$session s
    JOIN dba_users u
        ON u.username = s.username
    LEFT JOIN v$sql q
        ON q.sql_id = s.sql_id
       AND q.child_number = s.sql_child_number
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
PROMPT Recent Wait History For Active Application Sessions

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
        s.sql_id,
        s.module,
        s.action,
        s.machine,
        s.program
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
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    h.seq# AS wait_sequence,
    h.event#,
    h.event AS wait_event,
    h.p1text,
    h.p1,
    h.p2text,
    h.p2,
    h.p3text,
    h.p3,
    ROUND(h.wait_time / 1000000, 6)
        AS wait_time_seconds,
    s.module,
    s.action,
    s.machine,
    s.program
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
PROMPT Active Oracle Maintained Foreground Sessions

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
    s.status,
    s.sql_id,
    s.sql_child_number,
    q.plan_hash_value,
    CASE
        WHEN s.state = 'WAITING'
         AND s.wait_class <> 'Idle'
        THEN 'CURRENTLY WAITING'

        WHEN s.state LIKE 'WAITED%'
        THEN 'ON CPU OR RUNNABLE - LAST WAIT SHOWN'

        ELSE 'ON CPU OR RUNNABLE'
    END AS session_activity_state,
    s.event,
    s.wait_class,
    s.state AS wait_state,
    s.seconds_in_wait,
    s.blocking_session_status,
    s.blocking_session,
    s.module,
    s.action,
    s.machine,
    s.program,
    TO_CHAR(s.logon_time, 'DD-MON-YYYY HH24:MI:SS')
        AS logon_time,
    SUBSTR(
        REPLACE(
            REPLACE(q.sql_text, CHR(10), ' '),
            CHR(13),
            ' '
        ),
        1,
        500
    ) AS sql_text
FROM
    v$session s
    JOIN dba_users u
        ON u.username = s.username
    LEFT JOIN v$sql q
        ON q.sql_id = s.sql_id
       AND q.child_number = s.sql_child_number
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
PROMPT Active Session Wait Summary

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
PROMPT Active Session Wait Inventory Completed
