/*
  Script  : 05_scheduler_jobs.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports application Scheduler job configuration, current state,
            failures, execution history, and maintenance candidates.
  Run As  : SYSDBA
  Usage   : @05_scheduler_jobs.sql

  Notes
  -----
  - This script is read-only.
  - It does not run, stop, enable, disable, drop, or modify Scheduler jobs.
  - Disabled jobs may be intentional and require contextual review.
  - Historical failures should be evaluated together with the latest run status.
  - Results focus on non-Oracle-maintained job owners.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 400
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Application Scheduler Jobs

SELECT
    j.owner,
    j.job_name,
    j.job_type,
    j.enabled,
    j.state,
    j.schedule_type,
    j.restartable,
    j.auto_drop,
    j.run_count,
    j.failure_count,
    j.retry_count,
    TO_CHAR(j.last_start_date, 'DD-MON-YYYY HH24:MI:SS TZH:TZM')
        AS last_start_date,
    j.last_run_duration,
    TO_CHAR(j.next_run_date, 'DD-MON-YYYY HH24:MI:SS TZH:TZM')
        AS next_run_date
FROM
    dba_scheduler_jobs j
    JOIN dba_users u
        ON u.username = j.owner
WHERE
    u.oracle_maintained = 'N'
ORDER BY
    j.owner,
    j.job_name;

PROMPT
PROMPT Disabled Application Scheduler Jobs

SELECT
    j.owner,
    j.job_name,
    j.job_type,
    j.enabled,
    j.state,
    j.schedule_type,
    j.run_count,
    j.failure_count,
    TO_CHAR(j.last_start_date, 'DD-MON-YYYY HH24:MI:SS TZH:TZM')
        AS last_start_date,
    TO_CHAR(j.next_run_date, 'DD-MON-YYYY HH24:MI:SS TZH:TZM')
        AS next_run_date,
    'CONFIRM THAT DISABLED STATE IS INTENTIONAL'
        AS maintenance_assessment
FROM
    dba_scheduler_jobs j
    JOIN dba_users u
        ON u.username = j.owner
WHERE
    u.oracle_maintained = 'N'
    AND j.enabled = 'FALSE'
ORDER BY
    j.owner,
    j.job_name;

PROMPT
PROMPT Application Scheduler Jobs Requiring Review

SELECT
    j.owner,
    j.job_name,
    j.enabled,
    j.state,
    j.run_count,
    j.failure_count,
    j.retry_count,
    TO_CHAR(j.last_start_date, 'DD-MON-YYYY HH24:MI:SS TZH:TZM')
        AS last_start_date,
    j.last_run_duration,
    TO_CHAR(j.next_run_date, 'DD-MON-YYYY HH24:MI:SS TZH:TZM')
        AS next_run_date,
    CASE
        WHEN j.state = 'BROKEN'
        THEN 'BROKEN JOB - REVIEW REQUIRED'

        WHEN j.failure_count > 0
        THEN 'FAILURES RECORDED - REVIEW RUN HISTORY'

        WHEN j.enabled = 'FALSE'
        THEN 'DISABLED - CONFIRM INTENT'

        ELSE 'REVIEW REQUIRED'
    END AS maintenance_assessment
FROM
    dba_scheduler_jobs j
    JOIN dba_users u
        ON u.username = j.owner
WHERE
    u.oracle_maintained = 'N'
    AND (
           j.state = 'BROKEN'
        OR j.failure_count > 0
        OR j.enabled = 'FALSE'
    )
ORDER BY
    CASE
        WHEN j.state = 'BROKEN' THEN 1
        WHEN j.failure_count > 0 THEN 2
        ELSE 3
    END,
    j.owner,
    j.job_name;

PROMPT
PROMPT Currently Running Application Scheduler Jobs

SELECT
    j.owner,
    j.job_name,
    j.job_type,
    j.state,
    TO_CHAR(j.last_start_date, 'DD-MON-YYYY HH24:MI:SS TZH:TZM')
        AS last_start_date,
    j.last_run_duration,
    j.run_count,
    j.failure_count
FROM
    dba_scheduler_jobs j
    JOIN dba_users u
        ON u.username = j.owner
WHERE
    u.oracle_maintained = 'N'
    AND j.state = 'RUNNING'
ORDER BY
    j.owner,
    j.job_name;

PROMPT
PROMPT Recent Unsuccessful Application Job Runs

SELECT
    r.owner,
    r.job_name,
    r.status,
    r.error# AS error_number,
    TO_CHAR(r.req_start_date, 'DD-MON-YYYY HH24:MI:SS TZH:TZM')
        AS requested_start_date,
    TO_CHAR(r.actual_start_date, 'DD-MON-YYYY HH24:MI:SS TZH:TZM')
        AS actual_start_date,
    r.run_duration,
    r.instance_id,
    r.additional_info
FROM
    dba_scheduler_job_run_details r
    JOIN dba_users u
        ON u.username = r.owner
WHERE
    u.oracle_maintained = 'N'
    AND r.status <> 'SUCCEEDED'
ORDER BY
    r.actual_start_date DESC NULLS LAST,
    r.log_id DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT Latest Application Job Run Status

WITH ranked_runs AS (
    SELECT
        r.owner,
        r.job_name,
        r.status,
        r.error# AS error_number,
        r.actual_start_date,
        r.run_duration,
        ROW_NUMBER() OVER (
            PARTITION BY
                r.owner,
                r.job_name
            ORDER BY
                r.actual_start_date DESC NULLS LAST,
                r.log_id DESC
        ) AS row_number_value
    FROM
        dba_scheduler_job_run_details r
        JOIN dba_users u
            ON u.username = r.owner
    WHERE
        u.oracle_maintained = 'N'
)
SELECT
    rr.owner,
    rr.job_name,
    rr.status AS latest_run_status,
    rr.error_number,
    TO_CHAR(rr.actual_start_date, 'DD-MON-YYYY HH24:MI:SS TZH:TZM')
        AS latest_actual_start_date,
    rr.run_duration AS latest_run_duration
FROM
    ranked_runs rr
WHERE
    rr.row_number_value = 1
ORDER BY
    rr.owner,
    rr.job_name;

PROMPT
PROMPT Scheduler Job Summary By Owner

WITH latest_runs AS (
    SELECT
        r.owner,
        r.job_name,
        r.status,
        ROW_NUMBER() OVER (
            PARTITION BY
                r.owner,
                r.job_name
            ORDER BY
                r.actual_start_date DESC NULLS LAST,
                r.log_id DESC
        ) AS row_number_value
    FROM
        dba_scheduler_job_run_details r
),
application_jobs AS (
    SELECT
        j.owner,
        j.job_name,
        j.enabled,
        j.state,
        j.failure_count
    FROM
        dba_scheduler_jobs j
        JOIN dba_users u
            ON u.username = j.owner
    WHERE
        u.oracle_maintained = 'N'
)
SELECT
    j.owner,
    COUNT(*) AS job_count,
    NVL(
        SUM(
            CASE
                WHEN j.enabled = 'TRUE' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS enabled_job_count,
    NVL(
        SUM(
            CASE
                WHEN j.enabled = 'FALSE' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS disabled_job_count,
    NVL(
        SUM(
            CASE
                WHEN j.state = 'RUNNING' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS running_job_count,
    NVL(
        SUM(
            CASE
                WHEN j.state = 'BROKEN' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS broken_job_count,
    NVL(
        SUM(
            CASE
                WHEN j.failure_count > 0 THEN 1
                ELSE 0
            END
        ),
        0
    ) AS jobs_with_failure_count,
    NVL(
        SUM(
            CASE
                WHEN lr.status IS NOT NULL
                 AND lr.status <> 'SUCCEEDED'
                THEN 1
                ELSE 0
            END
        ),
        0
    ) AS latest_run_not_successful
FROM
    application_jobs j
    LEFT JOIN latest_runs lr
        ON lr.owner = j.owner
       AND lr.job_name = j.job_name
       AND lr.row_number_value = 1
GROUP BY
    j.owner
ORDER BY
    j.owner;

PROMPT
PROMPT Scheduler Maintenance Status Summary

WITH latest_runs AS (
    SELECT
        r.owner,
        r.job_name,
        r.status,
        ROW_NUMBER() OVER (
            PARTITION BY
                r.owner,
                r.job_name
            ORDER BY
                r.actual_start_date DESC NULLS LAST,
                r.log_id DESC
        ) AS row_number_value
    FROM
        dba_scheduler_job_run_details r
        JOIN dba_users u
            ON u.username = r.owner
    WHERE
        u.oracle_maintained = 'N'
),
application_jobs AS (
    SELECT
        j.owner,
        j.job_name,
        j.enabled,
        j.state,
        j.failure_count
    FROM
        dba_scheduler_jobs j
        JOIN dba_users u
            ON u.username = j.owner
    WHERE
        u.oracle_maintained = 'N'
),
job_state AS (
    SELECT
        COUNT(*) AS application_job_count,
        NVL(
            SUM(
                CASE
                    WHEN enabled = 'FALSE' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS disabled_job_count,
        NVL(
            SUM(
                CASE
                    WHEN state = 'RUNNING' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS running_job_count,
        NVL(
            SUM(
                CASE
                    WHEN state = 'BROKEN' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS broken_job_count,
        NVL(
            SUM(
                CASE
                    WHEN failure_count > 0 THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS jobs_with_failure_count
    FROM
        application_jobs
),
latest_run_state AS (
    SELECT
        NVL(
            SUM(
                CASE
                    WHEN lr.status IS NOT NULL
                     AND lr.status <> 'SUCCEEDED'
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS latest_run_not_successful
    FROM
        application_jobs j
        LEFT JOIN latest_runs lr
            ON lr.owner = j.owner
           AND lr.job_name = j.job_name
           AND lr.row_number_value = 1
),
oracle_job_state AS (
    SELECT
        COUNT(*) AS oracle_maintained_job_count
    FROM
        dba_scheduler_jobs j
        JOIN dba_users u
            ON u.username = j.owner
    WHERE
        u.oracle_maintained = 'Y'
)
SELECT
    js.application_job_count,
    js.disabled_job_count,
    js.running_job_count,
    js.broken_job_count,
    js.jobs_with_failure_count,
    lrs.latest_run_not_successful,
    ojs.oracle_maintained_job_count,
    CASE
        WHEN js.broken_job_count > 0
        THEN 'BROKEN JOB REVIEW REQUIRED'

        WHEN lrs.latest_run_not_successful > 0
          OR js.jobs_with_failure_count > 0
        THEN 'JOB FAILURE REVIEW REQUIRED'

        WHEN js.disabled_job_count > 0
        THEN 'DISABLED JOBS RECORDED'

        WHEN js.application_job_count = 0
        THEN 'NO APPLICATION JOBS'

        ELSE 'HEALTHY'
    END AS scheduler_maintenance_state
FROM
    job_state js
    CROSS JOIN latest_run_state lrs
    CROSS JOIN oracle_job_state ojs;

PROMPT
PROMPT Scheduler Job Inventory Completed
