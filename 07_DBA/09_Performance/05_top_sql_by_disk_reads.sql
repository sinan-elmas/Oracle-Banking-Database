/*
  Script  : 05_top_sql_by_disk_reads.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports SQL statements with the highest cumulative physical reads.
  Run As  : SYSDBA
  Usage   : @05_top_sql_by_disk_reads.sql

  Notes
  -----
  - This script is read-only.
  - DISK_READS represents physical read requests performed by each child cursor.
  - A high total may reflect frequent execution, while a high per-execution
    value may indicate an I/O-intensive access path.
  - Total and per-execution physical reads must be evaluated together.
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
PROMPT Top SQL By Disk Reads Metric Scope

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
PROMPT Top Application SQL By Total Disk Reads

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
        q.disk_reads,
        q.buffer_gets,
        q.rows_processed,
        q.parse_calls,
        q.cpu_time,
        q.elapsed_time,
        q.user_io_wait_time,
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
        AND q.disk_reads > 0
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
        disk_reads AS total_disk_reads,
        ROUND(
            disk_reads / NULLIF(executions, 0),
            2
        ) AS disk_reads_per_execution,
        buffer_gets AS total_buffer_gets,
        ROUND(
            buffer_gets / NULLIF(executions, 0),
            2
        ) AS buffer_gets_per_execution,
        rows_processed,
        ROUND(
            rows_processed / NULLIF(executions, 0),
            2
        ) AS rows_per_execution,
        parse_calls,
        ROUND(cpu_time / 1000000, 4)
            AS total_cpu_seconds,
        ROUND(elapsed_time / 1000000, 4)
            AS total_elapsed_seconds,
        ROUND(user_io_wait_time / 1000000, 4)
            AS user_io_wait_seconds,
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
                disk_reads DESC,
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
    total_disk_reads,
    disk_reads_per_execution,
    total_buffer_gets,
    buffer_gets_per_execution,
    rows_processed,
    rows_per_execution,
    parse_calls,
    total_cpu_seconds,
    total_elapsed_seconds,
    user_io_wait_seconds,
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
PROMPT Top Application SQL By Disk Reads Per Execution

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
        q.disk_reads,
        q.buffer_gets,
        q.rows_processed,
        q.parse_calls,
        q.cpu_time,
        q.elapsed_time,
        q.user_io_wait_time,
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
        AND q.disk_reads > 0
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
        disk_reads AS total_disk_reads,
        ROUND(disk_reads / executions, 2)
            AS disk_reads_per_execution,
        buffer_gets AS total_buffer_gets,
        ROUND(buffer_gets / executions, 2)
            AS buffer_gets_per_execution,
        rows_processed,
        ROUND(rows_processed / executions, 2)
            AS rows_per_execution,
        parse_calls,
        ROUND(cpu_time / 1000000, 4)
            AS total_cpu_seconds,
        ROUND(elapsed_time / 1000000, 4)
            AS total_elapsed_seconds,
        ROUND(user_io_wait_time / 1000000, 4)
            AS user_io_wait_seconds,
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
                disk_reads / executions DESC,
                disk_reads DESC,
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
    total_disk_reads,
    disk_reads_per_execution,
    total_buffer_gets,
    buffer_gets_per_execution,
    rows_processed,
    rows_per_execution,
    parse_calls,
    total_cpu_seconds,
    total_elapsed_seconds,
    user_io_wait_seconds,
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
PROMPT Top Oracle Maintained SQL By Total Disk Reads

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
        q.disk_reads,
        q.buffer_gets,
        q.rows_processed,
        q.user_io_wait_time,
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
        AND q.disk_reads > 0
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
        disk_reads AS total_disk_reads,
        ROUND(
            disk_reads / NULLIF(executions, 0),
            2
        ) AS disk_reads_per_execution,
        buffer_gets AS total_buffer_gets,
        rows_processed,
        ROUND(user_io_wait_time / 1000000, 4)
            AS user_io_wait_seconds,
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
                disk_reads DESC,
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
    total_disk_reads,
    disk_reads_per_execution,
    total_buffer_gets,
    rows_processed,
    user_io_wait_seconds,
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
PROMPT Disk Reads Workload Summary By Schema Category

WITH sql_category AS (
    SELECT
        CASE
            WHEN u.oracle_maintained = 'Y'
            THEN 'ORACLE MAINTAINED'
            ELSE 'APPLICATION OR UNRESOLVED'
        END AS workload_category,
        q.disk_reads,
        q.buffer_gets,
        q.executions,
        q.rows_processed,
        q.user_io_wait_time
    FROM
        v$sql q
        LEFT JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        q.disk_reads > 0
        AND q.sql_id IS NOT NULL
)
SELECT
    workload_category,
    COUNT(*) AS child_cursor_count,
    NVL(SUM(executions), 0) AS executions,
    NVL(SUM(disk_reads), 0) AS total_disk_reads,
    ROUND(
        NVL(SUM(disk_reads), 0)
        / NULLIF(SUM(executions), 0),
        2
    ) AS disk_reads_per_execution,
    NVL(SUM(buffer_gets), 0) AS total_buffer_gets,
    ROUND(NVL(SUM(user_io_wait_time), 0) / 1000000, 4)
        AS user_io_wait_seconds,
    NVL(SUM(rows_processed), 0) AS rows_processed
FROM
    sql_category
GROUP BY
    workload_category
ORDER BY
    total_disk_reads DESC;

PROMPT
PROMPT Top SQL By Disk Reads Completed
