-- ============================================================================
-- Report 15: Customer 360 Portfolio Dashboard
-- Project  : Oracle Banking Database
-- Database : Oracle AI Database 26ai Enterprise Edition
-- Version  : 23.26.1.0.0
-- Schema   : BANKING_DB
--
-- Business Purpose
--   Provides a comprehensive customer-level dashboard combining portfolio,
--   transaction, card, beneficiary, contact, address, activity, and ranking
--   metrics.
--
-- Reporting Grain
--   One row per customer.
--
-- Main SQL Features
--   * Common Table Expressions (CTE)
--   * ROW_NUMBER
--   * Currency Conversion
--   * Conditional Aggregation
--   * DENSE_RANK
--   * NULLIF
--   * LEFT JOIN
--   * CASE
--
-- Important Assumptions
--   * TRY is used as the reporting base currency.
--   * The latest available BUY_RATE is used to convert foreign-currency
--     balances and successful outgoing transaction amounts into TRY.
--   * A conversion rate of 1 is used for TRY-denominated accounts.
--   * Transaction activity is attributed through SOURCE_ACCOUNT_ID.
--   * Only transactions whose status is SUCCESS are included in transaction
--     KPIs, transaction rankings, and activity classification.
--   * Customers with missing exchange rates are not assigned financial ranks
--     or portfolio segments because their valuation is incomplete.
--   * A customer is considered dormant when the latest successful outgoing
--     transaction is older than the configured dormancy period.
-- ============================================================================

WITH report_parameters AS
(
    SELECT
        'TRY' AS base_currency_code,
        100   AS premium_rank_limit,
        500   AS high_value_rank_limit,
        2000  AS standard_rank_limit,
        6     AS dormancy_months,
        500   AS highly_active_rank_limit
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

customer_account_summary AS
(
    SELECT
        acc.customer_id,

        COUNT(*) AS total_accounts,

        SUM(
            CASE
                WHEN acc.status = 'ACTIVE' THEN 1
                ELSE 0
            END
        ) AS active_accounts,

        COUNT(DISTINCT acc.branch_id) AS distinct_branch_count,

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

        ROUND(
            MAX(
                CASE
                    WHEN acc.currency_id = base_curr.currency_id
                        THEN acc.balance

                    WHEN rate.buy_rate IS NOT NULL
                        THEN acc.balance * rate.buy_rate
                END
            ),
            2
        ) AS highest_account_balance_try,

        MIN(acc.opening_date) AS first_account_opening_date,
        MAX(acc.opening_date) AS latest_account_opening_date,

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

    GROUP BY
        acc.customer_id
),

customer_transaction_summary AS
(
    SELECT
        acc.customer_id,

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

        ROUND(
            MAX(
                CASE
                    WHEN acc.currency_id = base_curr.currency_id
                        THEN trx.amount

                    WHEN rate.buy_rate IS NOT NULL
                        THEN trx.amount * rate.buy_rate
                END
            ),
            2
        ) AS highest_transaction_amount_try,

        COUNT(DISTINCT trx.channel_id) AS distinct_channel_count,

        COUNT(
            DISTINCT TRUNC(trx.transaction_date)
        ) AS active_transaction_days,

        MIN(trx.transaction_date) AS first_transaction_date,
        MAX(trx.transaction_date) AS last_transaction_date,

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
        acc.customer_id
),

customer_card_summary AS
(
    SELECT
        acc.customer_id,

        COUNT(card.card_id) AS total_cards,

        SUM(
            CASE
                WHEN card.status = 'ACTIVE' THEN 1
                ELSE 0
            END
        ) AS active_cards

    FROM accounts acc

    JOIN cards card
      ON card.account_id = acc.account_id

    GROUP BY
        acc.customer_id
),

customer_beneficiary_summary AS
(
    SELECT
        bene.customer_id,
        COUNT(bene.beneficiary_id) AS total_beneficiaries

    FROM beneficiaries bene

    GROUP BY
        bene.customer_id
),

customer_contact_summary AS
(
    SELECT
        contact.customer_id,

        COUNT(*) AS total_contact_records,

        COUNT(
            DISTINCT contact.contact_type_id
        ) AS distinct_contact_type_count

    FROM customer_contacts contact

    GROUP BY
        contact.customer_id
),

customer_address_summary AS
(
    SELECT
        address.customer_id,
        COUNT(*) AS total_addresses

    FROM customer_addresses address

    GROUP BY
        address.customer_id
),

customer_360_analysis AS
(
    SELECT
        cust.customer_id,
        cust.customer_type,
        cust.status AS customer_status,

        base_curr.currency_code AS base_currency_code,

        NVL(acc_sum.total_accounts, 0) AS total_accounts,
        NVL(acc_sum.active_accounts, 0) AS active_accounts,
        NVL(acc_sum.distinct_branch_count, 0) AS distinct_branch_count,

        NVL(
            acc_sum.total_account_balance_try,
            0
        ) AS total_account_balance_try,

        NVL(
            acc_sum.average_account_balance_try,
            0
        ) AS average_account_balance_try,

        NVL(
            acc_sum.highest_account_balance_try,
            0
        ) AS highest_account_balance_try,

        acc_sum.first_account_opening_date,
        acc_sum.latest_account_opening_date,

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
            trx_sum.highest_transaction_amount_try,
            0
        ) AS highest_transaction_amount_try,

        NVL(
            trx_sum.distinct_channel_count,
            0
        ) AS distinct_channel_count,

        NVL(
            trx_sum.active_transaction_days,
            0
        ) AS active_transaction_days,

        trx_sum.first_transaction_date,
        trx_sum.last_transaction_date,

        NVL(card_sum.total_cards, 0) AS total_cards,
        NVL(card_sum.active_cards, 0) AS active_cards,

        NVL(
            bene_sum.total_beneficiaries,
            0
        ) AS total_beneficiaries,

        NVL(
            contact_sum.total_contact_records,
            0
        ) AS total_contact_records,

        NVL(
            contact_sum.distinct_contact_type_count,
            0
        ) AS distinct_contact_type_count,

        NVL(
            address_sum.total_addresses,
            0
        ) AS total_addresses,

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
                / NULLIF(acc_sum.total_accounts, 0),
                2
            ),
            0
        ) AS transaction_volume_per_account_try,

        NVL(
            acc_sum.accounts_missing_exchange_rate,
            0
        ) AS accounts_missing_exchange_rate,

        NVL(
            trx_sum.transactions_missing_exchange_rate,
            0
        ) AS transactions_missing_exchange_rate

    FROM customers cust

    CROSS JOIN base_currency base_curr

    LEFT JOIN customer_account_summary acc_sum
           ON acc_sum.customer_id = cust.customer_id

    LEFT JOIN customer_transaction_summary trx_sum
           ON trx_sum.customer_id = cust.customer_id

    LEFT JOIN customer_card_summary card_sum
           ON card_sum.customer_id = cust.customer_id

    LEFT JOIN customer_beneficiary_summary bene_sum
           ON bene_sum.customer_id = cust.customer_id

    LEFT JOIN customer_contact_summary contact_sum
           ON contact_sum.customer_id = cust.customer_id

    LEFT JOIN customer_address_summary address_sum
           ON address_sum.customer_id = cust.customer_id
),

