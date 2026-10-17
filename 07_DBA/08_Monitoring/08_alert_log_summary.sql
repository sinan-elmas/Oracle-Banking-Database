/*
  Script  : 08_alert_log_summary.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports recent database alert log entries recorded by Oracle.
  Run As  : SYSDBA
  Usage   : @08_alert_log_summary.sql

  Notes
  -----
  - This script is read-only.
  - Only alert information available through Oracle views is reported.
  - Operating-system alert log files are not parsed directly.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 360
SET FEEDBACK ON

PROMPT
PROMPT Alert Log Monitoring Threshold

SELECT
    24 AS alert_log_lookback_hours
FROM
    dual;

PROMPT
PROMPT Recent Critical Alert Log Entries (Last 24 Hours)

SELECT
    originating_timestamp,
    message_type,
    message_level,
    problem_key,
    SUBSTR(message_text, 1, 200) AS message_text
FROM
    v$diag_alert_ext
WHERE
    originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
    AND (
        UPPER(message_text) LIKE '%ORA-%'
        OR UPPER(message_text) LIKE '%TNS-%'
        OR message_type IN (2, 3)
    )
ORDER BY
    originating_timestamp DESC;

PROMPT
PROMPT Alert Counts By Category (Last 24 Hours)

SELECT
    NVL(
        SUM(
            CASE
                WHEN UPPER(message_text) LIKE '%ORA-%' THEN 1
                ELSE 0
            END
        ), 0
    ) AS ora_messages,
    NVL(
        SUM(
            CASE
                WHEN UPPER(message_text) LIKE '%TNS-%' THEN 1
                ELSE 0
            END
        ), 0
    ) AS tns_messages,
    NVL(
        SUM(
            CASE
                WHEN message_type IN (2, 3) THEN 1
                ELSE 0
            END
        ), 0
    ) AS critical_messages
FROM
    v$diag_alert_ext
WHERE
    originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR;

PROMPT
PROMPT Alert Log Status Summary

WITH alert_counts AS (
    SELECT
        NVL(
            SUM(
                CASE
                    WHEN UPPER(message_text) LIKE '%ORA-%' THEN 1
                    ELSE 0
                END
            ), 0
        ) AS ora_messages,
        NVL(
            SUM(
                CASE
                    WHEN UPPER(message_text) LIKE '%TNS-%' THEN 1
                    ELSE 0
                END
            ), 0
        ) AS tns_messages,
        NVL(
            SUM(
                CASE
                    WHEN message_type IN (2, 3) THEN 1
                    ELSE 0
                END
            ), 0
        ) AS critical_messages
    FROM
        v$diag_alert_ext
    WHERE
        originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
)
SELECT
    ora_messages,
    tns_messages,
    critical_messages,
    CASE
        WHEN critical_messages > 0
            OR ora_messages > 0
            OR tns_messages > 0
        THEN 'REVIEW REQUIRED'
        ELSE 'HEALTHY'
    END AS alert_log_state,
    CASE
        WHEN critical_messages > 0
            THEN 'CRITICAL ALERTS FOUND'
        WHEN ora_messages > 0
            THEN 'ORA MESSAGES FOUND'
        WHEN tns_messages > 0
            THEN 'TNS MESSAGES FOUND'
        ELSE 'NO CRITICAL ALERT LOG ENTRIES'
    END AS primary_monitoring_message
FROM
    alert_counts;

PROMPT
PROMPT Alert Log Inventory Completed
