-- ============================================================================
-- Report 02: Account Type Portfolio Analysis by Currency
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Analyzes the size, customer reach, balance distribution, and portfolio
--   importance of each account type within each currency.
--
-- Reporting Grain
--   One row per account type and currency.
--
-- Main SQL Features
--   * Common Table Expressions (CTE)
--   * Conditional Aggregation
--   * Aggregate Functions
--   * Analytic Functions
--   * RANK
--   * NULLIF
--
-- Important Assumptions
--   * Balances in different currencies are not added together.
--   * Portfolio share and ranking are calculated separately within each
--     currency.
--   * ACTIVE account metrics include only accounts whose status is ACTIVE.
--   * Account type and currency combinations without any account are not
--     included in the result.
--   * Displayed portfolio-share percentages may total slightly above or below
--     100% because each account-type share is rounded to two decimal places.
-- ============================================================================

WITH account_type_summary AS
(
    SELECT
        at.account_type_id,
        at.type_name,

        curr.currency_id,
        curr.currency_code,

        COUNT(a.account_id) AS total_accounts,

        SUM(
            CASE
                WHEN a.status = 'ACTIVE' THEN 1
                ELSE 0
            END
        ) AS active_accounts,

        COUNT(DISTINCT a.customer_id) AS total_customers,

        COUNT(
            DISTINCT CASE
                WHEN a.status = 'ACTIVE' THEN a.customer_id
            END
        ) AS active_customers,

        SUM(a.balance) AS total_balance,

        SUM(
            CASE
                WHEN a.status = 'ACTIVE' THEN a.balance
                ELSE 0
            END
        ) AS active_account_balance,

        ROUND(
            AVG(a.balance),
            2
        ) AS average_balance,

        MIN(a.balance) AS minimum_balance,
        MAX(a.balance) AS maximum_balance

    FROM accounts a

    JOIN account_types at
      ON at.account_type_id = a.account_type_id

    JOIN currencies curr
      ON curr.currency_id = a.currency_id

    GROUP BY
        at.account_type_id,
        at.type_name,
        curr.currency_id,
        curr.currency_code
),

portfolio_summary AS
(
    SELECT
        ats.*,

        SUM(ats.total_balance) OVER (
            PARTITION BY ats.currency_id
        ) AS currency_total_balance

    FROM account_type_summary ats
)

SELECT
    account_type_id,
    type_name,

    currency_id,
    currency_code,

    total_customers,
    active_customers,

    total_accounts,
    active_accounts,

    total_balance,
    active_account_balance,

    ROUND(
        total_balance * 100
        / NULLIF(currency_total_balance, 0),
        2
    ) AS balance_share_percent,

    average_balance,
    minimum_balance,
    maximum_balance,

    RANK() OVER (
        PARTITION BY currency_id
        ORDER BY total_balance DESC
    ) AS portfolio_rank,

    CASE
        WHEN total_balance * 100
             / NULLIF(currency_total_balance, 0) >= 35
            THEN 'Strategic'

        WHEN total_balance * 100
             / NULLIF(currency_total_balance, 0) >= 15
            THEN 'High'

        WHEN total_balance * 100
             / NULLIF(currency_total_balance, 0) >= 5
            THEN 'Medium'

        ELSE 'Low'
    END AS portfolio_category

FROM portfolio_summary

ORDER BY
    currency_code,
    total_balance DESC,
    account_type_id;