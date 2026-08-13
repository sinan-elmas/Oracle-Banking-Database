/*
  Script  : 02_active_jobs.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports active Oracle Data Pump jobs and worker sessions.
  Run As  : SYSDBA
  Usage   : @02_active_jobs.sql

  Notes
  -----
  - This script is read-only.
  - Results reflect currently active Data Pump jobs.
  - No Data Pump job is started or stopped.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 340
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Active Data Pump Jobs

SELECT
    owner_name,
    job_name,
    operation,
    job_mode,
    state,
    degree,
    attached_sessions,
    datapump_sessions
FROM
    dba_datapump_jobs
WHERE
    state <> 'NOT RUNNING'
ORDER BY
    owner_name,
    job_name;

PROMPT
PROMPT Data Pump Sessions

SELECT
    owner_name,
    job_name,
    session_type,
    saddr
FROM
    dba_datapump_sessions
ORDER BY
    owner_name,
    job_name,
    session_type;

PROMPT
PROMPT Active Data Pump Executions

SELECT
    owner_name,
    job_name,
    operation,
    job_mode,
    state,
    attached_sessions,
    datapump_sessions
FROM
    dba_datapump_jobs
WHERE
    state IN (
        'DEFINING',
        'EXECUTING',
        'IDLING',
        'STOP PENDING',
        'STOPPING'
    )
ORDER BY
    owner_name,
    job_name;

PROMPT
PROMPT Data Pump Active Job Summary

WITH job_summary AS (
    SELECT
        COUNT(*) AS total_jobs,
        NVL(
            SUM(
                CASE
                    WHEN state = 'EXECUTING' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS executing_jobs,
        NVL(
            SUM(
                CASE
                    WHEN state = 'DEFINING' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS defining_jobs,
        NVL(
            SUM(
                CASE
                    WHEN state = 'IDLING' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS idling_jobs,
        NVL(
            SUM(
                CASE
                    WHEN state IN ('STOPPING', 'STOP PENDING') THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS stopping_jobs
    FROM
        dba_datapump_jobs
    WHERE
        state <> 'NOT RUNNING'
)
SELECT
    total_jobs,
    executing_jobs,
    defining_jobs,
    idling_jobs,
    stopping_jobs,
    CASE
        WHEN total_jobs = 0 THEN 'NO ACTIVE JOB'
        ELSE 'ACTIVE JOB DETECTED'
    END AS datapump_job_state
FROM
    job_summary;

PROMPT
PROMPT Data Pump Active Job Inventory Completed
