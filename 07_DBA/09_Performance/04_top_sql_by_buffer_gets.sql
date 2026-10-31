
/*
  Script  : 04_top_sql_by_buffer_gets.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports SQL statements with the highest cumulative logical I/O.
  Run As  : SYSDBA
  Usage   : @04_top_sql_by_buffer_gets.sql

  Notes
  -----
  - This script is read-only.
  - BUFFER_GETS represents logical reads performed by each child cursor.
  - A high total may reflect frequent execution rather than an inefficient
    execution plan.
  - Total and per-execution logical I/O must be evaluated together.
  - Application and Oracle-maintained workloads are reported separately.
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
PROMPT Top SQL By Buffer Gets Metric Scope

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
PROMPT Top Application SQL By Total Buffer Gets

WITH sql_rows AS (
    SELECT
        q.sql_id,
        q.child_number,
        q.plan_hash_value,
        q.parsing_schema_name,
        q.executions,
        q.buffer_gets,
        q.disk_reads,
        q.rows_processed,
        q.parse_calls,
        q.cpu_time,
        q.elapsed_time
    FROM
        v$sql q
        LEFT JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        NVL(u.oracle_maintained, 'N') = 'N'
        AND q.buffer_gets > 0
        AND q.sql_id IS NOT NULL
),
ranked_sql AS (
    SELECT
        sql_id,
        child_number AS child_no,
        plan_hash_value AS plan_hash,
        parsing_schema_name AS schema_name,
        executions AS execs,
        buffer_gets,
        ROUND(
            buffer_gets / NULLIF(executions, 0),
            2
        ) AS gets_per_exec,
        disk_reads,
        rows_processed,
        parse_calls AS parses,
        ROUND(cpu_time / 1000000, 4) AS cpu_sec,
        ROUND(elapsed_time / 1000000, 4) AS elapsed_sec,
        ROW_NUMBER() OVER (
            ORDER BY
                buffer_gets DESC,
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
    buffer_gets,
    gets_per_exec,
    disk_reads,
    rows_processed,
    cpu_sec,
    elapsed_sec
FROM
    ranked_sql
WHERE
    row_number_value <= 20
ORDER BY
    row_number_value;

PROMPT
PROMPT Top Application SQL By Buffer Gets Per Execution

WITH sql_rows AS (
    SELECT
        q.sql_id,
        q.child_number,
        q.plan_hash_value,
        q.parsing_schema_name,
        q.executions,
        q.buffer_gets,
        q.disk_reads,
        q.rows_processed,
        q.parse_calls,
        q.cpu_time,
        q.elapsed_time
    FROM
        v$sql q
        LEFT JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        NVL(u.oracle_maintained, 'N') = 'N'
        AND q.buffer_gets > 0
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
        buffer_gets,
        ROUND(
            buffer_gets / executions,
            2
        ) AS gets_per_exec,
        disk_reads,
        rows_processed,
        parse_calls AS parses,
        ROUND(cpu_time / 1000000, 4) AS cpu_sec,
        ROUND(elapsed_time / 1000000, 4) AS elapsed_sec,
        ROW_NUMBER() OVER (
            ORDER BY
                buffer_gets / executions DESC,
                buffer_gets DESC,
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
    buffer_gets,
    gets_per_exec,
    disk_reads,
    rows_processed,
    cpu_sec,
    elapsed_sec
FROM
    ranked_sql
WHERE
    row_number_value <= 20
ORDER BY
    row_number_value;

PROMPT
PROMPT Top Oracle Maintained SQL By Total Buffer Gets

WITH sql_rows AS (
    SELECT
        q.sql_id,
        q.child_number,
        q.plan_hash_value,
        q.parsing_schema_name,
        q.executions,
        q.buffer_gets,
        q.disk_reads,
        q.rows_processed
    FROM
        v$sql q
        JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        u.oracle_maintained = 'Y'
        AND q.buffer_gets > 0
        AND q.sql_id IS NOT NULL
),
ranked_sql AS (
    SELECT
        sql_id,
        child_number AS child_no,
        plan_hash_value AS plan_hash,
        parsing_schema_name AS schema_name,
        executions AS execs,
        buffer_gets,
        ROUND(
            buffer_gets / NULLIF(executions, 0),
            2
        ) AS gets_per_exec,
        disk_reads,
        rows_processed,
        ROW_NUMBER() OVER (
            ORDER BY
                buffer_gets DESC,
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
    buffer_gets,
    gets_per_exec,
    disk_reads,
    rows_processed
FROM
    ranked_sql
WHERE
    row_number_value <= 10
ORDER BY
    row_number_value;

PROMPT
PROMPT Buffer Gets Workload Summary By Schema Category

WITH sql_category AS (
    SELECT
        CASE
            WHEN u.oracle_maintained = 'Y'
            THEN 'ORACLE MAINTAINED'
            ELSE 'APPLICATION OR UNRESOLVED'
        END AS workload_category,
        q.buffer_gets,
        q.disk_reads,
        q.executions,
        q.rows_processed
    FROM
        v$sql q
        LEFT JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        q.buffer_gets > 0
        AND q.sql_id IS NOT NULL
)
SELECT
    workload_category AS category,
    COUNT(*) AS child_count,
    NVL(SUM(executions), 0) AS execs,
    NVL(SUM(buffer_gets), 0) AS buffer_gets,
    ROUND(
        NVL(SUM(buffer_gets), 0)
        / NULLIF(SUM(executions), 0),
        2
    ) AS gets_per_exec,
    NVL(SUM(disk_reads), 0) AS disk_reads,
    NVL(SUM(rows_processed), 0) AS rows_processed
FROM
    sql_category
GROUP BY
    workload_category
ORDER BY
    buffer_gets DESC;

PROMPT
PROMPT Top SQL By Buffer Gets Completed
