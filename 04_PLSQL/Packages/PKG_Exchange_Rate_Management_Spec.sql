-- ============================================================================
-- Package Specification: PKG_EXCHANGE_RATE_MANAGEMENT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Defines the public interface for exchange-rate maintenance and currency
--   conversion services.
--
-- Responsibilities
--   * Maintain exchange-rate records
--   * Retrieve latest and historical exchange rates
--   * Convert amounts between supported currencies
--   * Validate exchange-rate business rules
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Transaction control remains with the calling application or script.
--
-- Dependencies
--   * EXCHANGE_RATES
--   * CURRENCIES
--   * PKG_AUDIT
--   * PKG_ERROR_LOG
-- ============================================================================

create or replace PACKAGE pkg_exchange_rate_management AS

    PROCEDURE add_exchange_rate (
        p_currency_id      IN  exchange_rates.currency_id%TYPE,
        p_base_currency_id IN  exchange_rates.base_currency_id%TYPE,
        p_buy_rate         IN  exchange_rates.buy_rate%TYPE,
        p_sell_rate        IN  exchange_rates.sell_rate%TYPE,
        p_rate_date        IN  exchange_rates.rate_date%TYPE DEFAULT TRUNC(SYSDATE),
        p_created_by       IN  exchange_rates.created_by%TYPE DEFAULT USER,
        p_rate_id          OUT exchange_rates.rate_id%TYPE
    );

    PROCEDURE update_exchange_rate (
        p_rate_id    IN exchange_rates.rate_id%TYPE,
        p_buy_rate   IN exchange_rates.buy_rate%TYPE,
        p_sell_rate  IN exchange_rates.sell_rate%TYPE,
        p_updated_by IN exchange_rates.updated_by%TYPE DEFAULT USER
    );

    PROCEDURE get_latest_rate (
        p_currency_id      IN  exchange_rates.currency_id%TYPE,
        p_base_currency_id IN  exchange_rates.base_currency_id%TYPE,
        p_result           OUT SYS_REFCURSOR
    );

    PROCEDURE get_rate_by_date (
        p_currency_id      IN  exchange_rates.currency_id%TYPE,
        p_base_currency_id IN  exchange_rates.base_currency_id%TYPE,
        p_rate_date        IN  exchange_rates.rate_date%TYPE,
        p_result           OUT SYS_REFCURSOR
    );

    FUNCTION convert_amount (
        p_amount           IN transactions.amount%TYPE,
        p_currency_id      IN exchange_rates.currency_id%TYPE,
        p_base_currency_id IN exchange_rates.base_currency_id%TYPE,
        p_rate_type        IN VARCHAR2 DEFAULT 'SELL',
        p_rate_date        IN exchange_rates.rate_date%TYPE DEFAULT NULL
    )
    RETURN NUMBER;

END pkg_exchange_rate_management;
