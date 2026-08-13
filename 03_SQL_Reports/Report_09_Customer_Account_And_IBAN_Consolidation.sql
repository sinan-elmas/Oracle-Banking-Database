-- ============================================================================
-- Report 09: Customer Account and IBAN Consolidation
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Consolidates each customer's account numbers, IBANs, and account
--   currencies into a single customer-level record.
--
-- Reporting Grain
--   One row per customer.
--
-- Main SQL Features
--   * Aggregate Functions
--   * Conditional Aggregation
--   * LISTAGG
--   * LEFT JOIN
--
-- Important Assumptions
--   * Customers without accounts remain in the report.
--   * Account numbers, IBANs, and currency codes are ordered by account number
--     so that values in the three lists remain positionally aligned.
--   * Account balances are not aggregated because balances denominated in
--     different currencies cannot be added directly.
-- ============================================================================

SELECT
    cust.customer_id,
    cust.customer_type,
    cust.status AS customer_status,

    COUNT(acc.account_id) AS total_accounts,

    SUM(
        CASE
            WHEN acc.status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_accounts,

    LISTAGG(
        acc.account_number,
        ', '
    ) WITHIN GROUP
    (
        ORDER BY acc.account_number
    ) AS account_numbers,

    LISTAGG(
        acc.iban,
        ', '
    ) WITHIN GROUP
    (
        ORDER BY acc.account_number
    ) AS iban_list,

    LISTAGG(
        curr.currency_code,
        ', '
    ) WITHIN GROUP
    (
        ORDER BY acc.account_number
    ) AS currency_list

FROM customers cust

LEFT JOIN accounts acc
       ON acc.customer_id = cust.customer_id

LEFT JOIN currencies curr
       ON curr.currency_id = acc.currency_id

GROUP BY
    cust.customer_id,
    cust.customer_type,
    cust.status

ORDER BY
    total_accounts DESC,
    cust.customer_id;