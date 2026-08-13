/*
  Script  : 05_blocking_sessions.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports blocking sessions and lock relationships.
  Run As  : SYSDBA
  Usage   : @05_blocking_sessions.sql

  Notes
  -----
  - This script is read-only.
  - Only current blocking relationships are reported.
  - Historical lock information is not included.
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
PROMPT Blocking Session Monitoring Thresholds

SELECT
    60 AS warning_wait_seconds,
    300 AS critical_wait_seconds
FROM
    dual;

PROMPT
PROMPT Current Blocking And Blocked Session Relationships

SELECT
    blocked.inst_id AS blocked_instance,
    blocked.sid AS blocked_sid,
    blocked.serial# AS blocked_serial,
    blocked.username AS blocked_username,
    blocked.status AS blocked_status,
    blocked.sql_id AS blocked_sql_id,
    blocked.event AS blocked_wait_event,
    blocked.wait_class AS blocked_wait_class,
    blocked.seconds_in_wait,
    blocked.blocking_instance,
    blocked.blocking_session AS blocker_sid,
    blocker.serial# AS blocker_serial,
    blocker.username AS blocker_username,
    blocker.status AS blocker_status,
    blocker.sql_id AS blocker_sql_id,
    blocker.machine AS blocker_machine,
    blocker.program AS blocker_program,
    blocked.final_blocking_instance,
    blocked.final_blocking_session,
    CASE
        WHEN blocked.seconds_in_wait >= 300 THEN 'CRITICAL'
        WHEN blocked.seconds_in_wait >= 60 THEN 'WARNING'
        ELSE 'INFORMATIONAL'
    END AS alert_level
FROM
    gv$session blocked
    LEFT JOIN gv$session blocker
        ON blocker.inst_id = blocked.blocking_instance
       AND blocker.sid = blocked.blocking_session
WHERE
    blocked.blocking_session_status = 'VALID'
    AND blocked.wait_class <> 'Idle'
ORDER BY
    blocked.seconds_in_wait DESC,
    blocked.inst_id,
    blocked.sid;

PROMPT
PROMPT Final Blocking Sessions

WITH blocked_sessions AS (
    SELECT
        s.final_blocking_instance,
        s.final_blocking_session,
        COUNT(*) AS blocked_session_count,
        MAX(s.seconds_in_wait) AS longest_wait_seconds
    FROM
        gv$session s
    WHERE
        s.final_blocking_session_status = 'VALID'
        AND s.wait_class <> 'Idle'
    GROUP BY
        s.final_blocking_instance,
        s.final_blocking_session
)
SELECT
    b.final_blocking_instance AS blocker_instance,
    b.final_blocking_session AS blocker_sid,
    s.serial# AS blocker_serial,
    s.username AS blocker_username,
    s.status AS blocker_status,
    s.sql_id AS blocker_sql_id,
    s.prev_sql_id AS blocker_previous_sql_id,
    s.machine AS blocker_machine,
    s.program AS blocker_program,
    s.module AS blocker_module,
    s.logon_time,
    b.blocked_session_count,
    b.longest_wait_seconds,
    CASE
        WHEN b.longest_wait_seconds >= 300 THEN 'CRITICAL'
        WHEN b.longest_wait_seconds >= 60 THEN 'WARNING'
        ELSE 'INFORMATIONAL'
    END AS alert_level
FROM
    blocked_sessions b
    LEFT JOIN gv$session s
        ON s.inst_id = b.final_blocking_instance
       AND s.sid = b.final_blocking_session
ORDER BY
    b.longest_wait_seconds DESC,
    b.final_blocking_instance,
    b.final_blocking_session;

PROMPT
PROMPT Blocking Sessions With Open Transactions

WITH blocker_sessions AS (
    SELECT DISTINCT
        s.blocking_instance AS blocker_instance,
        s.blocking_session AS blocker_sid
    FROM
        gv$session s
    WHERE
        s.blocking_session_status = 'VALID'
        AND s.wait_class <> 'Idle'
)
SELECT
    bs.blocker_instance,
    bs.blocker_sid,
    s.serial# AS blocker_serial,
    s.username AS blocker_username,
    s.status AS blocker_status,
    s.sql_id AS blocker_sql_id,
    t.start_scn,
    TO_CHAR(t.start_date, 'DD-MON-YYYY HH24:MI:SS') AS transaction_start_time,
    t.used_ublk AS undo_blocks,
    t.used_urec AS undo_records,
    t.log_io,
    t.phy_io,
    t.cr_get,
    t.cr_change
FROM
    blocker_sessions bs
    JOIN gv$session s
        ON s.inst_id = bs.blocker_instance
       AND s.sid = bs.blocker_sid
    LEFT JOIN gv$transaction t
        ON t.inst_id = s.inst_id
       AND t.addr = s.taddr
WHERE
    s.taddr IS NOT NULL
ORDER BY
    t.start_date,
    bs.blocker_instance,
    bs.blocker_sid;

PROMPT
PROMPT Locked Objects Held By Blocking Sessions

WITH blocker_sessions AS (
    SELECT DISTINCT
        s.blocking_instance AS blocker_instance,
        s.blocking_session AS blocker_sid
    FROM
        gv$session s
    WHERE
        s.blocking_session_status = 'VALID'
        AND s.wait_class <> 'Idle'
)
SELECT
    bs.blocker_instance,
    bs.blocker_sid,
    s.serial# AS blocker_serial,
    s.username AS blocker_username,
    o.owner AS object_owner,
    o.object_name,
    o.object_type,
    lo.locked_mode,
    CASE lo.locked_mode
        WHEN 0 THEN 'NONE'
        WHEN 1 THEN 'NULL'
        WHEN 2 THEN 'ROW SHARE'
        WHEN 3 THEN 'ROW EXCLUSIVE'
        WHEN 4 THEN 'SHARE'
        WHEN 5 THEN 'SHARE ROW EXCLUSIVE'
        WHEN 6 THEN 'EXCLUSIVE'
        ELSE 'UNKNOWN'
    END AS locked_mode_description
FROM
    blocker_sessions bs
    JOIN gv$session s
        ON s.inst_id = bs.blocker_instance
       AND s.sid = bs.blocker_sid
    JOIN gv$locked_object lo
        ON lo.inst_id = s.inst_id
       AND lo.session_id = s.sid
    JOIN dba_objects o
        ON o.object_id = lo.object_id
ORDER BY
    bs.blocker_instance,
    bs.blocker_sid,
    o.owner,
    o.object_name;

PROMPT
PROMPT Blocking Session Status Summary

WITH blocked_state AS (
    SELECT
        COUNT(*) AS blocked_session_count,
        COUNT(
            DISTINCT TO_CHAR(blocking_instance)
            || ':'
            || TO_CHAR(blocking_session)
        ) AS direct_blocker_count,
        COUNT(
            DISTINCT TO_CHAR(final_blocking_instance)
            || ':'
            || TO_CHAR(final_blocking_session)
        ) AS final_blocker_count,
        NVL(MAX(seconds_in_wait), 0) AS longest_wait_seconds,
        NVL(
            SUM(
                CASE
                    WHEN seconds_in_wait >= 300 THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS critical_blocked_sessions,
        NVL(
            SUM(
                CASE
                    WHEN seconds_in_wait >= 60
                     AND seconds_in_wait < 300
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS warning_blocked_sessions
    FROM
        gv$session
    WHERE
        blocking_session_status = 'VALID'
        AND wait_class <> 'Idle'
)
SELECT
    blocked_session_count,
    direct_blocker_count,
    final_blocker_count,
    longest_wait_seconds,
    critical_blocked_sessions,
    warning_blocked_sessions,
    CASE
        WHEN critical_blocked_sessions > 0 THEN 'CRITICAL'
        WHEN warning_blocked_sessions > 0 THEN 'WARNING'
        WHEN blocked_session_count > 0 THEN 'BLOCKING DETECTED'
        ELSE 'HEALTHY'
    END AS blocking_session_state,
    CASE
        WHEN critical_blocked_sessions > 0
        THEN 'BLOCKING WAIT EXCEEDS 300 SECONDS'

        WHEN warning_blocked_sessions > 0
        THEN 'BLOCKING WAIT EXCEEDS 60 SECONDS'

        WHEN blocked_session_count > 0
        THEN 'SHORT DURATION BLOCKING DETECTED'

        ELSE 'NO BLOCKING SESSION DETECTED'
    END AS primary_monitoring_message
FROM
    blocked_state;

PROMPT
PROMPT Blocking Session Inventory Completed
