-- ============================================================================
-- Report 13: Executive Banking KPI Dashboard
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Provides a single-row executive overview of the banking system, including
--   customer, account, portfolio, transaction, branch, channel, and
--   transaction-type KPIs.
--
-- Reporting Grain
--   One row for the entire banking system.
--
-- Main SQL Features
--   * Common Table Expressions (CTE)
--   * ROW_NUMBER
--   * Currency Conversion
--   * Conditional Aggregation
--   * Aggregate Functions
--   * CROSS JOIN
--   * CASE
--
-- Important Assumptions
--   * TRY is used as the reporting base currency.
--   * The latest available BUY_RATE is used to convert foreign-currency
--     account balances and successful transaction amounts into TRY.
--   * A conversion rate of 1 is used for TRY-denominated accounts.
--   * Only transactions whose status is SUCCESS are included in transaction
--     KPIs and activity rankings.
--   * Branch activity is attributed through SOURCE_ACCOUNT_ID.
--   * If at least one required exchange rate is missing, financial valuation
--     is marked as incomplete.
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

customer_summary AS
(
    SELECT
        COUNT(*) AS total_customers,

        SUM(
            CASE
                WHEN customer_type = 'I' THEN 1
                ELSE 0
            END
        ) AS individual_customers,

        SUM(
            CASE
                WHEN customer_type = 'C' THEN 1
                ELSE 0
            END
        ) AS corporate_customers

    FROM customers
),

account_summary AS
(
    SELECT
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
        ) AS total_balance_try,

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
        ) AS average_balance_try,

        SUM(
            CASE
                WHEN acc.currency_id <> base_curr.currency_id
                 AND rate.buy_rate IS NULL
                    THEN 1
                ELSE 0
            END
        ) AS accounts_missing_exchange_rate

    FROM accounts acc

    CROSS JOIN base_currency base_curr

    LEFT JOIN latest_exchange_rates rate
           ON rate.currency_id = acc.currency_id
          AND rate.base_currency_id = base_curr.currency_id
),

transaction_summary AS
(
    SELECT
        COUNT(*) AS successful_transactions,

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

        SUM(
            CASE
                WHEN acc.currency_id <> base_curr.currency_id
                 AND rate.buy_rate IS NULL
                    THEN 1
                ELSE 0
            END
        ) AS transactions_missing_exchange_rate

    FROM transactions trx

    JOIN accounts acc
      ON acc.account_id = trx.source_account_id

    CROSS JOIN base_currency base_curr

    LEFT JOIN latest_exchange_rates rate
           ON rate.currency_id = acc.currency_id
          AND rate.base_currency_id = base_curr.currency_id

    WHERE trx.status = 'SUCCESS'
),

top_branch AS
(
    SELECT
        branch_name,
        successful_transactions

    FROM
    (
        SELECT
            branch.branch_id,
            branch.branch_name,

            COUNT(trx.transaction_id) AS successful_transactions,

            ROW_NUMBER() OVER
            (
                ORDER BY
                    COUNT(trx.transaction_id) DESC,
                    branch.branch_id
            ) AS row_num

        FROM branches branch

        JOIN accounts acc
          ON acc.branch_id = branch.branch_id

        JOIN transactions trx
          ON trx.source_account_id = acc.account_id

        WHERE trx.status = 'SUCCESS'

        GROUP BY
            branch.branch_id,
            branch.branch_name
    )

    WHERE row_num = 1
),

top_channel AS
(
    SELECT
        channel_name,
        successful_transactions

    FROM
    (
        SELECT
            trx_channel.channel_id,
            trx_channel.channel_name,

            COUNT(trx.transaction_id) AS successful_transactions,

            ROW_NUMBER() OVER
            (
                ORDER BY
                    COUNT(trx.transaction_id) DESC,
                    trx_channel.channel_id
            ) AS row_num

        FROM transaction_channels trx_channel

        JOIN transactions trx
          ON trx.channel_id = trx_channel.channel_id

        WHERE trx.status = 'SUCCESS'

        GROUP BY
            trx_channel.channel_id,
            trx_channel.channel_name
    )

    WHERE row_num = 1
),

top_transaction_type AS
(
    SELECT
        type_name,
        successful_transactions

    FROM
    (
        SELECT
            trx_type.transaction_type_id,
            trx_type.type_name,

            COUNT(trx.transaction_id) AS successful_transactions,

            ROW_NUMBER() OVER
            (
                ORDER BY
                    COUNT(trx.transaction_id) DESC,
                    trx_type.transaction_type_id
            ) AS row_num

        FROM transaction_types trx_type

        JOIN transactions trx
          ON trx.transaction_type_id =
             trx_type.transaction_type_id

        WHERE trx.status = 'SUCCESS'

        GROUP BY
            trx_type.transaction_type_id,
            trx_type.type_name
    )

    WHERE row_num = 1
)

SELECT
    base_curr.currency_code AS base_currency_code,

    cust.total_customers,
    cust.individual_customers,
    cust.corporate_customers,

    acc.total_accounts,
    acc.total_balance_try,
    acc.average_balance_try,

    trx.successful_transactions,
    trx.total_transaction_volume_try,
    trx.average_transaction_amount_try,

    CASE
        WHEN acc.accounts_missing_exchange_rate > 0
          OR trx.transactions_missing_exchange_rate > 0
            THEN 'Incomplete Valuation'
        ELSE 'Complete'
    END AS financial_valuation_status,

    branch.branch_name AS most_active_branch,
    branch.successful_transactions AS branch_transaction_count,

    channel.channel_name AS most_used_channel,
    channel.successful_transactions AS channel_transaction_count,

    trx_type.type_name AS most_used_transaction_type,
    trx_type.successful_transactions AS transaction_type_count

FROM customer_summary cust

CROSS JOIN account_summary acc
CROSS JOIN transaction_summary trx
CROSS JOIN top_branch branch
CROSS JOIN top_channel channel
CROSS JOIN top_transaction_type trx_type
CROSS JOIN base_currency base_curr;