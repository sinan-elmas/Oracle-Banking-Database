/*
  Script  : 03_backup_history.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports RMAN backup job history and execution statistics.
  Run As  : SYSDBA
  Usage   : @03_backup_history.sql

  Notes
  -----
  - This script is read-only.
  - Job duration and status reflect RMAN execution history.
  - Historical information depends on repository retention.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 300
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF

PROMPT
PROMPT Recent RMAN Backup Jobs

SELECT
    session_key,
    input_type,
    status,
    output_device_type,
    optimized,
    autobackup_done,
    input_bytes_display,
    output_bytes_display,
    time_taken_display,
    input_bytes_per_sec_display AS input_rate,
    output_bytes_per_sec_display AS output_rate,
    ROUND(compression_ratio, 2) AS compression_ratio,
    TO_CHAR(start_time, 'DD-MON-YYYY HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'DD-MON-YYYY HH24:MI:SS') AS end_time
FROM
    v$rman_backup_job_details
ORDER BY
    start_time DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT Backup Job Status Summary

WITH status_reference AS (
    SELECT 'COMPLETED' AS status, 1 AS sort_order FROM dual
    UNION ALL
    SELECT 'COMPLETED WITH WARNINGS', 2 FROM dual
    UNION ALL
    SELECT 'COMPLETED WITH ERRORS', 3 FROM dual
    UNION ALL
    SELECT 'FAILED', 4 FROM dual
    UNION ALL
    SELECT 'RUNNING', 5 FROM dual
    UNION ALL
    SELECT 'RUNNING WITH WARNINGS', 6 FROM dual
    UNION ALL
    SELECT 'RUNNING WITH ERRORS', 7 FROM dual
),
job_summary AS (
    SELECT
        status,
        COUNT(*) AS job_count,
        SUM(output_bytes) AS output_bytes,
        MAX(end_time) AS latest_end_time
    FROM
        v$rman_backup_job_details
    GROUP BY
        status
)
SELECT
    sr.status,
    NVL(js.job_count, 0) AS job_count,
    ROUND(NVL(js.output_bytes, 0) / 1024 / 1024, 2) AS total_output_mb,
    js.latest_end_time
FROM
    status_reference sr
    LEFT JOIN job_summary js
        ON js.status = sr.status
ORDER BY
    sr.sort_order;

PROMPT
PROMPT Backup History By Input Type

SELECT
    input_type,
    COUNT(*) AS job_count,
    SUM(
        CASE
            WHEN status = 'COMPLETED' THEN 1
            ELSE 0
        END
    ) AS completed_jobs,
    SUM(
        CASE
            WHEN status LIKE '%WARNING%' THEN 1
            ELSE 0
        END
    ) AS warning_jobs,
    SUM(
        CASE
            WHEN status LIKE '%ERROR%' OR status = 'FAILED' THEN 1
            ELSE 0
        END
    ) AS failed_or_error_jobs,
    ROUND(SUM(input_bytes) / 1024 / 1024, 2) AS total_input_mb,
    ROUND(SUM(output_bytes) / 1024 / 1024, 2) AS total_output_mb,
    ROUND(AVG(elapsed_seconds), 2) AS average_elapsed_seconds,
    MAX(end_time) AS latest_backup
FROM
    v$rman_backup_job_details
GROUP BY
    input_type
ORDER BY
    input_type;

PROMPT
PROMPT Recent Failed Or Warning Backup Jobs

SELECT
    session_key,
    input_type,
    status,
    output_device_type,
    command_id,
    input_bytes_display,
    output_bytes_display,
    time_taken_display,
    TO_CHAR(start_time, 'DD-MON-YYYY HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'DD-MON-YYYY HH24:MI:SS') AS end_time
FROM
    v$rman_backup_job_details
WHERE
    status <> 'COMPLETED'
ORDER BY
    start_time DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT Archivelog Backup Job History

SELECT
    session_key,
    status,
    output_device_type,
    output_bytes_display,
    time_taken_display,
    output_bytes_per_sec_display AS output_rate,
    autobackup_done,
    TO_CHAR(start_time, 'DD-MON-YYYY HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'DD-MON-YYYY HH24:MI:SS') AS end_time
FROM
    v$rman_backup_job_details
WHERE
    input_type = 'ARCHIVELOG'
ORDER BY
    start_time DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT Backup Job Recency Summary

SELECT
    input_type,
    MAX(
        CASE
            WHEN status = 'COMPLETED' THEN end_time
        END
    ) AS latest_successful_backup,
    MAX(
        CASE
            WHEN status <> 'COMPLETED' THEN end_time
        END
    ) AS latest_non_successful_backup
FROM
    v$rman_backup_job_details
GROUP BY
    input_type
ORDER BY
    input_type;

PROMPT
PROMPT Backup History Inventory Completed
