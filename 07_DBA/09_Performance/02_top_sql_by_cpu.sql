
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
  - Results are reported per child cursor, not per distinct SQL_ID.
  - CPU_TIME is reported by Oracle in microseconds.
  - CPU values are displayed in seconds.
  - Total CPU and CPU per execution must be evaluated together.
  - CPU per execution is NULL when EXECUTIONS is zero.
  - Application and Oracle-maintained workloads are reported separately.
  - SQL text and session details are excluded to keep output readable.
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

WITH sql_rows AS (
    SELECT
        q.sql_id,
        q.child_number,
        q.plan_hash_value,
        q.parsing_schema_name,
        q.executions,
        q.cpu_time,
        q.parse_calls,
        q.buffer_gets,
        q.disk_reads
    FROM
        v$sql q
        LEFT JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        NVL(u.oracle_maintained, 'N') = 'N'
        AND q.cpu_time > 0
        AND q.sql_id IS NOT NULL
),
ranked_sql AS (
    SELECT
        sql_id,
        child_number AS child_no,
        plan_hash_value AS plan_hash,
        parsing_schema_name AS schema_name,
        executions AS execs,
        ROUND(cpu_time / 1000000, 4) AS cpu_sec,
        ROUND(cpu_time / NULLIF(executions, 0) / 1000000, 6)
            AS cpu_per_exec,
        parse_calls AS parses,
        buffer_gets,
        disk_reads,
        ROW_NUMBER() OVER (
            ORDER BY cpu_time DESC, sql_id, child_number
        ) AS row_number_value
    FROM
        sql_rows
)
SELECT
    sql_id,
    child_no,
    plan_hash,
    schema_name,
    execs,
    cpu_sec,
    cpu_per_exec,
    parses,
    buffer_gets,
    disk_reads
FROM
    ranked_sql
WHERE
    row_number_value <= 20
ORDER BY
    row_number_value;

PROMPT
PROMPT Top Application SQL By CPU Per Execution

WITH sql_rows AS (
    SELECT
        q.sql_id,
        q.child_number,
        q.plan_hash_value,
        q.parsing_schema_name,
        q.executions,
        q.cpu_time,
        q.parse_calls,
        q.buffer_gets,
        q.disk_reads
    FROM
        v$sql q
        LEFT JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        NVL(u.oracle_maintained, 'N') = 'N'
        AND q.cpu_time > 0
        AND q.executions > 0
        AND q.sql_id IS NOT NULL
),
ranked_sql AS (
    SELECT
        sql_id,
        child_number AS child_no,
        plan_hash_value AS plan_hash,
        parsing_schema_name AS schema_name,
        executions AS execs,
        ROUND(cpu_time / 1000000, 4) AS cpu_sec,
        ROUND(cpu_time / executions / 1000000, 6)
            AS cpu_per_exec,
        parse_calls AS parses,
        buffer_gets,
        disk_reads,
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
    child_no,
    plan_hash,
    schema_name,
    execs,
    cpu_sec,
    cpu_per_exec,
    parses,
    buffer_gets,
    disk_reads
FROM
    ranked_sql
WHERE
    row_number_value <= 20
ORDER BY
    row_number_value;

PROMPT
PROMPT Top Oracle Maintained SQL By Total CPU

WITH sql_rows AS (
    SELECT
        q.sql_id,
        q.child_number,
        q.plan_hash_value,
        q.parsing_schema_name,
        q.executions,
        q.cpu_time,
        q.parse_calls,
        q.buffer_gets,
        q.disk_reads
    FROM
        v$sql q
        JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        u.oracle_maintained = 'Y'
        AND q.cpu_time > 0
        AND q.sql_id IS NOT NULL
),
ranked_sql AS (
    SELECT
        sql_id,
        child_number AS child_no,
        plan_hash_value AS plan_hash,
        parsing_schema_name AS schema_name,
        executions AS execs,
        ROUND(cpu_time / 1000000, 4) AS cpu_sec,
        ROUND(cpu_time / NULLIF(executions, 0) / 1000000, 6)
            AS cpu_per_exec,
        parse_calls AS parses,
        buffer_gets,
        disk_reads,
        ROW_NUMBER() OVER (
            ORDER BY cpu_time DESC, sql_id, child_number
        ) AS row_number_value
    FROM
        sql_rows
)
SELECT
    sql_id,
    child_no,
    plan_hash,
    schema_name,
    execs,
    cpu_sec,
    cpu_per_exec,
    parses,
    buffer_gets,
    disk_reads
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
    workload_category AS category,
    COUNT(*) AS child_count,
    NVL(SUM(executions), 0) AS execs,
    ROUND(NVL(SUM(cpu_time), 0) / 1000000, 4)
        AS cpu_sec,
    ROUND(
        NVL(SUM(cpu_time), 0)
        / NULLIF(SUM(executions), 0)
        / 1000000,
        6
    ) AS cpu_per_exec,
    NVL(SUM(rows_processed), 0) AS rows
FROM
    sql_category
GROUP BY
    workload_category
ORDER BY
    cpu_sec DESC;

PROMPT
PROMPT Top SQL By CPU Completed
