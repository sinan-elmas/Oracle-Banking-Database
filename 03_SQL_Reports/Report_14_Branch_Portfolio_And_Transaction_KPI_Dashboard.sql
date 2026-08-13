-- ============================================================================
-- Report 14: Branch Portfolio and Transaction KPI Dashboard
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Provides a branch-level KPI dashboard combining customer reach, account
--   portfolio value, successful transaction activity, channel usage, and
--   operational efficiency metrics.
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
--   * LEFT JOIN
--   * CASE
--
-- Important Assumptions
--   * TRY is used as the reporting base currency.
--   * The latest available BUY_RATE is used to convert foreign-currency
--     balances and successful transaction amounts into TRY.
--   * A conversion rate of 1 is used for TRY-denominated accounts.
--   * Transaction activity is attributed to the branch of SOURCE_ACCOUNT_ID.
--   * Only transactions whose status is SUCCESS are included in transaction
--     KPIs, channel analysis, and transaction rankings.
--   * Branches with missing exchange rates are not assigned financial ranks
--     or transaction-volume segments because their valuation is incomplete.
--   * Transaction-volume segments are based on branch distribution:
--       - Top 10%             : Very High Volume
--       - Above 10% to 30%    : High Volume
--       - Above 30% to 60%    : Medium Volume
--       - Remaining branches  : Low Volume
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
        branch.branch_id,
        branch.branch_name,

        COUNT(DISTINCT acc.customer_id) AS total_customers,
        COUNT(acc.account_id) AS total_accounts,

        SUM(
            CASE
                WHEN acc.status = 'ACTIVE' THEN 1
                ELSE 0
            END
        ) AS active_accounts,

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
        ) AS total_account_balance_try,

        ROUND(
            AVG(
                CASE
                    WHEN acc.currency_id = base_curr.currency_id
                        THEN acc.balance

                    WHEN rate.buy_rate IS NOT NULL
                        THEN acc.balance * rate.buy_rate
                END
            ),
            2
        ) AS average_account_balance_try,

        SUM(
            CASE
                WHEN acc.currency_id <> base_curr.currency_id
                 AND rate.buy_rate IS NULL
                    THEN 1
                ELSE 0
            END
        ) AS accounts_missing_exchange_rate

    FROM branches branch

    CROSS JOIN base_currency base_curr

    LEFT JOIN accounts acc
           ON acc.branch_id = branch.branch_id

    LEFT JOIN latest_exchange_rates rate
           ON rate.currency_id = acc.currency_id
          AND rate.base_currency_id = base_curr.currency_id

    GROUP BY
        branch.branch_id,
        branch.branch_name
),

branch_transaction_summary AS
(
    SELECT
        acc.branch_id,

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
        ) AS total_transaction_volume_try,

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

        COUNT(
            DISTINCT TRUNC(trx.transaction_date)
        ) AS active_transaction_days,

        SUM(
            CASE
                WHEN acc.currency_id <> base_curr.currency_id
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

    WHERE trx.status = 'SUCCESS'

    GROUP BY
        acc.branch_id
),

branch_channel_summary AS
(
    SELECT
        branch_id,
        channel_name,
        channel_transaction_count

    FROM
    (
        SELECT
            acc.branch_id,
            trx_channel.channel_id,
            trx_channel.channel_name,

            COUNT(trx.transaction_id) AS channel_transaction_count,

            ROW_NUMBER() OVER
            (
                PARTITION BY acc.branch_id
                ORDER BY
                    COUNT(trx.transaction_id) DESC,
                    trx_channel.channel_id
            ) AS channel_rank

        FROM accounts acc

        JOIN transactions trx
          ON trx.source_account_id = acc.account_id

        JOIN transaction_channels trx_channel
          ON trx_channel.channel_id = trx.channel_id

        WHERE trx.status = 'SUCCESS'

        GROUP BY
            acc.branch_id,
            trx_channel.channel_id,
            trx_channel.channel_name
    )

    WHERE channel_rank = 1
),

