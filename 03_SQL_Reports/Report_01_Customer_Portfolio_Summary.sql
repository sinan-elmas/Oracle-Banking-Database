-- ============================================================================
-- Report 01: Customer Portfolio Summary by Currency
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Provides a consolidated overview of each customer's banking portfolio,
--   including accounts, balances, cards, and registered beneficiaries.
--
-- Reporting Grain
--   One row per customer and account currency.
--
-- Main SQL Features
--   * Common Table Expressions (CTE)
--   * Conditional Aggregation
--   * Aggregate Functions
--   * LEFT JOIN
--   * NVL
--
-- Important Assumptions
--   * Balances in different currencies are never added together.
--   * Account and card status comparisons use the value ACTIVE.
--   * Beneficiary counts are grouped by the currency of the beneficiary
--     account.
--   * Customers without accounts remain in the output with zero-valued
--     portfolio metrics and NULL currency information.
--   * Balance-based sorting is performed within each currency because raw
--     balances in different currencies are not directly comparable.
-- ============================================================================

WITH account_summary AS
(
    SELECT
        a.customer_id,
        a.currency_id,

        COUNT(*) AS total_accounts,

        SUM(
            CASE
                WHEN a.status = 'ACTIVE' THEN 1
                ELSE 0
            END
        ) AS active_accounts,

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
        ) AS average_balance

    FROM accounts a

    GROUP BY
        a.customer_id,
        a.currency_id
),

card_summary AS
(
    SELECT
        a.customer_id,
        a.currency_id,

        COUNT(c.card_id) AS total_cards,

        SUM(
            CASE
                WHEN c.status = 'ACTIVE' THEN 1
                ELSE 0
            END
        ) AS active_cards

    FROM accounts a

    JOIN cards c
      ON c.account_id = a.account_id

    GROUP BY
        a.customer_id,
        a.currency_id
),

beneficiary_summary AS
(
    SELECT
        b.customer_id,
        beneficiary_account.currency_id,

        COUNT(*) AS total_beneficiaries

    FROM beneficiaries b

    JOIN accounts beneficiary_account
      ON beneficiary_account.account_id = b.beneficiary_account_id

    GROUP BY
        b.customer_id,
        beneficiary_account.currency_id
)

SELECT
    c.customer_id,
    c.customer_type,
    c.status AS customer_status,

    curr.currency_id,
    curr.currency_code,

    NVL(acc_sum.total_accounts, 0)          AS total_accounts,
    NVL(acc_sum.active_accounts, 0)         AS active_accounts,

    NVL(acc_sum.total_balance, 0)           AS total_balance,
    NVL(acc_sum.active_account_balance, 0)  AS active_account_balance,
    NVL(acc_sum.average_balance, 0)         AS average_balance,

    NVL(card_sum.total_cards, 0)            AS total_cards,
    NVL(card_sum.active_cards, 0)           AS active_cards,

    NVL(ben_sum.total_beneficiaries, 0)     AS total_beneficiaries

FROM customers c

LEFT JOIN account_summary acc_sum
       ON acc_sum.customer_id = c.customer_id

LEFT JOIN currencies curr
       ON curr.currency_id = acc_sum.currency_id

LEFT JOIN card_summary card_sum
       ON card_sum.customer_id = c.customer_id
      AND card_sum.currency_id = acc_sum.currency_id

LEFT JOIN beneficiary_summary ben_sum
       ON ben_sum.customer_id = c.customer_id
      AND ben_sum.currency_id = acc_sum.currency_id

ORDER BY
    curr.currency_code NULLS LAST,
    NVL(acc_sum.total_balance, 0) DESC,
    c.customer_id;