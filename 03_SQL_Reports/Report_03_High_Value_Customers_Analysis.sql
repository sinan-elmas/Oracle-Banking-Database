-- ============================================================================
-- Report 03: High-Value Customers Analysis
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Identifies and ranks high-value customers according to the total value of
--   their account portfolio in a common reporting currency.
--
-- Reporting Grain
--   One row per customer.
--
-- Main SQL Features
--   * Common Table Expressions (CTE)
--   * ROW_NUMBER
--   * Currency Conversion
--   * Conditional Aggregation
--   * DENSE_RANK
--   * CASE
--   * LEFT JOIN
--
-- Important Assumptions
--   * TRY is used as the reporting base currency.
--   * The latest available BUY_RATE is used to value foreign-currency
--     account balances.
--   * A conversion rate of 1 is used for accounts already denominated in TRY.
--   * Customers with at least one missing exchange rate are not assigned a
--     customer level or portfolio rank because their portfolio value is
--     incomplete.
--   * Customer-level thresholds are expressed in TRY.
-- ============================================================================

WITH report_parameters AS
(
    SELECT
        'TRY'   AS base_currency_code,
        1000000 AS platinum_threshold,
        500000  AS gold_threshold,
        100000  AS silver_threshold
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

        COUNT(*) AS total_accounts,

        ROUND(
            SUM(
                CASE
                    WHEN acc.currency_id = base_curr.currency_id
                        THEN acc.balance

                    WHEN rate.buy_rate IS NOT NULL
                        THEN acc.balance * rate.buy_rate
                END
            ),
            2
        ) AS portfolio_value_try,

        SUM(
            CASE
                WHEN acc.currency_id <> base_curr.currency_id
                 AND rate.buy_rate IS NULL
                    THEN 1
                ELSE 0
            END
        ) AS missing_rate_accounts

    FROM accounts acc

    CROSS JOIN base_currency base_curr

    LEFT JOIN latest_exchange_rates rate
           ON rate.currency_id = acc.currency_id
          AND rate.base_currency_id = base_curr.currency_id

    GROUP BY
        acc.customer_id
),

card_summary AS
(
    SELECT
        acc.customer_id,
        COUNT(card.card_id) AS total_cards

    FROM accounts acc

    JOIN cards card
      ON card.account_id = acc.account_id

    GROUP BY
        acc.customer_id
),

transaction_summary AS
(
    SELECT
        acc.customer_id,

        SUM(
            CASE
                WHEN trx.status = 'SUCCESS' THEN 1
                ELSE 0
            END
        ) AS successful_transactions

    FROM accounts acc

    JOIN transactions trx
      ON trx.source_account_id = acc.account_id

    GROUP BY
        acc.customer_id
),

customer_portfolio AS
(
    SELECT
        cust.customer_id,
        cust.customer_type,
        cust.status AS customer_status,

        base_curr.currency_code AS base_currency_code,

        NVL(
            acc_sum.portfolio_value_try,
            0
        ) AS portfolio_value_try,

        NVL(
            acc_sum.total_accounts,
            0
        ) AS total_accounts,

        NVL(
            card_sum.total_cards,
            0
        ) AS total_cards,

        NVL(
            trx_sum.successful_transactions,
            0
        ) AS successful_transactions,

        NVL(
            acc_sum.missing_rate_accounts,
            0
        ) AS missing_rate_accounts

    FROM customers cust

    CROSS JOIN base_currency base_curr

    LEFT JOIN account_summary acc_sum
           ON acc_sum.customer_id = cust.customer_id

    LEFT JOIN card_summary card_sum
           ON card_sum.customer_id = cust.customer_id

    LEFT JOIN transaction_summary trx_sum
           ON trx_sum.customer_id = cust.customer_id
),

classified_customers AS
(
    SELECT
        portfolio.*,

        CASE
            WHEN portfolio.missing_rate_accounts > 0
                THEN NULL

            WHEN portfolio.portfolio_value_try
                 >= params.platinum_threshold
                THEN 'Platinum'

            WHEN portfolio.portfolio_value_try
                 >= params.gold_threshold
                THEN 'Gold'

            WHEN portfolio.portfolio_value_try
                 >= params.silver_threshold
                THEN 'Silver'

            ELSE 'Standard'
        END AS customer_level

    FROM customer_portfolio portfolio

    CROSS JOIN report_parameters params
),

ranked_customers AS
(
    SELECT
        classified.*,

        CASE
            WHEN classified.missing_rate_accounts = 0
                THEN DENSE_RANK() OVER
                     (
                         ORDER BY
                             CASE
                                 WHEN classified.missing_rate_accounts = 0
                                     THEN classified.portfolio_value_try
                             END DESC NULLS LAST
                     )
        END AS portfolio_rank

    FROM classified_customers classified
)

SELECT
    customer_id,
    customer_type,
    customer_status,

    customer_level,
    portfolio_rank,

    base_currency_code,
    portfolio_value_try,

    total_accounts,
    total_cards,
    successful_transactions

FROM ranked_customers

ORDER BY
    portfolio_rank NULLS LAST,
    customer_id;