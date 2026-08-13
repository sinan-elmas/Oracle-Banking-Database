/*
  Script  : 05_datapump_health_check.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Performs a read-only health assessment of the Oracle Data Pump environment.
  Run As  : SYSDBA
  Usage   : @05_datapump_health_check.sql

  Notes
  -----
  - This script is read-only.
  - It checks common Data Pump configuration and operational issues.
  - No Data Pump job is modified.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 360
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Data Pump Directory Readiness

WITH directory_state AS (
    SELECT
        COUNT(*) AS directory_count,
        SUM(
            CASE
                WHEN directory_name = 'DATA_PUMP_DIR' THEN 1
                ELSE 0
            END
        ) AS default_directory_count,
        SUM(
            CASE
                WHEN directory_name = 'EXPDP_DIR' THEN 1
                ELSE 0
            END
        ) AS custom_directory_count
    FROM
        dba_directories
),
privilege_state AS (
    SELECT
        COUNT(*) AS directory_privilege_count,
        COUNT(
            DISTINCT CASE
                WHEN privilege IN ('READ', 'WRITE') THEN grantee
            END
        ) AS privileged_grantee_count
    FROM
        dba_tab_privs
    WHERE
        type = 'DIRECTORY'
)
SELECT
    ds.directory_count,
    NVL(ds.default_directory_count, 0) AS default_directory_count,
    NVL(ds.custom_directory_count, 0) AS custom_directory_count,
    ps.directory_privilege_count,
    ps.privileged_grantee_count,
    CASE
        WHEN NVL(ds.default_directory_count, 0) > 0
          OR NVL(ds.custom_directory_count, 0) > 0
        THEN 'AVAILABLE'
        ELSE 'NOT CONFIGURED'
    END AS directory_readiness
FROM
    directory_state ds
    CROSS JOIN privilege_state ps;

PROMPT
PROMPT Active Data Pump Job State

WITH active_jobs AS (
    SELECT
        COUNT(*) AS active_job_count,
        NVL(
            SUM(
                CASE
                    WHEN state = 'EXECUTING' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS executing_job_count,
        NVL(
            SUM(
                CASE
                    WHEN state IN ('DEFINING', 'IDLING', 'STOP PENDING', 'STOPPING')
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS other_active_job_count
    FROM
        dba_datapump_jobs
    WHERE
        state <> 'NOT RUNNING'
),
active_sessions AS (
    SELECT
        COUNT(*) AS active_session_count
    FROM
        dba_datapump_sessions
)
SELECT
    aj.active_job_count,
    aj.executing_job_count,
    aj.other_active_job_count,
    ases.active_session_count,
    CASE
        WHEN aj.active_job_count = 0
         AND ases.active_session_count = 0
        THEN 'NO ACTIVE JOB'
        ELSE 'ACTIVE JOB DETECTED'
    END AS active_job_state
FROM
    active_jobs aj
    CROSS JOIN active_sessions ases;

PROMPT
PROMPT Data Pump Object Health

WITH master_table_state AS (
    SELECT
        COUNT(*) AS master_table_count,
        NVL(
            SUM(
                CASE
                    WHEN status <> 'VALID' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS invalid_master_table_count
    FROM
        dba_objects
    WHERE
        object_type = 'TABLE'
        AND (
               object_name LIKE 'SYS\_EXPORT\_%' ESCAPE '\'
            OR object_name LIKE 'SYS\_IMPORT\_%' ESCAPE '\'
        )
),
external_table_state AS (
    SELECT
        COUNT(*) AS datapump_external_table_count
    FROM
        dba_external_tables
    WHERE
        UPPER(type_name) = 'ORACLE_DATAPUMP'
),
invalid_external_state AS (
    SELECT
        COUNT(*) AS invalid_external_table_count
    FROM
        dba_objects o
    WHERE
        o.object_type = 'TABLE'
        AND o.status <> 'VALID'
        AND EXISTS (
            SELECT
                1
            FROM
                dba_external_tables e
            WHERE
                e.owner = o.owner
                AND e.table_name = o.object_name
                AND UPPER(e.type_name) = 'ORACLE_DATAPUMP'
        )
)
SELECT
    mts.master_table_count,
    mts.invalid_master_table_count,
    ets.datapump_external_table_count,
    ies.invalid_external_table_count,
    CASE
        WHEN mts.invalid_master_table_count > 0
          OR ies.invalid_external_table_count > 0
        THEN 'REVIEW REQUIRED'
        WHEN mts.master_table_count = 0
         AND ets.datapump_external_table_count = 0
        THEN 'NO DATAPUMP OBJECTS'
        ELSE 'HEALTHY'
    END AS object_health_state
FROM
    master_table_state mts
    CROSS JOIN external_table_state ets
    CROSS JOIN invalid_external_state ies;

PROMPT
PROMPT Data Pump Capacity Parameter

SELECT
    name,
    display_value,
    isdefault,
    issys_modifiable
FROM
    v$parameter
WHERE
    name = 'parallel_max_servers';

PROMPT
PROMPT Data Pump Health Summary

WITH directory_state AS (
    SELECT
        SUM(
            CASE
                WHEN directory_name IN ('DATA_PUMP_DIR', 'EXPDP_DIR') THEN 1
                ELSE 0
            END
        ) AS usable_directory_count
    FROM
        dba_directories
),
active_job_state AS (
    SELECT
        COUNT(*) AS active_job_count
    FROM
        dba_datapump_jobs
    WHERE
        state <> 'NOT RUNNING'
),
active_session_state AS (
    SELECT
        COUNT(*) AS active_session_count
    FROM
        dba_datapump_sessions
),
object_state AS (
    SELECT
        COUNT(*) AS invalid_datapump_object_count
    FROM
        dba_objects o
    WHERE
        o.status <> 'VALID'
        AND (
               (
                   o.object_type = 'TABLE'
                   AND (
                          o.object_name LIKE 'SYS\_EXPORT\_%' ESCAPE '\'
                       OR o.object_name LIKE 'SYS\_IMPORT\_%' ESCAPE '\'
                   )
               )
            OR EXISTS (
                   SELECT
                       1
                   FROM
                       dba_external_tables e
                   WHERE
                       e.owner = o.owner
                       AND e.table_name = o.object_name
                       AND UPPER(e.type_name) = 'ORACLE_DATAPUMP'
               )
        )
),
capacity_state AS (
    SELECT
        TO_NUMBER(value) AS parallel_max_servers
    FROM
        v$parameter
    WHERE
        name = 'parallel_max_servers'
)
SELECT
    CASE
        WHEN NVL(ds.usable_directory_count, 0) > 0
        THEN 'AVAILABLE'
        ELSE 'NOT CONFIGURED'
    END AS directory_state,
    CASE
        WHEN ajs.active_job_count = 0
         AND ass.active_session_count = 0
        THEN 'NO ACTIVE JOB'
        ELSE 'ACTIVE JOB DETECTED'
    END AS job_state,
    CASE
        WHEN os.invalid_datapump_object_count = 0
        THEN 'HEALTHY'
        ELSE 'REVIEW REQUIRED'
    END AS object_state,
    cs.parallel_max_servers,
    CASE
        WHEN NVL(ds.usable_directory_count, 0) = 0
        THEN 'NOT READY'
        WHEN os.invalid_datapump_object_count > 0
        THEN 'REVIEW REQUIRED'
        ELSE 'READY'
    END AS datapump_environment_state
FROM
    directory_state ds
    CROSS JOIN active_job_state ajs
    CROSS JOIN active_session_state ass
    CROSS JOIN object_state os
    CROSS JOIN capacity_state cs;

PROMPT
PROMPT Data Pump Health Check Completed
