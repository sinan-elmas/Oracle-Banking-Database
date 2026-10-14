/*
  Script  : 01_database_health_check.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Provides a consolidated read-only overview of database operational health.
  Run As  : SYSDBA
  Usage   : @01_database_health_check.sql

  Notes
  -----
  - This script is read-only.
  - It summarizes the current operational status using Oracle dynamic performance views.
  - Results represent the database state at execution time.
  - HEALTHY means no defined check raised an alarm; it does not guarantee recoverability.
  - Thresholds are laboratory defaults, not approved production policies.
  - Recent alert log matches indicate records to review, not necessarily active incidents.
  - A five-minute blocking wait is a review threshold, not an automatic critical incident.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 420
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Database And Instance State

SELECT
    d.name AS database_name,
    d.open_mode,
    d.log_mode,
    d.database_role,
    i.instance_name,
    i.status AS instance_status,
    i.database_status,
    TO_CHAR(i.startup_time, 'DD-MON-YYYY HH24:MI:SS') AS startup_time
FROM
    v$database d
    CROSS JOIN v$instance i;

PROMPT
PROMPT Monitoring Thresholds

SELECT
    80 AS tablespace_warning_pct,
    90 AS tablespace_critical_pct,
    80 AS fra_warning_pct,
    90 AS fra_critical_pct,
    80 AS resource_warning_pct,
    90 AS resource_critical_pct,
    30 AS long_running_minutes,
    24 AS alert_log_lookback_hours
FROM
    dual;

PROMPT
PROMPT Key Operational Indicators

WITH
tablespace_state AS (
    SELECT
        NVL(SUM(CASE WHEN used_percent >= 90 THEN 1 ELSE 0 END), 0)
            AS critical_tablespaces,
        NVL(
            SUM(
                CASE
                    WHEN used_percent >= 80
                     AND used_percent < 90
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS warning_tablespaces
    FROM
        dba_tablespace_usage_metrics
),
fra_state AS (
    SELECT
        MAX(
            ROUND(
                space_used * 100 / NULLIF(space_limit, 0),
                2
            )
        ) AS fra_used_pct
    FROM
        v$recovery_file_dest
),
archive_state AS (
    SELECT
        NVL(
            SUM(
                CASE
                    WHEN destination IS NOT NULL
                     AND status IN ('ERROR', 'BAD PARAM')
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS archive_destination_errors
    FROM
        v$archive_dest_status
),
blocking_state AS (
    SELECT
        COUNT(*) AS blocked_sessions
    FROM
        v$session
    WHERE
        blocking_session IS NOT NULL
        AND wait_class <> 'Idle'
),
long_running_state AS (
    SELECT
        COUNT(*) AS long_running_sessions
    FROM
        v$session s
    WHERE
        s.type = 'USER'
        AND s.status = 'ACTIVE'
        AND s.last_call_et >= 1800
        AND s.sid <> (
            SELECT
                sid
            FROM
                v$mystat
            WHERE
                ROWNUM = 1
        )
),
resource_values AS (
    SELECT
        resource_name,
        current_utilization,
        CASE
            WHEN REGEXP_LIKE(TRIM(limit_value), '^[0-9]+$')
            THEN TO_NUMBER(TRIM(limit_value))
        END AS numeric_limit
    FROM
        v$resource_limit
    WHERE
        resource_name IN ('processes', 'sessions', 'transactions')
),
resource_state AS (
    SELECT
        NVL(
            SUM(
                CASE
                    WHEN numeric_limit IS NOT NULL
                     AND current_utilization
                         / NULLIF(numeric_limit, 0) * 100 >= 90
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS critical_resources,
        NVL(
            SUM(
                CASE
                    WHEN numeric_limit IS NOT NULL
                     AND current_utilization
                         / NULLIF(numeric_limit, 0) * 100 >= 80
                     AND current_utilization
                         / NULLIF(numeric_limit, 0) * 100 < 90
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS warning_resources
    FROM
        resource_values
),
alert_state AS (
    SELECT
        COUNT(*) AS critical_alerts_last_24h
    FROM
        v$diag_alert_ext
    WHERE
        originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
        AND (
               message_level IN (1, 2, 3)
            OR REGEXP_LIKE(
                   message_text,
                   '(^|[^A-Z])(ORA-|TNS-|CRITICAL|FATAL)',
                   'i'
               )
        )
),
invalid_object_state AS (
    SELECT
        COUNT(*) AS application_invalid_objects
    FROM
        dba_objects o
        JOIN dba_users u
            ON u.username = o.owner
    WHERE
        u.oracle_maintained = 'N'
        AND o.status <> 'VALID'
),
scheduler_state AS (
    SELECT
        COUNT(*) AS application_jobs_requiring_review
    FROM
        dba_scheduler_jobs j
        JOIN dba_users u
            ON u.username = j.owner
    WHERE
        u.oracle_maintained = 'N'
        AND (
               j.state = 'BROKEN'
            OR j.failure_count > 0
        )
)
SELECT
    ts.critical_tablespaces,
    ts.warning_tablespaces,
    fs.fra_used_pct,
    ars.archive_destination_errors,
    bs.blocked_sessions,
    lrs.long_running_sessions,
    rs.critical_resources,
    rs.warning_resources,
    als.critical_alerts_last_24h,
    ios.application_invalid_objects,
    ss.application_jobs_requiring_review
FROM
    tablespace_state ts
    CROSS JOIN fra_state fs
    CROSS JOIN archive_state ars
    CROSS JOIN blocking_state bs
    CROSS JOIN long_running_state lrs
    CROSS JOIN resource_state rs
    CROSS JOIN alert_state als
    CROSS JOIN invalid_object_state ios
    CROSS JOIN scheduler_state ss;

PROMPT
PROMPT Recent RMAN Backup Completion Times

SELECT
    MAX(
        CASE
            WHEN status = 'COMPLETED'
             AND input_type IN ('DB FULL', 'DB INCR', 'DATAFILE FULL')
            THEN end_time
        END
    ) AS latest_database_backup,
    MAX(
        CASE
            WHEN status = 'COMPLETED'
             AND input_type = 'ARCHIVELOG'
            THEN end_time
        END
    ) AS latest_archivelog_backup,
    MAX(
        CASE
            WHEN status = 'COMPLETED'
             AND input_type = 'CONTROLFILE'
            THEN end_time
        END
    ) AS latest_controlfile_backup,
    ROUND(
        (SYSDATE - MAX(
            CASE
                WHEN status = 'COMPLETED'
                 AND input_type IN ('DB FULL', 'DB INCR', 'DATAFILE FULL')
                THEN end_time
            END
        )) * 24,
        2
    ) AS latest_database_backup_age_hours,
    SUM(
        CASE
            WHEN status LIKE 'FAILED%'
             AND end_time >= SYSDATE - 1
            THEN 1
            ELSE 0
        END
    ) AS failed_backup_jobs_last_24h
FROM
    v$rman_backup_job_details;

PROMPT
PROMPT Database Health Summary

WITH
database_state AS (
    SELECT
        d.open_mode,
        d.log_mode,
        d.database_role,
        i.status AS instance_status,
        i.database_status
    FROM
        v$database d
        CROSS JOIN v$instance i
),
tablespace_state AS (
    SELECT
        NVL(SUM(CASE WHEN used_percent >= 90 THEN 1 ELSE 0 END), 0)
            AS critical_count,
        NVL(
            SUM(
                CASE
                    WHEN used_percent >= 80
                     AND used_percent < 90
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS warning_count
    FROM
        dba_tablespace_usage_metrics
),
fra_state AS (
    SELECT
        MAX(
            ROUND(
                space_used * 100 / NULLIF(space_limit, 0),
                2
            )
        ) AS used_pct
    FROM
        v$recovery_file_dest
),
archive_state AS (
    SELECT
        NVL(
            SUM(
                CASE
                    WHEN destination IS NOT NULL
                     AND status IN ('ERROR', 'BAD PARAM')
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS error_count
    FROM
        v$archive_dest_status
),
blocking_state AS (
    SELECT
        COUNT(*) AS blocked_count,
        NVL(
            SUM(
                CASE
                    WHEN wait_time_micro >= 300000000
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS prolonged_blocked_count
    FROM
        v$session
    WHERE
        blocking_session_status = 'VALID'
        AND blocking_session IS NOT NULL
        AND state = 'WAITING'
        AND wait_class <> 'Idle'
),
resource_values AS (
    SELECT
        resource_name,
        current_utilization,
        CASE
            WHEN REGEXP_LIKE(TRIM(limit_value), '^[0-9]+$')
            THEN TO_NUMBER(TRIM(limit_value))
        END AS numeric_limit
    FROM
        v$resource_limit
    WHERE
        resource_name IN ('processes', 'sessions', 'transactions')
),
resource_state AS (
    SELECT
        NVL(
            SUM(
                CASE
                    WHEN numeric_limit IS NOT NULL
                     AND current_utilization
                         / NULLIF(numeric_limit, 0) * 100 >= 90
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS critical_count,
        NVL(
            SUM(
                CASE
                    WHEN numeric_limit IS NOT NULL
                     AND current_utilization
                         / NULLIF(numeric_limit, 0) * 100 >= 80
                     AND current_utilization
                         / NULLIF(numeric_limit, 0) * 100 < 90
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS warning_count
    FROM
        resource_values
),
alert_state AS (
    SELECT
        COUNT(*) AS critical_count
    FROM
        v$diag_alert_ext
    WHERE
        originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
        AND (
               message_level IN (1, 2, 3)
            OR REGEXP_LIKE(
                   message_text,
                   '(^|[^A-Z])(ORA-|TNS-|CRITICAL|FATAL)',
                   'i'
               )
        )
),
backup_state AS (
    SELECT
        SUM(
            CASE
                WHEN status LIKE 'FAILED%'
                 AND end_time >= SYSDATE - 1
                THEN 1
                ELSE 0
            END
        ) AS failed_jobs_last_24h
    FROM
        v$rman_backup_job_details
),
maintenance_state AS (
    SELECT
        (
            SELECT
                COUNT(*)
            FROM
                dba_objects o
                JOIN dba_users u
                    ON u.username = o.owner
            WHERE
                u.oracle_maintained = 'N'
                AND o.status <> 'VALID'
        )
        +
        (
            SELECT
                COUNT(*)
            FROM
                dba_scheduler_jobs j
                JOIN dba_users u
                    ON u.username = j.owner
            WHERE
                u.oracle_maintained = 'N'
                AND (
                       j.state = 'BROKEN'
                    OR j.failure_count > 0
                )
        ) AS review_count
    FROM
        dual
)
SELECT
    CASE
        WHEN ds.instance_status <> 'OPEN'
          OR ds.database_status <> 'ACTIVE'
          OR ds.open_mode NOT IN ('READ WRITE', 'READ ONLY')
        THEN 'CRITICAL'

        WHEN ts.critical_count > 0
          OR fs.used_pct >= 90
          OR ars.error_count > 0
          OR rs.critical_count > 0
        THEN 'CRITICAL'

        WHEN ts.warning_count > 0
          OR bs.prolonged_blocked_count > 0
          OR als.critical_count > 0
          OR fs.used_pct >= 80
          OR fs.used_pct IS NULL
          OR rs.warning_count > 0
          OR ms.review_count > 0
          OR bk.failed_jobs_last_24h > 0
        THEN 'REVIEW REQUIRED'

        ELSE 'HEALTHY'
    END AS database_health_state,
    CASE
        WHEN ds.instance_status <> 'OPEN'
          OR ds.database_status <> 'ACTIVE'
          OR ds.open_mode NOT IN ('READ WRITE', 'READ ONLY')
        THEN 'INSTANCE OR DATABASE STATE REQUIRES REVIEW'

        WHEN ts.critical_count > 0
        THEN 'CRITICAL TABLESPACE USAGE DETECTED'

        WHEN fs.used_pct >= 90
        THEN 'CRITICAL FRA USAGE DETECTED'

        WHEN ars.error_count > 0
        THEN 'ARCHIVE DESTINATION ERROR DETECTED'

        WHEN rs.critical_count > 0
        THEN 'CRITICAL RESOURCE LIMIT USAGE DETECTED'

        WHEN ts.warning_count > 0
        THEN 'TABLESPACE WARNING THRESHOLD REACHED'

        WHEN bs.prolonged_blocked_count > 0
        THEN 'PROLONGED BLOCKING WAIT REQUIRES REVIEW'

        WHEN als.critical_count > 0
        THEN 'ALERT LOG RECORDS REQUIRE REVIEW'

        WHEN fs.used_pct >= 80
        THEN 'FRA WARNING THRESHOLD REACHED'

        WHEN fs.used_pct IS NULL
        THEN 'FRA USAGE UNAVAILABLE OR NOT CONFIGURED'

        WHEN rs.warning_count > 0
        THEN 'RESOURCE LIMIT WARNING THRESHOLD REACHED'

        WHEN ms.review_count > 0
        THEN 'MAINTENANCE ITEMS REQUIRE REVIEW'

        WHEN bk.failed_jobs_last_24h > 0
        THEN 'RECENT FAILED BACKUP JOBS REQUIRE REVIEW'

        ELSE 'NO CRITICAL CONDITION DETECTED'
    END AS primary_health_message
FROM
    database_state ds
    CROSS JOIN tablespace_state ts
    CROSS JOIN fra_state fs
    CROSS JOIN archive_state ars
    CROSS JOIN blocking_state bs
    CROSS JOIN resource_state rs
    CROSS JOIN alert_state als
    CROSS JOIN maintenance_state ms
    CROSS JOIN backup_state bk;

PROMPT
PROMPT Database Health Check Completed
