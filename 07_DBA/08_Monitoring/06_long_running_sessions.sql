/*
  Script  : 06_long_running_sessions.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports long-running active sessions.
  Run As  : SYSDBA
  Usage   : @06_long_running_sessions.sql

  Notes
  -----
  - This script is read-only.
  - The report uses the execution-time threshold defined in the query.
  - Completed sessions are not included.
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
PROMPT Long Running Session Monitoring Thresholds

SELECT
    30 AS warning_runtime_minutes,
    60 AS critical_runtime_minutes
FROM
    dual;

PROMPT
PROMPT Long Running Active SQL Executions

SELECT
    s.inst_id,
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    s.sql_child_number,
    TO_CHAR(s.sql_exec_start, 'DD-MON-YYYY HH24:MI:SS')
        AS sql_exec_start,
    ROUND(
        (SYSDATE - CAST(s.sql_exec_start AS DATE)) * 1440,
        2
    ) AS runtime_minutes,
    s.event,
    s.wait_class,
    s.state AS wait_state,
    s.module,
    s.action,
    s.machine,
    s.program,
    s.client_identifier,
    CASE
        WHEN (SYSDATE - CAST(s.sql_exec_start AS DATE)) * 1440 >= 60
        THEN 'CRITICAL'
        ELSE 'WARNING'
    END AS alert_level
FROM
    gv$session s
WHERE
    s.type = 'USER'
    AND s.status = 'ACTIVE'
    AND s.sql_id IS NOT NULL
    AND s.sql_exec_start IS NOT NULL
    AND (SYSDATE - CAST(s.sql_exec_start AS DATE)) * 1440 >= 30
    AND NOT (
        s.sid = (
            SELECT
                sid
            FROM
                v$mystat
            WHERE
                ROWNUM = 1
        )
        AND s.inst_id = (
            SELECT
                instance_number
            FROM
                v$instance
        )
    )
ORDER BY
    runtime_minutes DESC,
    s.inst_id,
    s.sid;

PROMPT
PROMPT Long Running Sessions With SQL Text

WITH long_running_sessions AS (
    SELECT
        s.inst_id,
        s.sid,
        s.serial#,
        s.username,
        s.sql_id,
        s.sql_child_number,
        s.sql_exec_start,
        ROUND(
            (SYSDATE - CAST(s.sql_exec_start AS DATE)) * 1440,
            2
        ) AS runtime_minutes
    FROM
        gv$session s
    WHERE
        s.type = 'USER'
        AND s.status = 'ACTIVE'
        AND s.sql_id IS NOT NULL
        AND s.sql_exec_start IS NOT NULL
        AND (SYSDATE - CAST(s.sql_exec_start AS DATE)) * 1440 >= 30
        AND NOT (
            s.sid = (
                SELECT
                    sid
                FROM
                    v$mystat
                WHERE
                    ROWNUM = 1
            )
            AND s.inst_id = (
                SELECT
                    instance_number
                FROM
                    v$instance
            )
        )
)
SELECT
    l.inst_id,
    l.sid,
    l.serial#,
    l.username,
    l.sql_id,
    l.sql_child_number,
    l.runtime_minutes,
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
    long_running_sessions l
    LEFT JOIN gv$sql q
        ON q.inst_id = l.inst_id
       AND q.sql_id = l.sql_id
       AND q.child_number = l.sql_child_number
ORDER BY
    l.runtime_minutes DESC,
    l.inst_id,
    l.sid;

PROMPT
PROMPT Long Running Sessions With Open Transactions

WITH long_running_sessions AS (
    SELECT
        s.inst_id,
        s.sid,
        s.serial#,
        s.username,
        s.sql_id,
        s.sql_exec_start,
        s.taddr
    FROM
        gv$session s
    WHERE
        s.type = 'USER'
        AND s.status = 'ACTIVE'
        AND s.sql_id IS NOT NULL
        AND s.sql_exec_start IS NOT NULL
        AND (SYSDATE - CAST(s.sql_exec_start AS DATE)) * 1440 >= 30
        AND s.taddr IS NOT NULL
)
SELECT
    l.inst_id,
    l.sid,
    l.serial#,
    l.username,
    l.sql_id,
    TO_CHAR(l.sql_exec_start, 'DD-MON-YYYY HH24:MI:SS')
        AS sql_exec_start,
    TO_CHAR(t.start_date, 'DD-MON-YYYY HH24:MI:SS')
        AS transaction_start_time,
    ROUND((SYSDATE - t.start_date) * 1440, 2)
        AS transaction_age_minutes,
    t.used_ublk AS undo_blocks,
    t.used_urec AS undo_records,
    t.log_io,
    t.phy_io,
    t.cr_get,
    t.cr_change
FROM
    long_running_sessions l
    JOIN gv$transaction t
        ON t.inst_id = l.inst_id
       AND t.addr = l.taddr
ORDER BY
    transaction_age_minutes DESC,
    l.inst_id,
    l.sid;

PROMPT
PROMPT Long Running Open Transactions

SELECT
    s.inst_id,
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    TO_CHAR(t.start_date, 'DD-MON-YYYY HH24:MI:SS')
        AS transaction_start_time,
    ROUND((SYSDATE - t.start_date) * 1440, 2)
        AS transaction_age_minutes,
    t.used_ublk AS undo_blocks,
    t.used_urec AS undo_records,
    s.event,
    s.wait_class,
    s.module,
    s.machine,
    s.program,
    CASE
        WHEN (SYSDATE - t.start_date) * 1440 >= 60
        THEN 'CRITICAL'
        ELSE 'WARNING'
    END AS alert_level
FROM
    gv$transaction t
    JOIN gv$session s
        ON s.inst_id = t.inst_id
       AND s.taddr = t.addr
WHERE
    s.type = 'USER'
    AND (SYSDATE - t.start_date) * 1440 >= 30
ORDER BY
    transaction_age_minutes DESC,
    s.inst_id,
    s.sid;

PROMPT
PROMPT Long Running Session Status Summary

WITH sql_execution_state AS (
    SELECT
        COUNT(*) AS long_running_sql_count,
        NVL(
            SUM(
                CASE
                    WHEN (SYSDATE - CAST(sql_exec_start AS DATE)) * 1440 >= 60
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS critical_sql_count,
        NVL(
            SUM(
                CASE
                    WHEN (SYSDATE - CAST(sql_exec_start AS DATE)) * 1440 >= 30
                     AND (SYSDATE - CAST(sql_exec_start AS DATE)) * 1440 < 60
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS warning_sql_count,
        NVL(
            MAX(
                ROUND(
                    (SYSDATE - CAST(sql_exec_start AS DATE)) * 1440,
                    2
                )
            ),
            0
        ) AS longest_sql_runtime_minutes
    FROM
        gv$session
    WHERE
        type = 'USER'
        AND status = 'ACTIVE'
        AND sql_id IS NOT NULL
        AND sql_exec_start IS NOT NULL
        AND (SYSDATE - CAST(sql_exec_start AS DATE)) * 1440 >= 30
        AND NOT (
            sid = (
                SELECT
                    sid
                FROM
                    v$mystat
                WHERE
                    ROWNUM = 1
            )
            AND inst_id = (
                SELECT
                    instance_number
                FROM
                    v$instance
            )
        )
),
transaction_state AS (
    SELECT
        COUNT(*) AS long_running_transaction_count,
        NVL(
            SUM(
                CASE
                    WHEN (SYSDATE - t.start_date) * 1440 >= 60
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS critical_transaction_count,
        NVL(
            MAX(
                ROUND(
                    (SYSDATE - t.start_date) * 1440,
                    2
                )
            ),
            0
        ) AS longest_transaction_age_minutes
    FROM
        gv$transaction t
        JOIN gv$session s
            ON s.inst_id = t.inst_id
           AND s.taddr = t.addr
    WHERE
        s.type = 'USER'
        AND (SYSDATE - t.start_date) * 1440 >= 30
)
SELECT
    se.long_running_sql_count,
    se.warning_sql_count,
    se.critical_sql_count,
    se.longest_sql_runtime_minutes,
    ts.long_running_transaction_count,
    ts.critical_transaction_count,
    ts.longest_transaction_age_minutes,
    CASE
        WHEN se.critical_sql_count > 0
          OR ts.critical_transaction_count > 0
        THEN 'CRITICAL'

        WHEN se.warning_sql_count > 0
          OR ts.long_running_transaction_count > 0
        THEN 'WARNING'

        ELSE 'HEALTHY'
    END AS long_running_session_state,
    CASE
        WHEN se.critical_sql_count > 0
        THEN 'SQL EXECUTION EXCEEDS 60 MINUTES'

        WHEN ts.critical_transaction_count > 0
        THEN 'OPEN TRANSACTION EXCEEDS 60 MINUTES'

        WHEN se.warning_sql_count > 0
        THEN 'SQL EXECUTION EXCEEDS 30 MINUTES'

        WHEN ts.long_running_transaction_count > 0
        THEN 'OPEN TRANSACTION EXCEEDS 30 MINUTES'

        ELSE 'NO LONG RUNNING SESSION DETECTED'
    END AS primary_monitoring_message
FROM
    sql_execution_state se
    CROSS JOIN transaction_state ts;

PROMPT
PROMPT Long Running Session Inventory Completed
