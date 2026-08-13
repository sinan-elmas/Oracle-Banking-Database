-- ============================================================================
-- Report 11: Branch Transaction Performance with ROLLUP
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Analyzes successful outgoing transaction activity by branch and month,
--   while producing monthly subtotals and currency-level grand totals.
--
-- Reporting Grain
--   Detail rows contain one row per currency, month, and branch.
--   Additional ROLLUP rows provide:
--     * Monthly totals across all branches
--     * Currency totals across all months and branches
--
-- Main SQL Features
--   * Common Table Expressions (CTE)
--   * Aggregate Functions
--   * Oracle ROLLUP
--   * GROUPING
--   * CASE
--   * NVL
--
-- Important Assumptions
--   * Transaction activity is attributed to the branch of SOURCE_ACCOUNT_ID.
--   * Only transactions whose status is SUCCESS are included.
--   * Transaction amounts are reported in the source account currency.
--   * Amounts in different currencies are never added together.
--   * Transaction amount is a period-based flow measure rather than a
--     point-in-time account balance.
-- ============================================================================

WITH transaction_base AS
(
    SELECT
        TRUNC(trx.transaction_date, 'MM') AS transaction_month,

        branch.branch_id,
        branch.branch_name,

        curr.currency_code,

        trx.transaction_id,
        trx.amount

    FROM transactions trx

    JOIN accounts acc
      ON acc.account_id = trx.source_account_id

    JOIN branches branch
      ON branch.branch_id = acc.branch_id

    JOIN currencies curr
      ON curr.currency_id = acc.currency_id

    WHERE trx.status = 'SUCCESS'
),

rollup_summary AS
(
    SELECT
        currency_code,
        transaction_month,
        branch_id,
        branch_name,

        GROUPING(transaction_month) AS month_grouping_flag,
        GROUPING(branch_id) AS branch_grouping_flag,

        COUNT(transaction_id) AS successful_transactions,

        NVL(
            SUM(amount),
            0
        ) AS total_transaction_amount,

        NVL(
            ROUND(
                AVG(amount),
                2
            ),
            0
        ) AS average_transaction_amount

    FROM transaction_base

    GROUP BY
        currency_code,

        ROLLUP
        (
            transaction_month,
            (
                branch_id,
                branch_name
            )
        )
)

SELECT
    currency_code,

    CASE
        WHEN month_grouping_flag = 1
            THEN 'ALL PERIODS'

        ELSE TO_CHAR(
                 transaction_month,
                 'YYYY-MM'
             )
    END AS transaction_month,

    CASE
        WHEN branch_grouping_flag = 1
            THEN 'ALL BRANCHES'

        ELSE branch_name
    END AS branch_name,

    successful_transactions,
    total_transaction_amount,
    average_transaction_amount

FROM rollup_summary

ORDER BY
    currency_code,
    month_grouping_flag,
    transaction_month,
    branch_grouping_flag,
    branch_name;