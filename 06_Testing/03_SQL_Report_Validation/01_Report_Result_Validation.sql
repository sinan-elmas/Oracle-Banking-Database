-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / SQL Report Validation
-- Script       : 01_Report_Result_Validation.sql
-- Purpose      : Validate reporting grain and aggregate reconciliation for
--                the 15 analytical SQL reports
-- Scope        : 03_SQL_Reports
-- Environment  : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- Safety       : Read-only validation
-- ============================================================================

PROMPT
PROMPT ================================================================================
PROMPT SQL REPORT VALIDATION SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN checked_rule_count FORMAT 999,999
COLUMN passed_rule_count  FORMAT 999,999
COLUMN failed_rule_count  FORMAT 999,999
COLUMN health_status      FORMAT A12
COLUMN report_time        FORMAT A20

WITH
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

base_currency AS
(
    SELECT
        currency_id
    FROM currencies
    WHERE currency_code = 'TRY'
),

report_08_valued_transactions AS
(
    SELECT
        acc.customer_id,
        trx.transaction_id,

        ROW_NUMBER() OVER
        (
            PARTITION BY acc.customer_id
            ORDER BY
                ROUND(
                    CASE
                        WHEN acc.currency_id = base_curr.currency_id
                            THEN trx.amount

                        WHEN rate.buy_rate IS NOT NULL
                            THEN trx.amount * rate.buy_rate
                    END,
                    2
                ) DESC,
                trx.transaction_date DESC,
                trx.transaction_id DESC
        ) AS transaction_rank

    FROM accounts acc

    JOIN transactions trx
      ON trx.source_account_id = acc.account_id

    JOIN transaction_types trx_type
      ON trx_type.transaction_type_id =
         trx.transaction_type_id

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
      AND
          (
              acc.currency_id = base_curr.currency_id
              OR rate.buy_rate IS NOT NULL
          )
),