branch_kpi_analysis AS
(
    SELECT
        acc_sum.branch_id,
        acc_sum.branch_name,

        base_curr.currency_code AS base_currency_code,

        acc_sum.total_customers,
        acc_sum.total_accounts,
        acc_sum.active_accounts,

        NVL(
            acc_sum.total_account_balance_try,
            0
        ) AS total_account_balance_try,

        NVL(
            acc_sum.average_account_balance_try,
            0
        ) AS average_account_balance_try,

        NVL(
            trx_sum.successful_transactions,
            0
        ) AS successful_transactions,

        NVL(
            trx_sum.total_transaction_volume_try,
            0
        ) AS total_transaction_volume_try,

        NVL(
            trx_sum.average_transaction_amount_try,
            0
        ) AS average_transaction_amount_try,

        NVL(
            trx_sum.active_transaction_days,
            0
        ) AS active_transaction_days,

        NVL(
            channel_sum.channel_name,
            'NO TRANSACTION'
        ) AS most_active_channel,

        NVL(
            channel_sum.channel_transaction_count,
            0
        ) AS channel_transaction_count,

        NVL(
            ROUND(
                acc_sum.total_accounts
                / NULLIF(acc_sum.total_customers, 0),
                2
            ),
            0
        ) AS accounts_per_customer,

        NVL(
            ROUND(
                NVL(trx_sum.successful_transactions, 0)
                / NULLIF(acc_sum.total_accounts, 0),
                2
            ),
            0
        ) AS transactions_per_account,

        NVL(
            ROUND(
                NVL(trx_sum.total_transaction_volume_try, 0)
                / NULLIF(acc_sum.total_customers, 0),
                2
            ),
            0
        ) AS transaction_volume_per_customer_try,

        NVL(
            acc_sum.accounts_missing_exchange_rate,
            0
        ) AS accounts_missing_exchange_rate,

        NVL(
            trx_sum.transactions_missing_exchange_rate,
            0
        ) AS transactions_missing_exchange_rate

    FROM branch_account_summary acc_sum

    CROSS JOIN base_currency base_curr

    LEFT JOIN branch_transaction_summary trx_sum
           ON trx_sum.branch_id = acc_sum.branch_id

    LEFT JOIN branch_channel_summary channel_sum
           ON channel_sum.branch_id = acc_sum.branch_id
),

eligible_branch_ranking AS
(
    SELECT
        branch_kpi.branch_id,

        DENSE_RANK() OVER
        (
            ORDER BY
                branch_kpi.total_transaction_volume_try DESC
        ) AS transaction_volume_rank,

        DENSE_RANK() OVER
        (
            ORDER BY
                branch_kpi.total_account_balance_try DESC
        ) AS account_balance_rank,

        DENSE_RANK() OVER
        (
            ORDER BY
                branch_kpi.total_customers DESC
        ) AS customer_portfolio_rank,

        DENSE_RANK() OVER
        (
            ORDER BY
                branch_kpi.transactions_per_account DESC
        ) AS transaction_efficiency_rank,

        CUME_DIST() OVER
        (
            ORDER BY
                branch_kpi.total_transaction_volume_try DESC
        ) AS transaction_volume_percentile

    FROM branch_kpi_analysis branch_kpi

    WHERE branch_kpi.accounts_missing_exchange_rate = 0
      AND branch_kpi.transactions_missing_exchange_rate = 0
)

SELECT
    branch_kpi.branch_id,
    branch_kpi.branch_name,

    CASE
        WHEN branch_kpi.accounts_missing_exchange_rate > 0
          OR branch_kpi.transactions_missing_exchange_rate > 0
            THEN 'Incomplete Valuation'

        WHEN ranking.transaction_volume_percentile <= 0.10
            THEN 'Very High Volume'

        WHEN ranking.transaction_volume_percentile <= 0.30
            THEN 'High Volume'

        WHEN ranking.transaction_volume_percentile <= 0.60
            THEN 'Medium Volume'

        ELSE 'Low Volume'
    END AS transaction_volume_segment,

    ranking.transaction_volume_rank,
    ranking.account_balance_rank,
    ranking.customer_portfolio_rank,
    ranking.transaction_efficiency_rank,

    branch_kpi.base_currency_code,

    branch_kpi.total_customers,
    branch_kpi.total_accounts,
    branch_kpi.active_accounts,

    branch_kpi.total_account_balance_try,
    branch_kpi.average_account_balance_try,

    branch_kpi.successful_transactions,
    branch_kpi.total_transaction_volume_try,
    branch_kpi.average_transaction_amount_try,
    branch_kpi.active_transaction_days,

    branch_kpi.most_active_channel,
    branch_kpi.channel_transaction_count,

    branch_kpi.accounts_per_customer,
    branch_kpi.transactions_per_account,
    branch_kpi.transaction_volume_per_customer_try

FROM branch_kpi_analysis branch_kpi

LEFT JOIN eligible_branch_ranking ranking
       ON ranking.branch_id = branch_kpi.branch_id

ORDER BY
    ranking.transaction_volume_rank NULLS LAST,
    ranking.transaction_efficiency_rank NULLS LAST,
    branch_kpi.branch_id;