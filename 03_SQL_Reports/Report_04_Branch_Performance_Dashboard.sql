-- ============================================================================
-- Report 04: Branch Performance Dashboard
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Evaluates and ranks branch performance according to customer reach,
--   account portfolio value, account density, and outgoing transaction
--   activity.
--
-- Reporting Grain
--   One row per branch.
--
-- Main SQL Features
--   * Common Table Expressions (CTE)
--   * ROW_NUMBER
--   * Currency Conversion
--   * Conditional Aggregation
--   * DENSE_RANK
--   * CUME_DIST
--   * NULLIF
--   * CASE
--   * LEFT JOIN
--
-- Important Assumptions
--   * TRY is used as the reporting base currency.
--   * The latest available BUY_RATE is used to value foreign-currency
--     balances and successful outgoing transaction amounts.
--   * A conversion rate of 1 is used for accounts already denominated in TRY.
--   * Transaction activity is attributed to the branch of SOURCE_ACCOUNT_ID.
--   * Only SUCCESS transactions are included in transaction-value totals.
--   * Branches with at least one missing exchange rate are not assigned a
--     performance category or branch rank because their financial valuation
--     is incomplete.
--   * Performance categories are based on branch portfolio distribution:
--       - Top 10%            : Excellent
--       - Above 10% to 30%   : Very Good
--       - Above 30% to 60%   : Good
--       - Remaining branches : Average
--   * Portfolio value is a point-in-time balance measure, while transaction
--     amount is an accumulated flow measure. Transaction volume may therefore
--     exceed portfolio value.
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

branch_account_summary AS
(
    SELECT
        acc.branch_id,

        COUNT(*) AS total_accounts,

        SUM(
            CASE
                WHEN acc.status = 'ACTIVE' THEN 1
                ELSE 0
            END
        ) AS active_accounts,

        COUNT(DISTINCT acc.customer_id) AS total_customers,

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
        acc.branch_id
),

branch_transaction_summary AS
(
    SELECT
        acc.branch_id,

        COUNT(trx.transaction_id) AS total_outgoing_transactions,

        SUM(
            CASE
                WHEN trx.status = 'SUCCESS' THEN 1
                ELSE 0
            END
        ) AS successful_transactions,

        ROUND(
            SUM(
                CASE
                    WHEN trx.status <> 'SUCCESS'
                        THEN 0

                    WHEN acc.currency_id = base_curr.currency_id
                        THEN trx.amount

                    WHEN rate.buy_rate IS NOT NULL
                        THEN trx.amount * rate.buy_rate
                END
            ),
            2
        ) AS successful_transaction_amount_try,

        SUM(
            CASE
                WHEN trx.status = 'SUCCESS'
                 AND acc.currency_id <> base_curr.currency_id
                 AND rate.buy_rate IS NULL
                    THEN 1
                ELSE 0
            END
        ) AS transactions_missing_exchange_rate

    FROM accounts acc

    JOIN transactions trx
      ON trx.source_account_id = acc.account_id

    CROSS JOIN base_currency base_curr

    LEFT JOIN latest_exchange_rates rate
           ON rate.currency_id = acc.currency_id
          AND rate.base_currency_id = base_curr.currency_id

    GROUP BY
        acc.branch_id
),

branch_performance AS
(
    SELECT
        branch.branch_id,
        branch.branch_name,

        base_curr.currency_code AS base_currency_code,

        NVL(acc_sum.total_customers, 0) AS total_customers,
        NVL(acc_sum.total_accounts, 0) AS total_accounts,
        NVL(acc_sum.active_accounts, 0) AS active_accounts,

        ROUND(
            NVL(acc_sum.total_accounts, 0)
            / NULLIF(acc_sum.total_customers, 0),
            2
        ) AS accounts_per_customer,

        NVL(
            acc_sum.portfolio_value_try,
            0
        ) AS portfolio_value_try,

        NVL(
            trx_sum.total_outgoing_transactions,
            0
        ) AS total_outgoing_transactions,

        NVL(
            trx_sum.successful_transactions,
            0
        ) AS successful_transactions,

        NVL(
            trx_sum.successful_transaction_amount_try,
            0
        ) AS successful_transaction_amount_try,

        NVL(
            acc_sum.missing_rate_accounts,
            0
        ) AS missing_rate_accounts,

        NVL(
            trx_sum.transactions_missing_exchange_rate,
            0
        ) AS transactions_missing_exchange_rate

    FROM branches branch

    CROSS JOIN base_currency base_curr

    LEFT JOIN branch_account_summary acc_sum
           ON acc_sum.branch_id = branch.branch_id

    LEFT JOIN branch_transaction_summary trx_sum
           ON trx_sum.branch_id = branch.branch_id
),

eligible_branch_distribution AS
(
    SELECT
        performance.branch_id,

        DENSE_RANK() OVER
        (
            ORDER BY
                performance.portfolio_value_try DESC
        ) AS branch_rank,

        CUME_DIST() OVER
        (
            ORDER BY
                performance.portfolio_value_try DESC
        ) AS portfolio_percentile

    FROM branch_performance performance

    WHERE performance.missing_rate_accounts = 0
),

classified_branches AS
(
    SELECT
        performance.*,
        distribution.branch_rank,
        distribution.portfolio_percentile,

        CASE
            WHEN performance.missing_rate_accounts > 0
                THEN NULL

            WHEN distribution.portfolio_percentile <= 0.10
                THEN 'Excellent'

            WHEN distribution.portfolio_percentile <= 0.30
                THEN 'Very Good'

            WHEN distribution.portfolio_percentile <= 0.60
                THEN 'Good'

            ELSE 'Average'
        END AS performance_category

    FROM branch_performance performance

    LEFT JOIN eligible_branch_distribution distribution
           ON distribution.branch_id = performance.branch_id
)

SELECT
    branch_id,
    branch_name,

    performance_category,
    branch_rank,

    base_currency_code,
    portfolio_value_try,

    total_customers,
    total_accounts,
    active_accounts,
    accounts_per_customer,

    total_outgoing_transactions,
    successful_transactions,
    successful_transaction_amount_try

FROM classified_branches

ORDER BY
    branch_rank NULLS LAST,
    branch_id;