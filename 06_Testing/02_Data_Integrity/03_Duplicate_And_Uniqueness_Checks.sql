-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Data Integrity
-- Script       : 03_Duplicate_And_Uniqueness_Checks.sql
-- Purpose      : Detect duplicate values across schema-defined unique
--                business keys
-- Scope        : UNIQUE constraints in the current application schema
-- Safety       : Read-only
-- Environment  : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- ============================================================================

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 500
SET LINESIZE 240
SET FEEDBACK ON
SET VERIFY OFF
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

PROMPT
PROMPT ================================================================================
PROMPT DUPLICATE AND UNIQUENESS HEALTH SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN schema_name          FORMAT A20
COLUMN checked_rule_count   FORMAT 999,999
COLUMN passed_rule_count    FORMAT 999,999
COLUMN failed_rule_count    FORMAT 999,999
COLUMN duplicate_group_count FORMAT 999,999
COLUMN excess_row_count     FORMAT 999,999
COLUMN health_status        FORMAT A12
COLUMN report_time          FORMAT A20

WITH uniqueness_checks AS
(
    SELECT
        'ACCOUNTS.IBAN' AS rule_name,
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT iban
                FROM accounts
                WHERE iban IS NOT NULL
                GROUP BY iban
                HAVING COUNT(*) > 1
            )
        ) AS duplicate_group_count,
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM accounts
                WHERE iban IS NOT NULL
                GROUP BY iban
                HAVING COUNT(*) > 1
            )
        ) AS excess_row_count
    FROM dual

    UNION ALL

    SELECT
        'ACCOUNTS.ACCOUNT_NUMBER',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT account_number
                FROM accounts
                WHERE account_number IS NOT NULL
                GROUP BY account_number
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM accounts
                WHERE account_number IS NOT NULL
                GROUP BY account_number
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'ACCOUNT_TYPES.TYPE_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT type_name
                FROM account_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM account_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'BENEFICIARIES.CUSTOMER_ID + BENEFICIARY_ACCOUNT_ID',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT customer_id, beneficiary_account_id
                FROM beneficiaries
                WHERE customer_id IS NOT NULL
                  AND beneficiary_account_id IS NOT NULL
                GROUP BY customer_id, beneficiary_account_id
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM beneficiaries
                WHERE customer_id IS NOT NULL
                  AND beneficiary_account_id IS NOT NULL
                GROUP BY customer_id, beneficiary_account_id
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'BRANCHES.BRANCH_CODE',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT branch_code
                FROM branches
                WHERE branch_code IS NOT NULL
                GROUP BY branch_code
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM branches
                WHERE branch_code IS NOT NULL
                GROUP BY branch_code
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CARDS.CARD_NUMBER',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT card_number
                FROM cards
                WHERE card_number IS NOT NULL
                GROUP BY card_number
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM cards
                WHERE card_number IS NOT NULL
                GROUP BY card_number
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CARD_TYPES.TYPE_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT type_name
                FROM card_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM card_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CITIES.COUNTRY_ID + CITY_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT country_id, city_name
                FROM cities
                WHERE country_id IS NOT NULL
                  AND city_name IS NOT NULL
                GROUP BY country_id, city_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM cities
                WHERE country_id IS NOT NULL
                  AND city_name IS NOT NULL
                GROUP BY country_id, city_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'COMPANIES.COMPANY_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT company_name
                FROM companies
                WHERE company_name IS NOT NULL
                GROUP BY company_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM companies
                WHERE company_name IS NOT NULL
                GROUP BY company_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CONTACT_TYPES.TYPE_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT type_name
                FROM contact_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM contact_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CORPORATE_CUSTOMERS.REGISTRATION_NUMBER',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT registration_number
                FROM corporate_customers
                WHERE registration_number IS NOT NULL
                GROUP BY registration_number
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM corporate_customers
                WHERE registration_number IS NOT NULL
                GROUP BY registration_number
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CORPORATE_CUSTOMERS.TAX_NUMBER',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT tax_number
                FROM corporate_customers
                WHERE tax_number IS NOT NULL
                GROUP BY tax_number
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM corporate_customers
                WHERE tax_number IS NOT NULL
                GROUP BY tax_number
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CORPORATE_CUSTOMERS.COMPANY_ID',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT company_id
                FROM corporate_customers
                WHERE company_id IS NOT NULL
                GROUP BY company_id
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM corporate_customers
                WHERE company_id IS NOT NULL
                GROUP BY company_id
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'COUNTRIES.COUNTRY_CODE',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT country_code
                FROM countries
                WHERE country_code IS NOT NULL
                GROUP BY country_code
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM countries
                WHERE country_code IS NOT NULL
                GROUP BY country_code
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'COUNTRIES.COUNTRY_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT country_name
                FROM countries
                WHERE country_name IS NOT NULL
                GROUP BY country_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM countries
                WHERE country_name IS NOT NULL
                GROUP BY country_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CURRENCIES.CURRENCY_CODE',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT currency_code
                FROM currencies
                WHERE currency_code IS NOT NULL
                GROUP BY currency_code
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM currencies
                WHERE currency_code IS NOT NULL
                GROUP BY currency_code
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CUSTOMERS.CUSTOMER_NO',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT customer_no
                FROM customers
                WHERE customer_no IS NOT NULL
                GROUP BY customer_no
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM customers
                WHERE customer_no IS NOT NULL
                GROUP BY customer_no
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CUSTOMER_ADDRESSES.CUSTOMER_ID + ADDRESS_TYPE',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT customer_id, address_type
                FROM customer_addresses
                WHERE customer_id IS NOT NULL
                  AND address_type IS NOT NULL
                GROUP BY customer_id, address_type
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM customer_addresses
                WHERE customer_id IS NOT NULL
                  AND address_type IS NOT NULL
                GROUP BY customer_id, address_type
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CUSTOMER_CONTACTS.CUSTOMER_ID + CONTACT_VALUE + CONTACT_TYPE_ID',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT customer_id, contact_value, contact_type_id
                FROM customer_contacts
                WHERE customer_id IS NOT NULL
                  AND contact_value IS NOT NULL
                  AND contact_type_id IS NOT NULL
                GROUP BY customer_id, contact_value, contact_type_id
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM customer_contacts
                WHERE customer_id IS NOT NULL
                  AND contact_value IS NOT NULL
                  AND contact_type_id IS NOT NULL
                GROUP BY customer_id, contact_value, contact_type_id
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'DISTRICTS.CITY_ID + DISTRICT_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT city_id, district_name
                FROM districts
                WHERE city_id IS NOT NULL
                  AND district_name IS NOT NULL
                GROUP BY city_id, district_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM districts
                WHERE city_id IS NOT NULL
                  AND district_name IS NOT NULL
                GROUP BY city_id, district_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'EXCHANGE_RATES.CURRENCY_ID + BASE_CURRENCY_ID + RATE_DATE',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT currency_id, base_currency_id, rate_date
                FROM exchange_rates
                WHERE currency_id IS NOT NULL
                  AND base_currency_id IS NOT NULL
                  AND rate_date IS NOT NULL
                GROUP BY currency_id, base_currency_id, rate_date
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM exchange_rates
                WHERE currency_id IS NOT NULL
                  AND base_currency_id IS NOT NULL
                  AND rate_date IS NOT NULL
                GROUP BY currency_id, base_currency_id, rate_date
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'INDIVIDUAL_CUSTOMERS.NATIONAL_ID',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT national_id
                FROM individual_customers
                WHERE national_id IS NOT NULL
                GROUP BY national_id
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM individual_customers
                WHERE national_id IS NOT NULL
                GROUP BY national_id
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'SECTORS.SECTOR_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT sector_name
                FROM sectors
                WHERE sector_name IS NOT NULL
                GROUP BY sector_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM sectors
                WHERE sector_name IS NOT NULL
                GROUP BY sector_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'TRANSACTIONS.REFERENCE_NUMBER',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT reference_number
                FROM transactions
                WHERE reference_number IS NOT NULL
                GROUP BY reference_number
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM transactions
                WHERE reference_number IS NOT NULL
                GROUP BY reference_number
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'TRANSACTION_CHANNELS.CHANNEL_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT channel_name
                FROM transaction_channels
                WHERE channel_name IS NOT NULL
                GROUP BY channel_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM transaction_channels
                WHERE channel_name IS NOT NULL
                GROUP BY channel_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'TRANSACTION_TYPES.TYPE_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT type_name
                FROM transaction_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM transaction_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual
)
SELECT
    USER AS schema_name,
    COUNT(*) AS checked_rule_count,

    SUM(
        CASE
            WHEN duplicate_group_count = 0 THEN 1
            ELSE 0
        END
    ) AS passed_rule_count,

    SUM(
        CASE
            WHEN duplicate_group_count > 0 THEN 1
            ELSE 0
        END
    ) AS failed_rule_count,

    SUM(duplicate_group_count) AS duplicate_group_count,
    SUM(excess_row_count) AS excess_row_count,

    CASE
        WHEN SUM(duplicate_group_count) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS health_status,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM uniqueness_checks;

