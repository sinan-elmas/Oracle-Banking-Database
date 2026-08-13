-- ============================================================================
-- Report 08: Top Transaction per Customer
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Identifies each customer's highest-value successful outgoing transaction
--   after converting transaction amounts into a common reporting currency.
--
-- Reporting Grain
--   One row per customer with at least one successfully valued outgoing
--   transaction.
--
-- Main SQL Features
--   * Common Table Expressions (CTE)
--   * ROW_NUMBER
--   * Currency Conversion
--   * CASE
--   * Multi-Table JOIN
--
-- Important Assumptions
--   * TRY is used as the reporting base currency.
--   * Transaction activity is attributed through SOURCE_ACCOUNT_ID.
--   * Only successful outgoing transaction types are evaluated.
--   * DEPOSIT transactions are excluded because they represent incoming funds.
--   * The latest available BUY_RATE is used to convert foreign-currency
--     transaction amounts into TRY.
--   * A conversion rate of 1 is used for transactions originating from
--     TRY-denominated accounts.
--   * Transactions without an available exchange rate are excluded because
--     their value cannot be compared reliably with other currencies.
--   * If two transactions have the same TRY value, the more recent
--     transaction is selected. TRANSACTION_ID is the final tie-breaker.
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

valued_transactions AS
(
    SELECT
        cust.customer_id,
        cust.customer_type,
        cust.status AS customer_status,

        acc.account_number,

        source_currency.currency_code
            AS transaction_currency_code,

        trx.transaction_id,
        trx.transaction_date,

        trx.amount AS original_transaction_amount,

        base_curr.currency_code AS base_currency_code,

        ROUND(
            CASE
                WHEN acc.currency_id = base_curr.currency_id
                    THEN trx.amount
                WHEN rate.buy_rate IS NOT NULL
                    THEN trx.amount * rate.buy_rate
            END,
            2
        ) AS transaction_amount_try,

        trx_type.type_name AS transaction_type,
        trx_channel.channel_name AS transaction_channel

    FROM customers cust

    JOIN accounts acc
      ON acc.customer_id = cust.customer_id

    JOIN currencies source_currency
      ON source_currency.currency_id = acc.currency_id

    JOIN transactions trx
      ON trx.source_account_id = acc.account_id

    JOIN transaction_types trx_type
      ON trx_type.transaction_type_id = trx.transaction_type_id

    JOIN transaction_channels trx_channel
      ON trx_channel.channel_id = trx.channel_id

    CROSS JOIN base_currency base_curr

    LEFT JOIN latest_exchange_rates rate
           ON rate.currency_id = acc.currency_id
          AND rate.base_currency_id = base_curr.currency_id

    WHERE trx.status = 'SUCCESS'
      AND trx_type.type_name IN
          (
              'TRANSFER',
              'WITHDRAWAL',
              'PAYMENT',
              'FX_BUY',
              'FX_SELL'
          )
),

customer_transaction_ranking AS
(
    SELECT
        valued.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY valued.customer_id
            ORDER BY
                valued.transaction_amount_try DESC,
                valued.transaction_date DESC,
                valued.transaction_id DESC
        ) AS transaction_rank
    FROM valued_transactions valued
    WHERE valued.transaction_amount_try IS NOT NULL
)

SELECT
    customer_id,
    customer_type,
    customer_status,

    transaction_id,
    transaction_date,

    account_number,

    transaction_type,
    transaction_channel,

    transaction_currency_code,
    original_transaction_amount,

    base_currency_code,
    transaction_amount_try

FROM customer_transaction_ranking

WHERE transaction_rank = 1

ORDER BY
    transaction_amount_try DESC,
    customer_id;