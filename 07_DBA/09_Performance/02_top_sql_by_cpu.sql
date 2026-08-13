/*
  Script  : 02_top_sql_by_cpu.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports SQL statements with the highest cumulative CPU usage.
  Run As  : SYSDBA
  Usage   : @02_top_sql_by_cpu.sql

  Notes
  -----
  - This script is read-only.
  - V$SQL metrics are cumulative while each child cursor remains in
    the shared SQL area.
  - CPU_TIME is reported by Oracle in microseconds.
  - Total CPU and CPU per execution must be evaluated together.
  - Application and Oracle-maintained workloads are reported separately.
  - CURRENT_PROGRAM represents only a currently matching active session;
    it is not historical attribution.
  - SQL text is limited to preserve readable console output.
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
PROMPT Top SQL By CPU Metric Scope

SELECT
    'CUMULATIVE SHARED-POOL METRICS' AS metric_scope,
    TO_CHAR(i.startup_time, 'DD-MON-YYYY HH24:MI:SS')
        AS instance_startup_time,
    TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
        AS report_time,
    ROUND((SYSDATE - i.startup_time) * 1440, 2)
        AS instance_uptime_minutes
FROM
    v$instance i;

PROMPT
PROMPT Top Application SQL By Total CPU

WITH current_session_program AS (
    SELECT
        s.sql_id,
        s.sql_child_number AS child_number,
        MAX(s.program) AS current_program
    FROM
        v$session s
    WHERE
        s.type = 'USER'
        AND s.status = 'ACTIVE'
        AND s.sql_id IS NOT NULL
    GROUP BY
        s.sql_id,
        s.sql_child_number
),
sql_rows AS (
    SELECT
        q.sql_id,
        q.child_number,
        q.plan_hash_value,
        q.parsing_schema_name,
        u.oracle_maintained,
        q.module,
        q.action,
        csp.current_program,
        q.executions,
        q.cpu_time,
        q.rows_processed,
        q.parse_calls,
        q.buffer_gets,
        q.disk_reads,
        q.users_executing,
        q.last_active_time,
        q.sql_text
    FROM
        v$sql q
        LEFT JOIN dba_users u
            ON u.username = q.parsing_schema_name
        LEFT JOIN current_session_program csp
            ON csp.sql_id = q.sql_id
           AND csp.child_number = q.child_number
    WHERE
        NVL(u.oracle_maintained, 'N') = 'N'
        AND q.cpu_time > 0
        AND q.sql_id IS NOT NULL
),
ranked_sql AS (
    SELECT
        sql_id,
        child_number,
        plan_hash_value,
        parsing_schema_name,
        module,
        action,
        current_program,
        executions,
        ROUND(cpu_time / 1000000, 4) AS total_cpu_seconds,
        ROUND(
            cpu_time
            / NULLIF(executions, 0)
            / 1000000,
            6
        ) AS cpu_seconds_per_execution,
        rows_processed,
        ROUND(
            rows_processed / NULLIF(executions, 0),
            2
        ) AS rows_per_execution,
        parse_calls,
        buffer_gets,
        disk_reads,
        users_executing,
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
        ) AS sql_text,
        ROW_NUMBER() OVER (
            ORDER BY
                cpu_time DESC,
                sql_id,
                child_number
        ) AS row_number_value
    FROM
        sql_rows
)
SELECT
    sql_id,
    child_number,
    plan_hash_value,
    parsing_schema_name,
    module,
    action,
    current_program,
    executions,
    total_cpu_seconds,
    cpu_seconds_per_execution,
    rows_processed,
    rows_per_execution,
    parse_calls,
    buffer_gets,
    disk_reads,
    users_executing,
    last_active_time,
    sql_text
FROM
    ranked_sql
WHERE
    row_number_value <= 20
ORDER BY
    row_number_value;

PROMPT
PROMPT Top Application SQL By CPU Per Execution

WITH current_session_program AS (
    SELECT
        s.sql_id,
        s.sql_child_number AS child_number,
        MAX(s.program) AS current_program
    FROM
        v$session s
    WHERE
        s.type = 'USER'
        AND s.status = 'ACTIVE'
        AND s.sql_id IS NOT NULL
    GROUP BY
        s.sql_id,
        s.sql_child_number
),
sql_rows AS (
    SELECT
        q.sql_id,
        q.child_number,
        q.plan_hash_value,
        q.parsing_schema_name,
        q.module,
        q.action,
        csp.current_program,
        q.executions,
        q.cpu_time,
        q.rows_processed,
        q.parse_calls,
        q.buffer_gets,
        q.disk_reads,
        q.users_executing,
        q.last_active_time,
        q.sql_text
    FROM
        v$sql q
        LEFT JOIN dba_users u
            ON u.username = q.parsing_schema_name
        LEFT JOIN current_session_program csp
            ON csp.sql_id = q.sql_id
           AND csp.child_number = q.child_number
    WHERE
        NVL(u.oracle_maintained, 'N') = 'N'
        AND q.cpu_time > 0
        AND q.executions > 0
        AND q.sql_id IS NOT NULL
),
ranked_sql AS (
    SELECT
        sql_id,
        child_number,
        plan_hash_value,
        parsing_schema_name,
        module,
        action,
        current_program,
        executions,
        ROUND(cpu_time / 1000000, 4) AS total_cpu_seconds,
        ROUND(
            cpu_time
            / executions
            / 1000000,
            6
        ) AS cpu_seconds_per_execution,
        rows_processed,
        ROUND(rows_processed / executions, 2)
            AS rows_per_execution,
        parse_calls,
        buffer_gets,
        disk_reads,
        users_executing,
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
        ) AS sql_text,
        ROW_NUMBER() OVER (
            ORDER BY
                cpu_time / executions DESC,
                cpu_time DESC,
                sql_id,
                child_number
        ) AS row_number_value
    FROM
        sql_rows
)
SELECT
    sql_id,
    child_number,
    plan_hash_value,
    parsing_schema_name,
    module,
    action,
    current_program,
    executions,
    total_cpu_seconds,
    cpu_seconds_per_execution,
    rows_processed,
    rows_per_execution,
    parse_calls,
    buffer_gets,
    disk_reads,
    users_executing,
    last_active_time,
    sql_text
FROM
    ranked_sql
WHERE
    row_number_value <= 20
ORDER BY
    row_number_value;

PROMPT
PROMPT Top Oracle Maintained SQL By Total CPU

WITH current_session_program AS (
    SELECT
        s.sql_id,
        s.sql_child_number AS child_number,
        MAX(s.program) AS current_program
    FROM
        v$session s
    WHERE
        s.sql_id IS NOT NULL
    GROUP BY
        s.sql_id,
        s.sql_child_number
),
sql_rows AS (
    SELECT
        q.sql_id,
        q.child_number,
        q.plan_hash_value,
        q.parsing_schema_name,
        q.module,
        q.action,
        csp.current_program,
        q.executions,
        q.cpu_time,
        q.rows_processed,
        q.users_executing,
        q.last_active_time,
        q.sql_text
    FROM
        v$sql q
        JOIN dba_users u
            ON u.username = q.parsing_schema_name
        LEFT JOIN current_session_program csp
            ON csp.sql_id = q.sql_id
           AND csp.child_number = q.child_number
    WHERE
        u.oracle_maintained = 'Y'
        AND q.cpu_time > 0
        AND q.sql_id IS NOT NULL
),
ranked_sql AS (
    SELECT
        sql_id,
        child_number,
        plan_hash_value,
        parsing_schema_name,
        module,
        action,
        current_program,
        executions,
        ROUND(cpu_time / 1000000, 4) AS total_cpu_seconds,
        ROUND(
            cpu_time
            / NULLIF(executions, 0)
            / 1000000,
            6
        ) AS cpu_seconds_per_execution,
        rows_processed,
        users_executing,
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
        ) AS sql_text,
        ROW_NUMBER() OVER (
            ORDER BY
                cpu_time DESC,
                sql_id,
                child_number
        ) AS row_number_value
    FROM
        sql_rows
)
SELECT
    sql_id,
    child_number,
    plan_hash_value,
    parsing_schema_name,
    module,
    action,
    current_program,
    executions,
    total_cpu_seconds,
    cpu_seconds_per_execution,
    rows_processed,
    users_executing,
    last_active_time,
    sql_text
FROM
    ranked_sql
WHERE
    row_number_value <= 10
ORDER BY
    row_number_value;

PROMPT
PROMPT CPU Workload Summary By Schema Category

WITH sql_category AS (
    SELECT
        CASE
            WHEN u.oracle_maintained = 'Y'
            THEN 'ORACLE MAINTAINED'
            ELSE 'APPLICATION OR UNRESOLVED'
        END AS workload_category,
        q.cpu_time,
        q.executions,
        q.rows_processed
    FROM
        v$sql q
        LEFT JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        q.cpu_time > 0
        AND q.sql_id IS NOT NULL
)
SELECT
    workload_category,
    COUNT(*) AS child_cursor_count,
    NVL(SUM(executions), 0) AS executions,
    ROUND(NVL(SUM(cpu_time), 0) / 1000000, 4)
        AS total_cpu_seconds,
    ROUND(
        NVL(SUM(cpu_time), 0)
        / NULLIF(SUM(executions), 0)
        / 1000000,
        6
    ) AS cpu_seconds_per_execution,
    NVL(SUM(rows_processed), 0) AS rows_processed
FROM
    sql_category
GROUP BY
    workload_category
ORDER BY
    total_cpu_seconds DESC;

PROMPT
PROMPT Top SQL By CPU Completed
