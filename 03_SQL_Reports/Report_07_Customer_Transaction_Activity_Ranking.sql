-- ============================================================================
-- Report 07: Customer Transaction Activity Ranking
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Ranks customers according to successful outgoing transaction frequency
--   and transaction volume in a common reporting currency.
--
-- Reporting Grain
--   One row per customer.
--
-- Main SQL Features
--   * Common Table Expressions (CTE)
--   * ROW_NUMBER
--   * Currency Conversion
--   * Aggregate Functions
--   * DENSE_RANK
--   * CUME_DIST
--   * Conditional Classification
--   * LEFT JOIN
--   * CASE
--
-- Important Assumptions
--   * TRY is used as the reporting base currency.
--   * Transaction activity is attributed through SOURCE_ACCOUNT_ID.
--   * Only transactions whose status is SUCCESS are included.
--   * The latest available BUY_RATE is used to convert foreign-currency
--     transaction amounts into TRY.
--   * A conversion rate of 1 is used for transactions originating from
--     TRY-denominated accounts.
--   * Customers with missing exchange rates are not assigned volume-based
--     rankings or activity segments because their transaction valuation is
--     incomplete.
--   * Customers without successful outgoing transactions remain in the report
--     and are classified as No Activity.
--   * Activity segments are based on transaction-volume distribution:
--       - Top 10%             : Elite Activity
--       - Above 10% to 30%    : High Activity
--       - Above 30% to 60%    : Medium Activity
--       - Remaining customers : Standard Activity
-- ============================================================================

WITH report_parameters AS
(
    SELECT
        'TRY' AS base_currency_code
    FROM dual
),

base_currency AS
(
    SELECT
        curr.currency_id,
        curr.currency_code

    FROM currencies curr

    CROSS JOIN report_parameters params

    WHERE curr.currency_code = params.base_currency_code
),

latest_exchange_rates AS
(
    SELECT
        currency_id,
        base_currency_id,
        buy_rate

    FROM
    (
        SELECT
            er.currency_id,
            er.base_currency_id,
            er.buy_rate,

            ROW_NUMBER() OVER
            (
                PARTITION BY
                    er.currency_id,
                    er.base_currency_id
                ORDER BY
                    er.rate_date DESC,
                    er.rate_id DESC
            ) AS row_num

        FROM exchange_rates er
    )

    WHERE row_num = 1
),

account_summary AS
(
    SELECT
        acc.customer_id,
        COUNT(*) AS total_accounts

    FROM accounts acc

    GROUP BY
        acc.customer_id
),

transaction_summary AS
(
    SELECT
        acc.customer_id,

        COUNT(trx.transaction_id) AS successful_transactions,

        ROUND(
            SUM(
                CASE
                    WHEN acc.currency_id = base_curr.currency_id
                        THEN trx.amount

                    WHEN rate.buy_rate IS NOT NULL
                        THEN trx.amount * rate.buy_rate
                END
            ),
            2
        ) AS total_transaction_amount_try,

        ROUND(
            AVG(
                CASE
                    WHEN acc.currency_id = base_curr.currency_id
                        THEN trx.amount

                    WHEN rate.buy_rate IS NOT NULL
                        THEN trx.amount * rate.buy_rate
                END
            ),
            2
        ) AS average_transaction_amount_try,

        SUM(
            CASE
                WHEN acc.currency_id <> base_curr.currency_id
                 AND rate.buy_rate IS NULL
                    THEN 1
                ELSE 0
            END
        ) AS missing_rate_transactions

    FROM accounts acc

    JOIN transactions trx
      ON trx.source_account_id = acc.account_id

    CROSS JOIN base_currency base_curr

    LEFT JOIN latest_exchange_rates rate
           ON rate.currency_id = acc.currency_id
          AND rate.base_currency_id = base_curr.currency_id

    WHERE trx.status = 'SUCCESS'

    GROUP BY
        acc.customer_id
),

customer_activity AS
(
    SELECT
        cust.customer_id,
        cust.customer_type,
        cust.status AS customer_status,

        base_curr.currency_code AS base_currency_code,

        NVL(
            acc_sum.total_accounts,
            0
        ) AS total_accounts,

        NVL(
            trx_sum.successful_transactions,
            0
        ) AS successful_transactions,

        NVL(
            trx_sum.total_transaction_amount_try,
            0
        ) AS total_transaction_amount_try,

        NVL(
            trx_sum.average_transaction_amount_try,
            0
        ) AS average_transaction_amount_try,

        NVL(
            trx_sum.missing_rate_transactions,
            0
        ) AS missing_rate_transactions

    FROM customers cust

    CROSS JOIN base_currency base_curr

    LEFT JOIN account_summary acc_sum
           ON acc_sum.customer_id = cust.customer_id

    LEFT JOIN transaction_summary trx_sum
           ON trx_sum.customer_id = cust.customer_id
),

eligible_customer_ranking AS
(
    SELECT
        activity.customer_id,

        DENSE_RANK() OVER
        (
            ORDER BY
                activity.successful_transactions DESC
        ) AS activity_rank,

        DENSE_RANK() OVER
        (
            ORDER BY
                activity.total_transaction_amount_try DESC
        ) AS volume_rank,

        CUME_DIST() OVER
        (
            ORDER BY
                activity.total_transaction_amount_try DESC
        ) AS transaction_volume_percentile

    FROM customer_activity activity

    WHERE activity.successful_transactions > 0
      AND activity.missing_rate_transactions = 0
),

classified_customers AS
(
    SELECT
        activity.*,
        ranking.activity_rank,
        ranking.volume_rank,
        ranking.transaction_volume_percentile,

        CASE
            WHEN activity.successful_transactions = 0
                THEN 'No Activity'

            WHEN activity.missing_rate_transactions > 0
                THEN 'Incomplete Valuation'

            WHEN ranking.transaction_volume_percentile <= 0.10
                THEN 'Elite Activity'

            WHEN ranking.transaction_volume_percentile <= 0.30
                THEN 'High Activity'

            WHEN ranking.transaction_volume_percentile <= 0.60
                THEN 'Medium Activity'

            ELSE 'Standard Activity'
        END AS activity_segment

    FROM customer_activity activity

    LEFT JOIN eligible_customer_ranking ranking
           ON ranking.customer_id = activity.customer_id
)

SELECT
    customer_id,
    customer_type,
    customer_status,

    activity_segment,
    volume_rank,
    activity_rank,

    base_currency_code,

    total_accounts,
    successful_transactions,

    total_transaction_amount_try,
    average_transaction_amount_try

FROM classified_customers

ORDER BY
    volume_rank NULLS LAST,
    activity_rank NULLS LAST,
    customer_id;