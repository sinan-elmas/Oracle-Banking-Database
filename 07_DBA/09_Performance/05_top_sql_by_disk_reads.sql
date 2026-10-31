
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

WITH sql_rows AS (
    SELECT
        q.sql_id,
        q.child_number,
        q.plan_hash_value,
        q.parsing_schema_name,
        q.executions,
        q.disk_reads,
        q.buffer_gets,
        q.rows_processed,
        q.cpu_time,
        q.elapsed_time,
        q.user_io_wait_time
    FROM
        v$sql q
        LEFT JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        NVL(u.oracle_maintained, 'N') = 'N'
        AND q.disk_reads > 0
        AND q.sql_id IS NOT NULL
),
ranked_sql AS (
    SELECT
        sql_id,
        child_number AS child_no,
        plan_hash_value AS plan_hash,
        parsing_schema_name AS schema_name,
        executions AS execs,
        disk_reads,
        ROUND(
            disk_reads / NULLIF(executions, 0),
            2
        ) AS reads_per_exec,
        buffer_gets,
        rows_processed,
        ROUND(elapsed_time / 1000000, 4) AS elapsed_sec,
        ROUND(user_io_wait_time / 1000000, 4) AS io_wait_sec,
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
    child_no,
    plan_hash,
    schema_name,
    execs,
    disk_reads,
    reads_per_exec,
    buffer_gets,
    rows_processed,
    elapsed_sec,
    io_wait_sec
FROM
    ranked_sql
WHERE
    row_number_value <= 20
ORDER BY
    row_number_value;

PROMPT
PROMPT Top Application SQL By Disk Reads Per Execution

WITH sql_rows AS (
    SELECT
        q.sql_id,
        q.child_number,
        q.plan_hash_value,
        q.parsing_schema_name,
        q.executions,
        q.disk_reads,
        q.buffer_gets,
        q.rows_processed,
        q.cpu_time,
        q.elapsed_time,
        q.user_io_wait_time
    FROM
        v$sql q
        LEFT JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        NVL(u.oracle_maintained, 'N') = 'N'
        AND q.disk_reads > 0
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
        disk_reads,
        ROUND(
            disk_reads / executions,
            2
        ) AS reads_per_exec,
        buffer_gets,
        rows_processed,
        ROUND(elapsed_time / 1000000, 4) AS elapsed_sec,
        ROUND(user_io_wait_time / 1000000, 4) AS io_wait_sec,
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
    child_no,
    plan_hash,
    schema_name,
    execs,
    disk_reads,
    reads_per_exec,
    buffer_gets,
    rows_processed,
    elapsed_sec,
    io_wait_sec
FROM
    ranked_sql
WHERE
    row_number_value <= 20
ORDER BY
    row_number_value;

PROMPT
PROMPT Top Oracle Maintained SQL By Total Disk Reads

WITH sql_rows AS (
    SELECT
        q.sql_id,
        q.child_number,
        q.plan_hash_value,
        q.parsing_schema_name,
        q.executions,
        q.disk_reads,
        q.buffer_gets,
        q.rows_processed,
        q.user_io_wait_time
    FROM
        v$sql q
        JOIN dba_users u
            ON u.username = q.parsing_schema_name
    WHERE
        u.oracle_maintained = 'Y'
        AND q.disk_reads > 0
        AND q.sql_id IS NOT NULL
),
ranked_sql AS (
    SELECT
        sql_id,
        child_number AS child_no,
        plan_hash_value AS plan_hash,
        parsing_schema_name AS schema_name,
        executions AS execs,
        disk_reads,
        ROUND(
            disk_reads / NULLIF(executions, 0),
            2
        ) AS reads_per_exec,
        buffer_gets,
        rows_processed,
        ROUND(user_io_wait_time / 1000000, 4) AS io_wait_sec,
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
    child_no,
    plan_hash,
    schema_name,
    execs,
    disk_reads,
    reads_per_exec,
    buffer_gets,
    rows_processed,
    io_wait_sec
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
    workload_category AS category,
    COUNT(*) AS child_count,
    NVL(SUM(executions), 0) AS execs,
    NVL(SUM(disk_reads), 0) AS disk_reads,
    ROUND(
        NVL(SUM(disk_reads), 0)
        / NULLIF(SUM(executions), 0),
        2
    ) AS reads_per_exec,
    NVL(SUM(buffer_gets), 0) AS buffer_gets,
    ROUND(
        NVL(SUM(user_io_wait_time), 0) / 1000000,
        4
    ) AS io_wait_sec,
    NVL(SUM(rows_processed), 0) AS rows_processed
FROM
    sql_category
GROUP BY
    workload_category
ORDER BY
    disk_reads DESC;

PROMPT
PROMPT Top SQL By Disk Reads Completed
