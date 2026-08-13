/*
  Script  : 04_archivelog_status.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports archived redo log generation and archive destination status.
  Run As  : SYSDBA
  Usage   : @04_archivelog_status.sql

  Notes
  -----
  - This script is read-only.
  - Results reflect current archive generation and destination status.
  - Archive destination errors should be investigated promptly.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 440
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Database Archiving State

SELECT
    d.name AS database_name,
    d.open_mode,
    d.log_mode,
    d.database_role,
    i.status AS instance_status,
    i.archiver,
    i.database_status
FROM
    v$database d
    CROSS JOIN v$instance i;

PROMPT
PROMPT Configured Archive Destinations

SELECT
    d.dest_id,
    d.dest_name,
    d.status,
    d.binding,
    d.target,
    d.archiver,
    d.schedule,
    d.destination,
    d.process,
    d.transmit_mode,
    d.affirm,
    d.valid_now,
    d.valid_type,
    d.valid_role,
    d.db_unique_name,
    d.failure_count,
    TO_CHAR(d.fail_date, 'DD-MON-YYYY HH24:MI:SS') AS fail_date,
    d.error
FROM
    v$archive_dest d
WHERE
    d.destination IS NOT NULL
ORDER BY
    d.dest_id;

PROMPT
PROMPT Archive Destination Runtime Status

SELECT
    s.dest_id,
    s.dest_name,
    s.status,
    s.type AS destination_type,
    s.database_mode,
    s.recovery_mode,
    s.destination,
    s.archived_thread#,
    s.archived_seq#,
    s.applied_thread#,
    s.applied_seq#,
    s.srl,
    s.synchronized,
    s.synchronization_status,
    s.gap_status,
    s.db_unique_name,
    s.error
FROM
    v$archive_dest_status s
WHERE
    s.destination IS NOT NULL
ORDER BY
    s.dest_id;

PROMPT
PROMPT Archive Destinations Requiring Review

WITH configured_destinations AS (
    SELECT
        d.dest_id,
        d.dest_name,
        d.status,
        d.binding,
        d.target,
        d.schedule,
        d.destination,
        d.valid_now,
        d.failure_count,
        d.fail_date,
        d.error
    FROM
        v$archive_dest d
    WHERE
        d.destination IS NOT NULL
)
SELECT
    d.dest_id,
    d.dest_name,
    d.status,
    d.binding,
    d.target,
    d.schedule,
    d.destination,
    d.valid_now,
    d.failure_count,
    TO_CHAR(d.fail_date, 'DD-MON-YYYY HH24:MI:SS') AS fail_date,
    d.error,
    CASE
        WHEN d.status = 'FULL'
        THEN 'DESTINATION QUOTA OR CAPACITY EXCEEDED'

        WHEN d.status IN ('ERROR', 'DISABLED', 'BAD PARAM')
        THEN 'ARCHIVE DESTINATION ERROR REQUIRES REVIEW'

        WHEN d.valid_now NOT IN ('YES', 'INACTIVE')
        THEN 'VALID_FOR CONFIGURATION REQUIRES REVIEW'

        WHEN NVL(d.failure_count, 0) > 0
        THEN 'ARCHIVAL FAILURES RECORDED'

        WHEN d.status = 'DEFERRED'
        THEN 'DEFERRED - CONFIRM INTENT'

        WHEN d.status = 'ALTERNATE'
        THEN 'ALTERNATE DESTINATION - INFORMATIONAL'

        ELSE 'REVIEW REQUIRED'
    END AS monitoring_assessment
FROM
    configured_destinations d
WHERE
       d.status IN (
           'ERROR',
           'DISABLED',
           'BAD PARAM',
           'FULL',
           'DEFERRED'
       )
    OR d.valid_now NOT IN ('YES', 'INACTIVE')
    OR NVL(d.failure_count, 0) > 0
    OR d.error IS NOT NULL
ORDER BY
    CASE
        WHEN d.status = 'FULL' THEN 1
        WHEN d.status IN ('ERROR', 'DISABLED', 'BAD PARAM') THEN 2
        WHEN d.error IS NOT NULL THEN 3
        WHEN NVL(d.failure_count, 0) > 0 THEN 4
        WHEN d.valid_now NOT IN ('YES', 'INACTIVE') THEN 5
        ELSE 6
    END,
    d.dest_id;

PROMPT
PROMPT Archive Destination Runtime Issues

SELECT
    s.dest_id,
    s.dest_name,
    s.status,
    s.type AS destination_type,
    s.destination,
    s.synchronized,
    s.synchronization_status,
    s.gap_status,
    s.error,
    CASE
        WHEN s.status = 'FULL'
        THEN 'DESTINATION FULL'

        WHEN s.status IN ('ERROR', 'DISABLED', 'BAD PARAM')
        THEN 'RUNTIME DESTINATION ERROR'

        WHEN s.gap_status IS NOT NULL
         AND s.gap_status <> 'NO GAP'
        THEN 'REDO GAP REQUIRES REVIEW'

        WHEN s.synchronization_status IS NOT NULL
         AND s.synchronization_status NOT IN (
             'OK',
             'STATUS NOT AVAILABLE',
             'CHECK CONFIGURATION'
         )
        THEN 'SYNCHRONIZATION REQUIRES REVIEW'

        ELSE 'REVIEW REQUIRED'
    END AS monitoring_assessment
FROM
    v$archive_dest_status s
WHERE
    s.destination IS NOT NULL
    AND (
           s.status IN (
               'ERROR',
               'DISABLED',
               'BAD PARAM',
               'FULL'
           )
        OR s.error IS NOT NULL
        OR (
               s.gap_status IS NOT NULL
           AND s.gap_status <> 'NO GAP'
        )
        OR (
               s.synchronization_status IS NOT NULL
           AND s.synchronization_status NOT IN (
               'OK',
               'STATUS NOT AVAILABLE',
               'CHECK CONFIGURATION'
           )
        )
    )
ORDER BY
    s.dest_id;

PROMPT
PROMPT Latest Archived Log By Destination

SELECT
    a.dest_id,
    d.dest_name,
    d.destination,
    MAX(a.thread#) KEEP (
        DENSE_RANK LAST
        ORDER BY
            a.completion_time,
            a.recid
    ) AS latest_thread,
    MAX(a.sequence#) KEEP (
        DENSE_RANK LAST
        ORDER BY
            a.completion_time,
            a.recid
    ) AS latest_sequence,
    MAX(a.completion_time) AS latest_completion_time,
    NVL(
        SUM(
            CASE
                WHEN a.status <> 'A' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS non_available_log_records
FROM
    v$archived_log a
    JOIN v$archive_dest d
        ON d.dest_id = a.dest_id
WHERE
    d.destination IS NOT NULL
    AND a.name IS NOT NULL
GROUP BY
    a.dest_id,
    d.dest_name,
    d.destination
ORDER BY
    a.dest_id;

PROMPT
PROMPT Archive Destination Status Summary

WITH configured_destinations AS (
    SELECT
        d.dest_id,
        d.status,
        d.valid_now,
        d.failure_count,
        d.error
    FROM
        v$archive_dest d
    WHERE
        d.destination IS NOT NULL
),
configuration_state AS (
    SELECT
        COUNT(*) AS configured_destination_count,
        NVL(
            SUM(
                CASE
                    WHEN status = 'VALID'
                     AND valid_now = 'YES'
                     AND error IS NULL
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS healthy_destination_count,
        NVL(
            SUM(
                CASE
                    WHEN status IN (
                        'ERROR',
                        'DISABLED',
                        'BAD PARAM',
                        'FULL'
                    )
                      OR error IS NOT NULL
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS error_destination_count,
        NVL(
            SUM(
                CASE
                    WHEN status = 'DEFERRED' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS deferred_destination_count,
        NVL(
            SUM(
                CASE
                    WHEN valid_now NOT IN ('YES', 'INACTIVE')
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS invalid_for_current_role_count,
        NVL(
            SUM(
                CASE
                    WHEN NVL(failure_count, 0) > 0 THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS destinations_with_failures
    FROM
        configured_destinations
),
runtime_state AS (
    SELECT
        NVL(
            SUM(
                CASE
                    WHEN s.destination IS NOT NULL
                     AND s.gap_status IS NOT NULL
                     AND s.gap_status <> 'NO GAP'
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS destinations_with_gap,
        NVL(
            SUM(
                CASE
                    WHEN s.destination IS NOT NULL
                     AND s.status IN (
                         'ERROR',
                         'DISABLED',
                         'BAD PARAM',
                         'FULL'
                     )
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS runtime_error_destinations
    FROM
        v$archive_dest_status s
),
database_state AS (
    SELECT
        log_mode,
        database_role
    FROM
        v$database
)
SELECT
    ds.log_mode,
    ds.database_role,
    cs.configured_destination_count,
    cs.healthy_destination_count,
    cs.error_destination_count,
    cs.deferred_destination_count,
    cs.invalid_for_current_role_count,
    cs.destinations_with_failures,
    rs.destinations_with_gap,
    rs.runtime_error_destinations,
    CASE
        WHEN ds.log_mode <> 'ARCHIVELOG'
        THEN 'ARCHIVELOG DISABLED'

        WHEN cs.configured_destination_count = 0
        THEN 'NO CONFIGURED DESTINATION'

        WHEN cs.error_destination_count > 0
          OR rs.runtime_error_destinations > 0
          OR rs.destinations_with_gap > 0
        THEN 'CRITICAL'

        WHEN cs.invalid_for_current_role_count > 0
          OR cs.destinations_with_failures > 0
          OR cs.deferred_destination_count > 0
        THEN 'REVIEW REQUIRED'

        ELSE 'HEALTHY'
    END AS archive_destination_state,
    CASE
        WHEN ds.log_mode <> 'ARCHIVELOG'
        THEN 'DATABASE IS NOT IN ARCHIVELOG MODE'

        WHEN cs.configured_destination_count = 0
        THEN 'NO ACTIVE ARCHIVE DESTINATION CONFIGURED'

        WHEN cs.error_destination_count > 0
          OR rs.runtime_error_destinations > 0
        THEN 'ARCHIVE DESTINATION ERROR DETECTED'

        WHEN rs.destinations_with_gap > 0
        THEN 'REDO GAP DETECTED'

        WHEN cs.invalid_for_current_role_count > 0
        THEN 'DESTINATION VALID_FOR SETTINGS REQUIRE REVIEW'

        WHEN cs.destinations_with_failures > 0
        THEN 'ARCHIVAL FAILURE HISTORY REQUIRES REVIEW'

        WHEN cs.deferred_destination_count > 0
        THEN 'DEFERRED DESTINATION RECORDED'

        ELSE 'NO ARCHIVE DESTINATION ALERT'
    END AS primary_monitoring_message
FROM
    configuration_state cs
    CROSS JOIN runtime_state rs
    CROSS JOIN database_state ds;

PROMPT
PROMPT Archive Destination Inventory Completed
