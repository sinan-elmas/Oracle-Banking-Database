-- ============================================================================
-- Report 10: Monthly Successful Transaction Channel Performance Pivot
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Compares monthly successful transaction counts across banking channels
--   and presents channel activity in a dashboard-friendly pivot format.
--
-- Reporting Grain
--   One row per calendar month.
--
-- Main SQL Features
--   * Common Table Expression (CTE)
--   * Aggregate Functions
--   * Oracle PIVOT
--   * NVL
--
-- Important Assumptions
--   * Only transactions whose status is SUCCESS are included.
--   * Transaction performance is measured by transaction count, not amount.
--   * The pivot contains the five channels currently defined by the project:
--     ATM, BRANCH, INTERNET, MOBILE, and POS.
--   * If a new channel is added to TRANSACTION_CHANNELS, the static PIVOT list
--     must also be updated.
--   * Months without any successful transaction activity are not returned.
-- ============================================================================

WITH monthly_channel_summary AS
(
    SELECT
        TRUNC(trx.transaction_date, 'MM') AS transaction_month,
        trx_channel.channel_name,
        COUNT(trx.transaction_id) AS successful_transactions

    FROM transactions trx

    JOIN transaction_channels trx_channel
      ON trx_channel.channel_id = trx.channel_id

    WHERE trx.status = 'SUCCESS'

    GROUP BY
        TRUNC(trx.transaction_date, 'MM'),
        trx_channel.channel_name
)

SELECT
    transaction_month,

    NVL(atm_transactions, 0)      AS atm_transactions,
    NVL(branch_transactions, 0)   AS branch_transactions,
    NVL(internet_transactions, 0) AS internet_transactions,
    NVL(mobile_transactions, 0)   AS mobile_transactions,
    NVL(pos_transactions, 0)      AS pos_transactions,

    NVL(atm_transactions, 0)
    + NVL(branch_transactions, 0)
    + NVL(internet_transactions, 0)
    + NVL(mobile_transactions, 0)
    + NVL(pos_transactions, 0) AS total_successful_transactions

FROM monthly_channel_summary

PIVOT
(
    SUM(successful_transactions)

    FOR channel_name IN
    (
        'ATM'      AS atm_transactions,
        'BRANCH'   AS branch_transactions,
        'INTERNET' AS internet_transactions,
        'MOBILE'   AS mobile_transactions,
        'POS'      AS pos_transactions
    )
)

ORDER BY
    transaction_month;