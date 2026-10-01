/*
  Script  : 03_job_history.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports Data Pump job metadata and master table information
            currently available in the database.
  Run As  : SYSDBA
  Usage   : @03_job_history.sql

  Notes
  -----
  - This script is read-only.
  - DBA_DATAPUMP_JOBS is not a permanent or complete Data Pump execution history.
  - Successfully completed Data Pump jobs normally remove their master tables.
  - Stopped, interrupted, or otherwise retained jobs may leave master tables behind.
  - Custom JOB_NAME values are supported when matching current Data Pump jobs
    to their master tables.
  - SYS_EXPORT_% and SYS_IMPORT_% name patterns are checked separately as
    potential Data Pump master tables using Oracle's default naming convention.
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
PROMPT Data Pump Job Master Tables

SELECT
    o.owner,
    o.object_name,
    o.object_type,
    o.status,
    o.created,
    o.last_ddl_time,
    j.operation,
    j.job_mode,
    j.state
FROM
    dba_objects o
    JOIN dba_datapump_jobs j
        ON  j.owner_name = o.owner
        AND j.job_name   = o.object_name
WHERE
    o.object_type = 'TABLE'
ORDER BY
    o.created DESC,
    o.owner,
    o.object_name;

PROMPT
PROMPT Potential Data Pump Master Tables by Default Naming Pattern

SELECT
    owner,
    object_name,
    object_type,
    status,
    created,
    last_ddl_time
FROM
    dba_objects
WHERE
    object_type = 'TABLE'
    AND (
           object_name LIKE 'SYS\_EXPORT\_%' ESCAPE '\'
        OR object_name LIKE 'SYS\_IMPORT\_%' ESCAPE '\'
    )
ORDER BY
    created DESC,
    owner,
    object_name;

PROMPT
PROMPT Data Pump Jobs Currently Recorded

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
ORDER BY
    owner_name,
    job_name;

PROMPT
PROMPT Data Pump Job Metadata Summary

WITH job_summary AS (
    SELECT
        COUNT(*) AS total_jobs,
        NVL(
            SUM(
                CASE
                    WHEN operation = 'EXPORT' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS export_jobs,
        NVL(
            SUM(
                CASE
                    WHEN operation = 'IMPORT' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS import_jobs
    FROM
        dba_datapump_jobs
),
master_summary AS (
    SELECT
        COUNT(*) AS matched_master_tables
    FROM
        dba_objects o
        JOIN dba_datapump_jobs j
            ON  j.owner_name = o.owner
            AND j.job_name   = o.object_name
    WHERE
        o.object_type = 'TABLE'
),
pattern_summary AS (
    SELECT
        COUNT(*) AS default_named_master_tables
    FROM
        dba_objects
    WHERE
        object_type = 'TABLE'
        AND (
               object_name LIKE 'SYS\_EXPORT\_%' ESCAPE '\'
            OR object_name LIKE 'SYS\_IMPORT\_%' ESCAPE '\'
        )
)
SELECT
    j.total_jobs,
    j.export_jobs,
    j.import_jobs,
    m.matched_master_tables,
    p.default_named_master_tables,
    CASE
        WHEN j.total_jobs = 0 THEN 'NO RECORDED JOB'
        ELSE 'JOB METADATA AVAILABLE'
    END AS datapump_job_metadata_state
FROM
    job_summary j
    CROSS JOIN master_summary m
    CROSS JOIN pattern_summary p;

PROMPT
PROMPT Data Pump Job Metadata Inventory Completed
