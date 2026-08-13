-- ============================================================================
-- Report 05: Dormant Account Detection
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Identifies active accounts with limited or no successful outgoing
--   transaction activity and classifies them according to inactivity duration.
--
-- Reporting Grain
--   One row per active account.
--
-- Main SQL Features
--   * Common Table Expressions (CTE)
--   * Aggregate Functions
--   * Conditional Classification
--   * Date Arithmetic
--   * LEFT JOIN
--   * NVL
--   * CASE
--
-- Important Assumptions
--   * Account activity is measured using successful outgoing transactions
--     linked through SOURCE_ACCOUNT_ID.
--   * Failed, pending, or otherwise unsuccessful transactions do not reset
--     the inactivity period.
--   * For an account with no successful outgoing transaction, OPENING_DATE is
--     used as the last activity date.
--   * Only accounts whose current status is ACTIVE are evaluated.
--   * Dormancy thresholds are centralized in REPORT_PARAMETERS.
--   * Balances are displayed in their original account currency and are not
--     aggregated across currencies.
-- ============================================================================

WITH report_parameters AS
(
    SELECT
        30  AS active_day_limit,
        90  AS inactive_day_limit,
        180 AS dormant_day_limit
    FROM dual
),

transaction_summary AS
(
    SELECT
        trx.source_account_id AS account_id,
        MAX(trx.transaction_date) AS last_successful_transaction_date

    FROM transactions trx

    WHERE trx.status = 'SUCCESS'

    GROUP BY
        trx.source_account_id
),

account_activity AS
(
    SELECT
        acc.account_id,
        acc.account_number,

        cust.customer_id,
        cust.customer_type,

        curr.currency_code,
        acc.balance,

        NVL(
            trx_sum.last_successful_transaction_date,
            acc.opening_date
        ) AS last_activity_date

    FROM accounts acc

    JOIN customers cust
      ON cust.customer_id = acc.customer_id

    JOIN currencies curr
      ON curr.currency_id = acc.currency_id

    LEFT JOIN transaction_summary trx_sum
           ON trx_sum.account_id = acc.account_id

    WHERE acc.status = 'ACTIVE'
),

classified_accounts AS
(
    SELECT
        activity.*,

        TRUNC(SYSDATE)
        - TRUNC(activity.last_activity_date)
            AS days_since_activity

    FROM account_activity activity
)

SELECT
    account_number,

    customer_id,
    customer_type,

    currency_code,
    balance,

    last_activity_date,
    days_since_activity,

    CASE
        WHEN last_activity_date > TRUNC(SYSDATE)
            THEN 'Data Issue - Future Date'

        WHEN days_since_activity <= params.active_day_limit
            THEN 'Active'

        WHEN days_since_activity <= params.inactive_day_limit
            THEN 'Inactive'

        WHEN days_since_activity <= params.dormant_day_limit
            THEN 'Dormant'

        ELSE 'Long-Term Dormant'
    END AS dormant_status

FROM classified_accounts

CROSS JOIN report_parameters params

ORDER BY
    CASE
        WHEN last_activity_date > TRUNC(SYSDATE) THEN 1
        WHEN days_since_activity > params.dormant_day_limit THEN 2
        WHEN days_since_activity > params.inactive_day_limit THEN 3
        WHEN days_since_activity > params.active_day_limit THEN 4
        ELSE 5
    END,
    days_since_activity DESC,
    currency_code,
    balance DESC,
    account_number;