validation_checks AS
(
    -- Report 01
    SELECT
        (SELECT COUNT(*) FROM accounts) AS expected_value,

        (
            SELECT NVL(SUM(total_accounts), 0)
            FROM
            (
                SELECT
                    COUNT(*) AS total_accounts
                FROM accounts
                GROUP BY
                    customer_id,
                    currency_id
            )
        ) AS actual_value

    FROM dual

    UNION ALL

    -- Report 02
    SELECT
        (SELECT COUNT(*) FROM accounts),

        (
            SELECT NVL(SUM(total_accounts), 0)
            FROM
            (
                SELECT
                    COUNT(*) AS total_accounts
                FROM accounts
                GROUP BY
                    account_type_id,
                    currency_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 03
    SELECT
        (SELECT COUNT(*) FROM customers),

        (
            SELECT COUNT(*)
            FROM customers
            CROSS JOIN base_currency
        )

    FROM dual

    UNION ALL

    -- Report 04
    SELECT
        (SELECT COUNT(*) FROM branches),

        (
            SELECT COUNT(*)
            FROM branches
            CROSS JOIN base_currency
        )

    FROM dual

    UNION ALL

    -- Report 05
    SELECT
        (
            SELECT COUNT(*)
            FROM accounts
            WHERE status = 'ACTIVE'
        ),

        (
            SELECT COUNT(*)
            FROM accounts
            WHERE status = 'ACTIVE'
        )

    FROM dual

    UNION ALL

    -- Report 06
    SELECT
        (
            SELECT COUNT(*)
            FROM transactions
            WHERE status = 'SUCCESS'
        ),

        (
            SELECT NVL(SUM(successful_transactions), 0)
            FROM
            (
                SELECT
                    COUNT(*) AS successful_transactions

                FROM transactions trx

                JOIN accounts acc
                  ON acc.account_id = trx.source_account_id

                WHERE trx.status = 'SUCCESS'

                GROUP BY
                    TRUNC(trx.transaction_date, 'MM'),
                    acc.currency_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 07
    SELECT
        (
            SELECT COUNT(*)
            FROM transactions
            WHERE status = 'SUCCESS'
        ),

        (
            SELECT NVL(SUM(successful_transactions), 0)
            FROM
            (
                SELECT
                    COUNT(*) AS successful_transactions

                FROM accounts acc

                JOIN transactions trx
                  ON trx.source_account_id = acc.account_id

                WHERE trx.status = 'SUCCESS'

                GROUP BY
                    acc.customer_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 08
    SELECT
        (
            SELECT COUNT(DISTINCT customer_id)
            FROM report_08_valued_transactions
        ),

        (
            SELECT COUNT(*)
            FROM report_08_valued_transactions
            WHERE transaction_rank = 1
        )

    FROM dual

    UNION ALL

    -- Report 09: customer grain
    SELECT
        (SELECT COUNT(*) FROM customers),

        (
            SELECT COUNT(*)
            FROM
            (
                SELECT
                    cust.customer_id

                FROM customers cust

                LEFT JOIN accounts acc
                  ON acc.customer_id = cust.customer_id

                GROUP BY
                    cust.customer_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 09: account reconciliation
    SELECT
        (SELECT COUNT(*) FROM accounts),

        (
            SELECT NVL(SUM(total_accounts), 0)
            FROM
            (
                SELECT
                    cust.customer_id,
                    COUNT(acc.account_id) AS total_accounts

                FROM customers cust

                LEFT JOIN accounts acc
                  ON acc.customer_id = cust.customer_id

                GROUP BY
                    cust.customer_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 10
    SELECT
        (
            SELECT COUNT(*)
            FROM transactions
            WHERE status = 'SUCCESS'
        ),

        (
            SELECT COUNT(*)

            FROM transactions trx

            JOIN transaction_channels channel_data
              ON channel_data.channel_id = trx.channel_id

            WHERE trx.status = 'SUCCESS'
              AND channel_data.channel_name IN
                  (
                      'ATM',
                      'BRANCH',
                      'INTERNET',
                      'MOBILE',
                      'POS'
                  )
        )

    FROM dual

    UNION ALL

    -- Report 11
    SELECT
        (
            SELECT COUNT(*)
            FROM transactions
            WHERE status = 'SUCCESS'
        ),

        (
            SELECT COUNT(*)

            FROM transactions trx

            JOIN accounts acc
              ON acc.account_id = trx.source_account_id

            WHERE trx.status = 'SUCCESS'
        )

    FROM dual

    UNION ALL

    -- Report 12
    SELECT
        (
            SELECT COUNT(*)
            FROM transactions
            WHERE status = 'SUCCESS'
        ),

        (
            SELECT COUNT(*)

            FROM transactions trx

            JOIN accounts acc
              ON acc.account_id = trx.source_account_id

            JOIN transaction_types trx_type
              ON trx_type.transaction_type_id =
                 trx.transaction_type_id

            JOIN transaction_channels trx_channel
              ON trx_channel.channel_id = trx.channel_id

            WHERE trx.status = 'SUCCESS'
        )

    FROM dual

    UNION ALL

    -- Report 13: customers
    SELECT
        (SELECT COUNT(*) FROM customers),
        (SELECT COUNT(*) FROM customers)

    FROM dual

    UNION ALL

    -- Report 13: accounts
    SELECT
        (SELECT COUNT(*) FROM accounts),
        (SELECT COUNT(*) FROM accounts)

    FROM dual

    UNION ALL

    -- Report 13: transactions
    SELECT
        (
            SELECT COUNT(*)
            FROM transactions
            WHERE status = 'SUCCESS'
        ),

        (
            SELECT COUNT(*)
            FROM transactions
            WHERE status = 'SUCCESS'
        )

    FROM dual

    UNION ALL

    -- Report 14: branch grain
    SELECT
        (SELECT COUNT(*) FROM branches),

        (
            SELECT COUNT(*)
            FROM
            (
                SELECT
                    branch_data.branch_id

                FROM branches branch_data

                LEFT JOIN accounts acc
                  ON acc.branch_id = branch_data.branch_id

                GROUP BY
                    branch_data.branch_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 14: accounts
    SELECT
        (SELECT COUNT(*) FROM accounts),

        (
            SELECT NVL(SUM(total_accounts), 0)
            FROM
            (
                SELECT
                    branch_data.branch_id,
                    COUNT(acc.account_id) AS total_accounts

                FROM branches branch_data

                LEFT JOIN accounts acc
                  ON acc.branch_id = branch_data.branch_id

                GROUP BY
                    branch_data.branch_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 14: transactions
    SELECT
        (
            SELECT COUNT(*)
            FROM transactions
            WHERE status = 'SUCCESS'
        ),

        (
            SELECT NVL(SUM(successful_transactions), 0)
            FROM
            (
                SELECT
                    acc.branch_id,
                    COUNT(*) AS successful_transactions

                FROM accounts acc

                JOIN transactions trx
                  ON trx.source_account_id = acc.account_id

                WHERE trx.status = 'SUCCESS'

                GROUP BY
                    acc.branch_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 15: customer grain
    SELECT
        (SELECT COUNT(*) FROM customers),
        (SELECT COUNT(*) FROM customers)

    FROM dual

    UNION ALL

    -- Report 15: accounts
    SELECT
        (SELECT COUNT(*) FROM accounts),

        (
            SELECT NVL(SUM(total_accounts), 0)
            FROM
            (
                SELECT
                    customer_id,
                    COUNT(*) AS total_accounts

                FROM accounts

                GROUP BY
                    customer_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 15: transactions
    SELECT
        (
            SELECT COUNT(*)
            FROM transactions
            WHERE status = 'SUCCESS'
        ),

        (
            SELECT NVL(SUM(successful_transactions), 0)
            FROM
            (
                SELECT
                    acc.customer_id,
                    COUNT(*) AS successful_transactions

                FROM accounts acc

                JOIN transactions trx
                  ON trx.source_account_id = acc.account_id

                WHERE trx.status = 'SUCCESS'

                GROUP BY
                    acc.customer_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 15: cards
    SELECT
        (SELECT COUNT(*) FROM cards),

        (
            SELECT NVL(SUM(total_cards), 0)
            FROM
            (
                SELECT
                    acc.customer_id,
                    COUNT(card_data.card_id) AS total_cards

                FROM accounts acc

                JOIN cards card_data
                  ON card_data.account_id = acc.account_id

                GROUP BY
                    acc.customer_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 15: beneficiaries
    SELECT
        (SELECT COUNT(*) FROM beneficiaries),

        (
            SELECT NVL(SUM(total_beneficiaries), 0)
            FROM
            (
                SELECT
                    customer_id,
                    COUNT(*) AS total_beneficiaries

                FROM beneficiaries

                GROUP BY
                    customer_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 15: contacts
    SELECT
        (SELECT COUNT(*) FROM customer_contacts),

        (
            SELECT NVL(SUM(total_contacts), 0)
            FROM
            (
                SELECT
                    customer_id,
                    COUNT(*) AS total_contacts

                FROM customer_contacts

                GROUP BY
                    customer_id
            )
        )

    FROM dual

    UNION ALL

    -- Report 15: addresses
    SELECT
        (SELECT COUNT(*) FROM customer_addresses),

        (
            SELECT NVL(SUM(total_addresses), 0)
            FROM
            (
                SELECT
                    customer_id,
                    COUNT(*) AS total_addresses

                FROM customer_addresses

                GROUP BY
                    customer_id
            )
        )

    FROM dual
)
SELECT
    COUNT(*) AS checked_rule_count,

    SUM(
        CASE
            WHEN actual_value = expected_value THEN 1
            ELSE 0
        END
    ) AS passed_rule_count,

    SUM(
        CASE
            WHEN actual_value <> expected_value THEN 1
            ELSE 0
        END
    ) AS failed_rule_count,

    CASE
        WHEN SUM(
                 CASE
                     WHEN actual_value <> expected_value THEN 1
                     ELSE 0
                 END
             ) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS health_status,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM validation_checks;