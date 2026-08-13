-- ============================================================================
-- Report 12: Transaction Type and Channel Analysis with GROUPING SETS
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Summarizes successful transaction activity by transaction type,
--   transaction channel and currency using Oracle GROUPING SETS.
--
-- Reporting Grain
--   Detail rows:
--       Currency + Transaction Type + Channel
--
--   Summary rows:
--       Currency + Transaction Type
--       Currency + Channel
--       Currency Total
--
-- Main SQL Features
--   * GROUPING SETS
--   * GROUPING
--   * Aggregate Functions
--   * CASE
--   * NVL
-- ============================================================================

SELECT
    curr.currency_code,
    CASE
        WHEN GROUPING(trx_type.type_name) = 1
        THEN 'ALL TRANSACTION TYPES'
        ELSE trx_type.type_name
    END AS transaction_type,
    CASE
        WHEN GROUPING(trx_channel.channel_name) = 1
        THEN 'ALL CHANNELS'
        ELSE trx_channel.channel_name
    END AS transaction_channel,
    COUNT(*) AS successful_transactions,
    ROUND(SUM(trx.amount), 2) AS total_transaction_amount,
    ROUND(AVG(trx.amount), 2) AS average_transaction_amount,
    COUNT(DISTINCT trx.source_account_id) AS active_source_accounts
FROM transactions trx
JOIN accounts acc
    ON acc.account_id = trx.source_account_id
JOIN currencies curr
    ON curr.currency_id = acc.currency_id
JOIN transaction_types trx_type
    ON trx_type.transaction_type_id = trx.transaction_type_id
JOIN transaction_channels trx_channel
    ON trx_channel.channel_id = trx.channel_id
WHERE trx.status = 'SUCCESS'
GROUP BY GROUPING SETS
(
    (
        curr.currency_code,
        trx_type.type_name,
        trx_channel.channel_name
    ),
    (
        curr.currency_code,
        trx_type.type_name
    ),
    (
        curr.currency_code,
        trx_channel.channel_name
    ),
    (
        curr.currency_code
    )
)
ORDER BY
    curr.currency_code,
    GROUPING(trx_type.type_name),
    trx_type.type_name NULLS LAST,
    GROUPING(trx_channel.channel_name),
    trx_channel.channel_name NULLS LAST;
