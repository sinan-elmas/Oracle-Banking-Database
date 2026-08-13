/*
  Script  : 07_resource_limits.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports current Oracle resource utilization and configured limits.
  Run As  : SYSDBA
  Usage   : @07_resource_limits.sql

  Notes
  -----
  - This script is read-only.
  - Resource usage reflects the current instance state.
  - Historical utilization is not reported.
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
PROMPT Resource Limit Monitoring Thresholds

SELECT
    80 AS warning_threshold_pct,
    90 AS critical_threshold_pct
FROM
    dual;

PROMPT
PROMPT Resource Limit Utilization

WITH resource_values AS (
    SELECT
        resource_name,
        current_utilization,
        max_utilization,
        TRIM(limit_value) AS limit_value,
        CASE
            WHEN REGEXP_LIKE(TRIM(limit_value), '^[0-9]+$')
            THEN TO_NUMBER(TRIM(limit_value))
        END AS numeric_limit
    FROM
        v$resource_limit
    WHERE
        resource_name IN (
            'processes',
            'sessions',
            'transactions'
        )
)
SELECT
    resource_name,
    current_utilization,
    max_utilization,
    limit_value,
    CASE
        WHEN numeric_limit IS NOT NULL
         AND numeric_limit > 0
        THEN ROUND(
                 current_utilization
                 / numeric_limit
                 * 100,
                 2
             )
    END AS current_utilization_pct,
    CASE
        WHEN numeric_limit IS NOT NULL
         AND numeric_limit > 0
        THEN ROUND(
                 max_utilization
                 / numeric_limit
                 * 100,
                 2
             )
    END AS max_utilization_pct,
    CASE
        WHEN numeric_limit IS NULL
        THEN 'UNLIMITED'

        WHEN current_utilization / NULLIF(numeric_limit, 0) >= 0.90
        THEN 'CRITICAL'

        WHEN current_utilization / NULLIF(numeric_limit, 0) >= 0.80
        THEN 'WARNING'

        ELSE 'NORMAL'
    END AS current_alert_level,
    CASE
        WHEN numeric_limit IS NULL
        THEN 'UNLIMITED'

        WHEN max_utilization / NULLIF(numeric_limit, 0) >= 0.90
        THEN 'CRITICAL'

        WHEN max_utilization / NULLIF(numeric_limit, 0) >= 0.80
        THEN 'WARNING'

        ELSE 'NORMAL'
    END AS historical_alert_level
FROM
    resource_values
ORDER BY
    resource_name;

PROMPT
PROMPT Resources At Warning Or Critical Level

WITH resource_values AS (
    SELECT
        resource_name,
        current_utilization,
        max_utilization,
        TRIM(limit_value) AS limit_value,
        CASE
            WHEN REGEXP_LIKE(TRIM(limit_value), '^[0-9]+$')
            THEN TO_NUMBER(TRIM(limit_value))
        END AS numeric_limit
    FROM
        v$resource_limit
    WHERE
        resource_name IN (
            'processes',
            'sessions',
            'transactions'
        )
)
SELECT
    resource_name,
    current_utilization,
    max_utilization,
    limit_value,
    ROUND(
        current_utilization
        / NULLIF(numeric_limit, 0)
        * 100,
        2
    ) AS current_utilization_pct,
    ROUND(
        max_utilization
        / NULLIF(numeric_limit, 0)
        * 100,
        2
    ) AS max_utilization_pct,
    CASE
        WHEN current_utilization / NULLIF(numeric_limit, 0) >= 0.90
        THEN 'CRITICAL - CURRENT USAGE'

        WHEN current_utilization / NULLIF(numeric_limit, 0) >= 0.80
        THEN 'WARNING - CURRENT USAGE'

        WHEN max_utilization / NULLIF(numeric_limit, 0) >= 0.90
        THEN 'CRITICAL HISTORICAL PEAK'

        ELSE 'WARNING HISTORICAL PEAK'
    END AS monitoring_assessment
FROM
    resource_values
WHERE
    numeric_limit IS NOT NULL
    AND (
           current_utilization / NULLIF(numeric_limit, 0) >= 0.80
        OR max_utilization / NULLIF(numeric_limit, 0) >= 0.80
    )
ORDER BY
    GREATEST(
        current_utilization / NULLIF(numeric_limit, 0),
        max_utilization / NULLIF(numeric_limit, 0)
    ) DESC,
    resource_name;

PROMPT
PROMPT Resource Limit Status Summary

WITH resource_values AS (
    SELECT
        resource_name,
        current_utilization,
        max_utilization,
        CASE
            WHEN REGEXP_LIKE(TRIM(limit_value), '^[0-9]+$')
            THEN TO_NUMBER(TRIM(limit_value))
        END AS numeric_limit
    FROM
        v$resource_limit
    WHERE
        resource_name IN (
            'processes',
            'sessions',
            'transactions'
        )
),
resource_state AS (
    SELECT
        COUNT(*) AS monitored_resource_count,
        NVL(
            SUM(
                CASE
                    WHEN numeric_limit IS NULL THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS unlimited_resource_count,
        NVL(
            SUM(
                CASE
                    WHEN numeric_limit IS NOT NULL
                     AND current_utilization
                         / NULLIF(numeric_limit, 0) >= 0.90
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS current_critical_resources,
        NVL(
            SUM(
                CASE
                    WHEN numeric_limit IS NOT NULL
                     AND current_utilization
                         / NULLIF(numeric_limit, 0) >= 0.80
                     AND current_utilization
                         / NULLIF(numeric_limit, 0) < 0.90
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS current_warning_resources,
        NVL(
            SUM(
                CASE
                    WHEN numeric_limit IS NOT NULL
                     AND max_utilization
                         / NULLIF(numeric_limit, 0) >= 0.90
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS historical_critical_resources,
        NVL(
            SUM(
                CASE
                    WHEN numeric_limit IS NOT NULL
                     AND max_utilization
                         / NULLIF(numeric_limit, 0) >= 0.80
                     AND max_utilization
                         / NULLIF(numeric_limit, 0) < 0.90
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS historical_warning_resources,
        NVL(
            MAX(
                CASE
                    WHEN numeric_limit IS NOT NULL
                    THEN ROUND(
                             current_utilization
                             / NULLIF(numeric_limit, 0)
                             * 100,
                             2
                         )
                END
            ),
            0
        ) AS highest_current_utilization_pct,
        NVL(
            MAX(
                CASE
                    WHEN numeric_limit IS NOT NULL
                    THEN ROUND(
                             max_utilization
                             / NULLIF(numeric_limit, 0)
                             * 100,
                             2
                         )
                END
            ),
            0
        ) AS highest_historical_utilization_pct
    FROM
        resource_values
)
SELECT
    monitored_resource_count,
    unlimited_resource_count,
    current_critical_resources,
    current_warning_resources,
    historical_critical_resources,
    historical_warning_resources,
    highest_current_utilization_pct,
    highest_historical_utilization_pct,
    CASE
        WHEN current_critical_resources > 0
        THEN 'CRITICAL'

        WHEN current_warning_resources > 0
        THEN 'WARNING'

        WHEN historical_critical_resources > 0
          OR historical_warning_resources > 0
        THEN 'HISTORICAL REVIEW REQUIRED'

        ELSE 'HEALTHY'
    END AS resource_limit_state,
    CASE
        WHEN current_critical_resources > 0
        THEN 'CURRENT RESOURCE USAGE EXCEEDS 90 PERCENT'

        WHEN current_warning_resources > 0
        THEN 'CURRENT RESOURCE USAGE EXCEEDS 80 PERCENT'

        WHEN historical_critical_resources > 0
        THEN 'HISTORICAL RESOURCE PEAK EXCEEDED 90 PERCENT'

        WHEN historical_warning_resources > 0
        THEN 'HISTORICAL RESOURCE PEAK EXCEEDED 80 PERCENT'

        ELSE 'NO RESOURCE LIMIT ALERT'
    END AS primary_monitoring_message
FROM
    resource_state;

PROMPT
PROMPT Resource Limit Inventory Completed
