/*
  Script  : 03_top_sql_by_elapsed_time.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports SQL statements with the highest cumulative elapsed time.
  Run As  : SYSDBA
  Usage   : @03_top_sql_by_elapsed_time.sql

  Notes
  -----
  - This script is read-only.
  - V$SQL metrics are cumulative while each child cursor remains in
    the shared SQL area.
  - ELAPSED_TIME is reported by Oracle in microseconds.
  - Total elapsed time does not necessarily mean one execution ran for
    the reported duration.
  - Total and per-execution elapsed time must be evaluated together.
  - Application and Oracle-maintained workloads are reported separately.
  - CURRENT_PROGRAM is current-session context, not historical attribution.
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
PROMPT Top SQL By Elapsed Time Metric Scope

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
PROMPT Top Application SQL By Total Elapsed Time

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
        q.elapsed_time,
        q.cpu_time,
        q.rows_processed,
        q.parse_calls,
        q.buffer_gets,
        q.disk_reads,
        q.application_wait_time,
        q.concurrency_wait_time,
        q.cluster_wait_time,
        q.user_io_wait_time,
        q.plsql_exec_time,
        q.java_exec_time,
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
        AND q.elapsed_time > 0
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
        ROUND(elapsed_time / 1000000, 4)
            AS total_elapsed_seconds,
        ROUND(
            elapsed_time
            / NULLIF(executions, 0)
            / 1000000,
            6
        ) AS elapsed_seconds_per_execution,
        ROUND(cpu_time / 1000000, 4)
            AS total_cpu_seconds,
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
        ROUND(application_wait_time / 1000000, 4)
            AS application_wait_seconds,
        ROUND(concurrency_wait_time / 1000000, 4)
            AS concurrency_wait_seconds,
        ROUND(cluster_wait_time / 1000000, 4)
            AS cluster_wait_seconds,
        ROUND(user_io_wait_time / 1000000, 4)
            AS user_io_wait_seconds,
        ROUND(plsql_exec_time / 1000000, 4)
            AS plsql_exec_seconds,
        ROUND(java_exec_time / 1000000, 4)
            AS java_exec_seconds,
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
                elapsed_time DESC,
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
    total_elapsed_seconds,
    elapsed_seconds_per_execution,
    total_cpu_seconds,
    cpu_seconds_per_execution,
    rows_processed,
    rows_per_execution,
    parse_calls,
    buffer_gets,
    disk_reads,
    application_wait_seconds,
    concurrency_wait_seconds,
    cluster_wait_seconds,
    user_io_wait_seconds,
    plsql_exec_seconds,
    java_exec_seconds,
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
PROMPT Top Application SQL By Elapsed Time Per Execution

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
        q.elapsed_time,
        q.cpu_time,
        q.rows_processed,
        q.parse_calls,
        q.buffer_gets,
        q.disk_reads,
        q.application_wait_time,
        q.concurrency_wait_time,
        q.cluster_wait_time,
        q.user_io_wait_time,
        q.plsql_exec_time,
        q.java_exec_time,
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
        AND q.elapsed_time > 0
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
        ROUND(elapsed_time / 1000000, 4)
            AS total_elapsed_seconds,
        ROUND(
            elapsed_time / executions / 1000000,
            6
        ) AS elapsed_seconds_per_execution,
        ROUND(cpu_time / 1000000, 4)
            AS total_cpu_seconds,
        ROUND(
            cpu_time / executions / 1000000,
            6
        ) AS cpu_seconds_per_execution,
        rows_processed,
        ROUND(rows_processed / executions, 2)
            AS rows_per_execution,
        parse_calls,
        buffer_gets,
        disk_reads,
        ROUND(application_wait_time / 1000000, 4)
            AS application_wait_seconds,
        ROUND(concurrency_wait_time / 1000000, 4)
            AS concurrency_wait_seconds,
        ROUND(cluster_wait_time / 1000000, 4)
            AS cluster_wait_seconds,
        ROUND(user_io_wait_time / 1000000, 4)
            AS user_io_wait_seconds,
        ROUND(plsql_exec_time / 1000000, 4)
            AS plsql_exec_seconds,
        ROUND(java_exec_time / 1000000, 4)
            AS java_exec_seconds,
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
                elapsed_time / executions DESC,
                elapsed_time DESC,
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
    total_elapsed_seconds,
    elapsed_seconds_per_execution,
    total_cpu_seconds,
    cpu_seconds_per_execution,
    rows_processed,
    rows_per_execution,
    parse_calls,
    buffer_gets,
    disk_reads,
    application_wait_seconds,
    concurrency_wait_seconds,
    cluster_wait_seconds,
    user_io_wait_seconds,
    plsql_exec_seconds,
    java_exec_seconds,
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
PROMPT Top Oracle Maintained SQL By Total Elapsed Time

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
        q.elapsed_time,
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
        AND q.elapsed_time > 0
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
        ROUND(elapsed_time / 1000000, 4)
            AS total_elapsed_seconds,
        ROUND(
            elapsed_time
            / NULLIF(executions, 0)
            / 1000000,
            6
        ) AS elapsed_seconds_per_execution,
        ROUND(cpu_time / 1000000, 4)
            AS total_cpu_seconds,
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
                elapsed_time DESC,
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
    total_elapsed_seconds,
    elapsed_seconds_per_execution,
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
PROMPT Elapsed Time Workload Summary By Schema Category

WITH sql_category AS (
    SELECT
        CASE
            WHEN u.oracle_maintained = 'Y'
            THEN 'ORACLE MAINTAINED'
            ELSE 'APPLICATION OR UNRESOLVED'
        END AS workload_category,
        q.elapsed_time,
        q.cpu_time,
        q.executions,
        q.rows_processed
    FROM
        v$sql q
        LEFT JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        q.elapsed_time > 0
        AND q.sql_id IS NOT NULL
)
SELECT
    workload_category,
    COUNT(*) AS child_cursor_count,
    NVL(SUM(executions), 0) AS executions,
    ROUND(NVL(SUM(elapsed_time), 0) / 1000000, 4)
        AS total_elapsed_seconds,
    ROUND(
        NVL(SUM(elapsed_time), 0)
        / NULLIF(SUM(executions), 0)
        / 1000000,
        6
    ) AS elapsed_seconds_per_execution,
    ROUND(NVL(SUM(cpu_time), 0) / 1000000, 4)
        AS total_cpu_seconds,
    NVL(SUM(rows_processed), 0) AS rows_processed
FROM
    sql_category
GROUP BY
    workload_category
ORDER BY
    total_elapsed_seconds DESC;

PROMPT
PROMPT Top SQL By Elapsed Time Completed
