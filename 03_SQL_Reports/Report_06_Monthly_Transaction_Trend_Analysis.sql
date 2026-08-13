-- ============================================================================
-- Report 06: Monthly Transaction Trend and Growth Analysis by Currency
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Analyzes monthly successful outgoing transaction activity, customer
--   participation, transaction volume, and month-over-month growth separately
--   for each currency.
--
-- Reporting Grain
--   One row per calendar month and transaction currency.
--
-- Main SQL Features
--   * Common Table Expressions (CTE)
--   * CONNECT BY
--   * Conditional Classification
--   * Aggregate Functions
--   * LAG
--   * DENSE_RANK
--   * NULLIF
--   * Date Arithmetic
--
-- Important Assumptions
--   * Transaction activity is attributed through SOURCE_ACCOUNT_ID.
--   * Only transactions whose status is SUCCESS are included.
--   * Transaction amounts are reported in the source account currency.
--   * Amounts in different currencies are never added together.
--   * Calendar months without successful transaction activity are retained
--     with zero-valued metrics.
--   * Month-over-month growth is calculated against the immediately preceding
--     calendar month within the same currency.
--   * Growth from a previous-month value of zero is reported as undefined.
-- ============================================================================

WITH transaction_base AS
(
    SELECT
        trx.transaction_id,
        TRUNC(trx.transaction_date, 'MM') AS transaction_month,

        acc.customer_id,
        acc.currency_id,

        trx.amount

    FROM transactions trx

    JOIN accounts acc
      ON acc.account_id = trx.source_account_id

    WHERE trx.status = 'SUCCESS'
),

date_boundaries AS
(
    SELECT
        MIN(transaction_month) AS first_month,
        MAX(transaction_month) AS last_month

    FROM transaction_base
),

month_calendar AS
(
    SELECT
        ADD_MONTHS(
            boundaries.first_month,
            LEVEL - 1
        ) AS transaction_month

    FROM date_boundaries boundaries

    CONNECT BY LEVEL <=
        MONTHS_BETWEEN(
            boundaries.last_month,
            boundaries.first_month
        ) + 1
),

active_currencies AS
(
    SELECT DISTINCT
        base.currency_id

    FROM transaction_base base
),

report_dimensions AS
(
    SELECT
        calendar.transaction_month,
        active_currency.currency_id

    FROM month_calendar calendar

    CROSS JOIN active_currencies active_currency
),

monthly_transaction_summary AS
(
    SELECT
        dimensions.transaction_month,
        dimensions.currency_id,

        COUNT(base.transaction_id) AS total_transactions,

        COUNT(
            DISTINCT base.customer_id
        ) AS active_customers,

        NVL(
            SUM(base.amount),
            0
        ) AS total_transaction_amount,

        ROUND(
            NVL(
                AVG(base.amount),
                0
            ),
            2
        ) AS average_transaction_amount

    FROM report_dimensions dimensions

    LEFT JOIN transaction_base base
           ON base.transaction_month = dimensions.transaction_month
          AND base.currency_id = dimensions.currency_id

    GROUP BY
        dimensions.transaction_month,
        dimensions.currency_id
),

monthly_trend_analysis AS
(
    SELECT
        summary.*,

        LAG(summary.total_transaction_amount) OVER
        (
            PARTITION BY summary.currency_id
            ORDER BY summary.transaction_month
        ) AS previous_month_amount

    FROM monthly_transaction_summary summary
),

monthly_growth_analysis AS
(
    SELECT
        trend.*,

        trend.total_transaction_amount
        - trend.previous_month_amount
            AS monthly_change_amount,

        ROUND(
            (
                trend.total_transaction_amount
                - trend.previous_month_amount
            ) * 100
            / NULLIF(trend.previous_month_amount, 0),
            2
        ) AS monthly_change_percent

    FROM monthly_trend_analysis trend
)

SELECT
    growth.transaction_month,

    curr.currency_id,
    curr.currency_code,

    growth.total_transactions,
    growth.active_customers,

    growth.total_transaction_amount,
    growth.average_transaction_amount,

    growth.previous_month_amount,
    growth.monthly_change_amount,
    growth.monthly_change_percent,

    DENSE_RANK() OVER
    (
        PARTITION BY growth.currency_id
        ORDER BY growth.total_transaction_amount DESC
    ) AS volume_rank_within_currency,

    CASE
        WHEN growth.previous_month_amount IS NULL
            THEN 'No Previous Data'

        WHEN growth.previous_month_amount = 0
         AND growth.total_transaction_amount = 0
            THEN 'Stable - No Activity'

        WHEN growth.previous_month_amount = 0
         AND growth.total_transaction_amount > 0
            THEN 'Growth from Zero'

        WHEN growth.monthly_change_percent >= 10
            THEN 'Strong Growth'

        WHEN growth.monthly_change_percent > 0
            THEN 'Moderate Growth'

        WHEN growth.monthly_change_percent = 0
            THEN 'Stable'

        WHEN growth.monthly_change_percent > -10
            THEN 'Moderate Decline'

        ELSE 'Strong Decline'
    END AS trend_status

FROM monthly_growth_analysis growth

JOIN currencies curr
  ON curr.currency_id = growth.currency_id

ORDER BY
    curr.currency_code,
    growth.transaction_month;