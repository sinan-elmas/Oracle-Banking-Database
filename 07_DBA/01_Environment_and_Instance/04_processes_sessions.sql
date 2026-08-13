/*
  Script  : 04_processes_sessions.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports process capacity, session activity, waits, and blocking sessions.
  Run As  : SYSDBA
  Usage   : @04_processes_sessions.sql

  Notes
  -----
  - This script is read-only.
  - Session and wait information represents the current instance state.
  - Long-running active sessions use the threshold defined in the query.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 260
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF

PROMPT
PROMPT Process And Session Capacity

SELECT
    resource_name,
    current_utilization,
    max_utilization,
    initial_allocation,
    limit_value,
    CASE
        WHEN REGEXP_LIKE(TRIM(limit_value), '^[0-9]+$')
        THEN ROUND(
            max_utilization / TO_NUMBER(TRIM(limit_value)) * 100,
            2
        )
    END AS max_utilization_pct
FROM
    v$resource_limit
WHERE
    resource_name IN ('processes', 'sessions', 'transactions')
ORDER BY
    CASE resource_name
        WHEN 'processes' THEN 1
        WHEN 'sessions' THEN 2
        WHEN 'transactions' THEN 3
        ELSE 4
    END;

PROMPT
PROMPT Session Summary By Type And Status

SELECT
    type,
    status,
    COUNT(*) AS session_count
FROM
    v$session
GROUP BY
    type,
    status
ORDER BY
    type,
    status;

PROMPT
PROMPT User Session Summary

SELECT
    NVL(username, 'UNKNOWN') AS username,
    status,
    COUNT(*) AS session_count
FROM
    v$session
WHERE
    type = 'USER'
GROUP BY
    NVL(username, 'UNKNOWN'),
    status
ORDER BY
    username,
    status;

PROMPT
PROMPT Current User Sessions

SELECT
    sid,
    serial#,
    username,
    status,
    osuser,
    machine,
    program,
    module,
    service_name,
    TO_CHAR(logon_time, 'DD-MON-YY HH24:MI:SS') AS logon_time,
    last_call_et AS last_call_seconds,
    sql_id
FROM
    v$session
WHERE
    type = 'USER'
    AND username IS NOT NULL
ORDER BY
    status,
    username,
    sid;

PROMPT
PROMPT Long Running Active User Sessions

SELECT
    sid,
    serial#,
    username,
    machine,
    program,
    module,
    sql_id,
    event,
    wait_class,
    last_call_et AS active_seconds,
    TO_CHAR(logon_time, 'DD-MON-YY HH24:MI:SS') AS logon_time
FROM
    v$session
WHERE
    type = 'USER'
    AND username IS NOT NULL
    AND status = 'ACTIVE'
    AND last_call_et >= 300
    AND sid <> SYS_CONTEXT('USERENV', 'SID')
ORDER BY
    last_call_et DESC;

PROMPT
PROMPT Blocking Sessions

SELECT
    sid AS blocked_sid,
    serial# AS blocked_serial,
    username AS blocked_user,
    blocking_instance,
    blocking_session AS blocking_sid,
    blocking_session_status,
    event,
    wait_class,
    seconds_in_wait
FROM
    v$session
WHERE
    blocking_session IS NOT NULL
ORDER BY
    seconds_in_wait DESC;

PROMPT
PROMPT Background Process Summary

SELECT
    process_group,
    COUNT(*) AS process_count
FROM (
    SELECT
        CASE
            WHEN REGEXP_LIKE(b.name, '^ARC[0-9]+$') THEN 'ARCn'
            WHEN REGEXP_LIKE(b.name, '^DBW[0-9]+$') THEN 'DBWn'
            WHEN REGEXP_LIKE(b.name, '^LG[0-9]+$') THEN 'LGnn'
            WHEN REGEXP_LIKE(b.name, '^M[0-9]+$') THEN 'Mnnn'
            WHEN REGEXP_LIKE(b.name, '^P[0-9]+$') THEN 'Pnnn'
            WHEN REGEXP_LIKE(b.name, '^Q[0-9A-Z]+$') THEN 'QMON SLAVES'
            WHEN REGEXP_LIKE(b.name, '^W[0-9]+$') THEN 'Wnnn'
            ELSE b.name
        END AS process_group
    FROM
        v$bgprocess b
    WHERE
        b.paddr <> '00'
)
GROUP BY
    process_group
ORDER BY
    process_group;

PROMPT
PROMPT Top Session Wait Events

SELECT
    event,
    wait_class,
    COUNT(*) AS session_count
FROM
    v$session
WHERE
    status = 'ACTIVE'
    AND wait_class <> 'Idle'
GROUP BY
    event,
    wait_class
ORDER BY
    session_count DESC,
    event
FETCH FIRST 15 ROWS ONLY;

PROMPT
PROMPT Processes And Sessions Inventory Completed