PROMPT
PROMPT ================================================================================
PROMPT DUPLICATE AND UNIQUENESS CHECK DETAILS
PROMPT ================================================================================
PROMPT

COLUMN rule_name             FORMAT A68
COLUMN duplicate_group_count FORMAT 999,999
COLUMN excess_row_count      FORMAT 999,999
COLUMN validation_status     FORMAT A12

WITH uniqueness_checks AS
(
    SELECT
        'ACCOUNTS.IBAN' AS rule_name,
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT iban
                FROM accounts
                WHERE iban IS NOT NULL
                GROUP BY iban
                HAVING COUNT(*) > 1
            )
        ) AS duplicate_group_count,
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM accounts
                WHERE iban IS NOT NULL
                GROUP BY iban
                HAVING COUNT(*) > 1
            )
        ) AS excess_row_count
    FROM dual

    UNION ALL

    SELECT
        'ACCOUNTS.ACCOUNT_NUMBER',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT account_number
                FROM accounts
                WHERE account_number IS NOT NULL
                GROUP BY account_number
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM accounts
                WHERE account_number IS NOT NULL
                GROUP BY account_number
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'ACCOUNT_TYPES.TYPE_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT type_name
                FROM account_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM account_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'BENEFICIARIES.CUSTOMER_ID + BENEFICIARY_ACCOUNT_ID',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT customer_id, beneficiary_account_id
                FROM beneficiaries
                WHERE customer_id IS NOT NULL
                  AND beneficiary_account_id IS NOT NULL
                GROUP BY customer_id, beneficiary_account_id
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM beneficiaries
                WHERE customer_id IS NOT NULL
                  AND beneficiary_account_id IS NOT NULL
                GROUP BY customer_id, beneficiary_account_id
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'BRANCHES.BRANCH_CODE',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT branch_code
                FROM branches
                WHERE branch_code IS NOT NULL
                GROUP BY branch_code
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM branches
                WHERE branch_code IS NOT NULL
                GROUP BY branch_code
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CARDS.CARD_NUMBER',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT card_number
                FROM cards
                WHERE card_number IS NOT NULL
                GROUP BY card_number
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM cards
                WHERE card_number IS NOT NULL
                GROUP BY card_number
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CARD_TYPES.TYPE_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT type_name
                FROM card_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM card_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CITIES.COUNTRY_ID + CITY_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT country_id, city_name
                FROM cities
                WHERE country_id IS NOT NULL
                  AND city_name IS NOT NULL
                GROUP BY country_id, city_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM cities
                WHERE country_id IS NOT NULL
                  AND city_name IS NOT NULL
                GROUP BY country_id, city_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'COMPANIES.COMPANY_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT company_name
                FROM companies
                WHERE company_name IS NOT NULL
                GROUP BY company_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM companies
                WHERE company_name IS NOT NULL
                GROUP BY company_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CONTACT_TYPES.TYPE_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT type_name
                FROM contact_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM contact_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CORPORATE_CUSTOMERS.REGISTRATION_NUMBER',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT registration_number
                FROM corporate_customers
                WHERE registration_number IS NOT NULL
                GROUP BY registration_number
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM corporate_customers
                WHERE registration_number IS NOT NULL
                GROUP BY registration_number
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CORPORATE_CUSTOMERS.TAX_NUMBER',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT tax_number
                FROM corporate_customers
                WHERE tax_number IS NOT NULL
                GROUP BY tax_number
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM corporate_customers
                WHERE tax_number IS NOT NULL
                GROUP BY tax_number
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CORPORATE_CUSTOMERS.COMPANY_ID',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT company_id
                FROM corporate_customers
                WHERE company_id IS NOT NULL
                GROUP BY company_id
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM corporate_customers
                WHERE company_id IS NOT NULL
                GROUP BY company_id
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'COUNTRIES.COUNTRY_CODE',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT country_code
                FROM countries
                WHERE country_code IS NOT NULL
                GROUP BY country_code
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM countries
                WHERE country_code IS NOT NULL
                GROUP BY country_code
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'COUNTRIES.COUNTRY_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT country_name
                FROM countries
                WHERE country_name IS NOT NULL
                GROUP BY country_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM countries
                WHERE country_name IS NOT NULL
                GROUP BY country_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CURRENCIES.CURRENCY_CODE',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT currency_code
                FROM currencies
                WHERE currency_code IS NOT NULL
                GROUP BY currency_code
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM currencies
                WHERE currency_code IS NOT NULL
                GROUP BY currency_code
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CUSTOMERS.CUSTOMER_NO',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT customer_no
                FROM customers
                WHERE customer_no IS NOT NULL
                GROUP BY customer_no
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM customers
                WHERE customer_no IS NOT NULL
                GROUP BY customer_no
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CUSTOMER_ADDRESSES.CUSTOMER_ID + ADDRESS_TYPE',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT customer_id, address_type
                FROM customer_addresses
                WHERE customer_id IS NOT NULL
                  AND address_type IS NOT NULL
                GROUP BY customer_id, address_type
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM customer_addresses
                WHERE customer_id IS NOT NULL
                  AND address_type IS NOT NULL
                GROUP BY customer_id, address_type
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'CUSTOMER_CONTACTS.CUSTOMER_ID + CONTACT_VALUE + CONTACT_TYPE_ID',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT customer_id, contact_value, contact_type_id
                FROM customer_contacts
                WHERE customer_id IS NOT NULL
                  AND contact_value IS NOT NULL
                  AND contact_type_id IS NOT NULL
                GROUP BY customer_id, contact_value, contact_type_id
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM customer_contacts
                WHERE customer_id IS NOT NULL
                  AND contact_value IS NOT NULL
                  AND contact_type_id IS NOT NULL
                GROUP BY customer_id, contact_value, contact_type_id
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'DISTRICTS.CITY_ID + DISTRICT_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT city_id, district_name
                FROM districts
                WHERE city_id IS NOT NULL
                  AND district_name IS NOT NULL
                GROUP BY city_id, district_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM districts
                WHERE city_id IS NOT NULL
                  AND district_name IS NOT NULL
                GROUP BY city_id, district_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'EXCHANGE_RATES.CURRENCY_ID + BASE_CURRENCY_ID + RATE_DATE',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT currency_id, base_currency_id, rate_date
                FROM exchange_rates
                WHERE currency_id IS NOT NULL
                  AND base_currency_id IS NOT NULL
                  AND rate_date IS NOT NULL
                GROUP BY currency_id, base_currency_id, rate_date
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM exchange_rates
                WHERE currency_id IS NOT NULL
                  AND base_currency_id IS NOT NULL
                  AND rate_date IS NOT NULL
                GROUP BY currency_id, base_currency_id, rate_date
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'INDIVIDUAL_CUSTOMERS.NATIONAL_ID',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT national_id
                FROM individual_customers
                WHERE national_id IS NOT NULL
                GROUP BY national_id
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM individual_customers
                WHERE national_id IS NOT NULL
                GROUP BY national_id
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'SECTORS.SECTOR_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT sector_name
                FROM sectors
                WHERE sector_name IS NOT NULL
                GROUP BY sector_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM sectors
                WHERE sector_name IS NOT NULL
                GROUP BY sector_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'TRANSACTIONS.REFERENCE_NUMBER',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT reference_number
                FROM transactions
                WHERE reference_number IS NOT NULL
                GROUP BY reference_number
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM transactions
                WHERE reference_number IS NOT NULL
                GROUP BY reference_number
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'TRANSACTION_CHANNELS.CHANNEL_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT channel_name
                FROM transaction_channels
                WHERE channel_name IS NOT NULL
                GROUP BY channel_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM transaction_channels
                WHERE channel_name IS NOT NULL
                GROUP BY channel_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual

    UNION ALL

    SELECT
        'TRANSACTION_TYPES.TYPE_NAME',
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT type_name
                FROM transaction_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        ),
        (
            SELECT NVL(SUM(row_count - 1), 0)
            FROM
            (
                SELECT COUNT(*) AS row_count
                FROM transaction_types
                WHERE type_name IS NOT NULL
                GROUP BY type_name
                HAVING COUNT(*) > 1
            )
        )
    FROM dual
)
SELECT
    rule_name,
    duplicate_group_count,
    excess_row_count,

    CASE
        WHEN duplicate_group_count = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status

FROM uniqueness_checks

ORDER BY
    rule_name;

PROMPT
PROMPT ================================================================================
PROMPT DUPLICATE AND UNIQUENESS INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT PASS means no duplicate group was detected for the reviewed unique key.
PROMPT
PROMPT The report evaluates all 26 UNIQUE constraints identified in the schema.
PROMPT
PROMPT PRIMARY KEY duplication is already prevented and validated separately
PROMPT through enabled and validated primary-key constraints.
PROMPT
PROMPT Duplicate checks ignore rows containing NULL in any reviewed unique-key
PROMPT column to remain consistent with Oracle UNIQUE constraint NULL semantics.
PROMPT
PROMPT DUPLICATE_GROUP_COUNT reports the number of repeated key combinations.
PROMPT
PROMPT EXCESS_ROW_COUNT reports rows exceeding one permitted row per unique key.
PROMPT
PROMPT The function-based index UQ_CUSTOMER_PRIMARY_CONTACT is not represented
PROMPT as a USER_CONSTRAINTS unique constraint and will be validated separately
PROMPT with its underlying business rule.
PROMPT
PROMPT No table, row, constraint, index, sequence, or schema object is modified.
PROMPT
PROMPT End of duplicate and uniqueness validation report.