eligible_customer_ranking AS
(
    SELECT
        customer_360.customer_id,

        DENSE_RANK() OVER
        (
            ORDER BY
                customer_360.total_account_balance_try DESC
        ) AS balance_rank,

        DENSE_RANK() OVER
        (
            ORDER BY
                customer_360.total_transaction_volume_try DESC
        ) AS transaction_volume_rank,

        DENSE_RANK() OVER
        (
            ORDER BY
                customer_360.successful_transactions DESC
        ) AS transaction_activity_rank

    FROM customer_360_analysis customer_360

    WHERE customer_360.accounts_missing_exchange_rate = 0
      AND customer_360.transactions_missing_exchange_rate = 0
),

customer_360_ranking AS
(
    SELECT
        customer_360.*,

        ranking.balance_rank,
        ranking.transaction_volume_rank,
        ranking.transaction_activity_rank

    FROM customer_360_analysis customer_360

    LEFT JOIN eligible_customer_ranking ranking
           ON ranking.customer_id = customer_360.customer_id
)

SELECT
    customer_360.customer_id,
    customer_360.customer_type,
    customer_360.customer_status,

    CASE
        WHEN customer_360.accounts_missing_exchange_rate > 0
          OR customer_360.transactions_missing_exchange_rate > 0
            THEN 'Incomplete Valuation'

        WHEN customer_360.balance_rank <= params.premium_rank_limit
            THEN 'Premium Portfolio'

        WHEN customer_360.balance_rank <= params.high_value_rank_limit
            THEN 'High Value Portfolio'

        WHEN customer_360.balance_rank <= params.standard_rank_limit
            THEN 'Standard Portfolio'

        ELSE 'Mass Portfolio'
    END AS portfolio_segment,

    CASE
        WHEN customer_360.successful_transactions = 0
            THEN 'No Transaction Activity'

        WHEN customer_360.last_transaction_date <
             ADD_MONTHS(
                 TRUNC(SYSDATE),
                 -params.dormancy_months
             )
            THEN 'Dormant'

        WHEN customer_360.transaction_activity_rank <=
             params.highly_active_rank_limit
            THEN 'Highly Active'

        ELSE 'Active'
    END AS activity_segment,

    customer_360.balance_rank,
    customer_360.transaction_volume_rank,
    customer_360.transaction_activity_rank,

    customer_360.base_currency_code,

    customer_360.total_accounts,
    customer_360.active_accounts,
    customer_360.distinct_branch_count,

    customer_360.total_account_balance_try,
    customer_360.average_account_balance_try,
    customer_360.highest_account_balance_try,

    customer_360.first_account_opening_date,
    customer_360.latest_account_opening_date,

    customer_360.successful_transactions,
    customer_360.total_transaction_volume_try,
    customer_360.average_transaction_amount_try,
    customer_360.highest_transaction_amount_try,

    customer_360.distinct_channel_count,
    customer_360.active_transaction_days,
    customer_360.first_transaction_date,
    customer_360.last_transaction_date,

    customer_360.total_cards,
    customer_360.active_cards,
    customer_360.total_beneficiaries,

    customer_360.total_contact_records,
    customer_360.distinct_contact_type_count,
    customer_360.total_addresses,

    customer_360.transactions_per_account,
    customer_360.transaction_volume_per_account_try

FROM customer_360_ranking customer_360

CROSS JOIN report_parameters params

ORDER BY
    customer_360.balance_rank NULLS LAST,
    customer_360.transaction_volume_rank NULLS LAST,
    customer_360.customer_id;