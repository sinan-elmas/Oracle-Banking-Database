-- ============================================================================
-- Package Body         : PKG_EXCHANGE_RATE_MANAGEMENT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Implements exchange-rate maintenance, retrieval, and currency conversion.
--
-- Implementation Notes
--   * Validates currency references and exchange-rate business rules.
--   * Prevents duplicate currency-pair rates for the same business date.
--   * Supports retrieval of the latest rate and date-specific rates.
--   * Converts amounts using BUY or SELL rates.
--   * Records successful business actions through PKG_AUDIT.
--   * Records unexpected errors through PKG_ERROR_LOG.
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Transaction control remains with the calling application or script.
--
-- Dependencies
--   * EXCHANGE_RATES and CURRENCIES
--   * PKG_AUDIT
--   * PKG_ERROR_LOG
-- ============================================================================

create or replace PACKAGE BODY pkg_exchange_rate_management AS

    c_rate_type_buy  CONSTANT VARCHAR2(4) := 'BUY';
    c_rate_type_sell CONSTANT VARCHAR2(4) := 'SELL';

    PROCEDURE validate_currency (
        p_currency_id IN currencies.currency_id%TYPE,
        p_error_code  IN PLS_INTEGER,
        p_error_text  IN VARCHAR2
    )
    IS
        l_count PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO l_count
          FROM currencies
         WHERE currency_id = p_currency_id;

        IF l_count = 0 THEN
            RAISE_APPLICATION_ERROR(p_error_code, p_error_text);
        END IF;
    END validate_currency;


    PROCEDURE log_error_safely (
        p_operation_name IN VARCHAR2,
        p_entity_name    IN VARCHAR2,
        p_entity_id      IN VARCHAR2,
        p_context_data   IN CLOB
    )
    IS
    BEGIN
        pkg_error_log.log_error(
            p_operation_name => p_operation_name,
            p_entity_name    => p_entity_name,
            p_entity_id      => p_entity_id,
            p_context_data   => p_context_data,
            p_severity       => 'ERROR'
        );
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END log_error_safely;


    PROCEDURE add_exchange_rate (
        p_currency_id      IN  exchange_rates.currency_id%TYPE,
        p_base_currency_id IN  exchange_rates.base_currency_id%TYPE,
        p_buy_rate         IN  exchange_rates.buy_rate%TYPE,
        p_sell_rate        IN  exchange_rates.sell_rate%TYPE,
        p_rate_date        IN  exchange_rates.rate_date%TYPE DEFAULT TRUNC(SYSDATE),
        p_created_by       IN  exchange_rates.created_by%TYPE DEFAULT USER,
        p_rate_id          OUT exchange_rates.rate_id%TYPE
    )
    IS
        l_rate_date       exchange_rates.rate_date%TYPE;
        l_created_by      exchange_rates.created_by%TYPE;
        l_duplicate_count PLS_INTEGER;
    BEGIN
        p_rate_id := NULL;

        IF p_currency_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20600, 'Currency ID cannot be null.');
        END IF;

        IF p_base_currency_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20601, 'Base currency ID cannot be null.');
        END IF;

        IF p_currency_id = p_base_currency_id THEN
            RAISE_APPLICATION_ERROR(-20602, 'Currency and base currency must be different.');
        END IF;

        IF p_buy_rate IS NULL OR p_buy_rate <= 0 THEN
            RAISE_APPLICATION_ERROR(-20603, 'Buy rate must be greater than zero.');
        END IF;

        IF p_sell_rate IS NULL OR p_sell_rate <= 0 THEN
            RAISE_APPLICATION_ERROR(-20604, 'Sell rate must be greater than zero.');
        END IF;

        IF p_sell_rate < p_buy_rate THEN
            RAISE_APPLICATION_ERROR(-20605, 'Sell rate cannot be lower than buy rate.');
        END IF;

        IF p_rate_date IS NULL THEN
            RAISE_APPLICATION_ERROR(-20606, 'Rate date cannot be null.');
        END IF;

        l_rate_date  := TRUNC(p_rate_date);
        l_created_by := NVL(TRIM(p_created_by), USER);

        validate_currency(p_currency_id, -20607, 'Currency does not exist.');
        validate_currency(p_base_currency_id, -20608, 'Base currency does not exist.');

        SELECT COUNT(*)
          INTO l_duplicate_count
          FROM exchange_rates
         WHERE currency_id = p_currency_id
           AND base_currency_id = p_base_currency_id
           AND rate_date = l_rate_date;

        IF l_duplicate_count > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20609,
                'An exchange rate already exists for this currency pair and date.'
            );
        END IF;

        INSERT INTO exchange_rates (
            currency_id,
            base_currency_id,
            buy_rate,
            sell_rate,
            rate_date,
            created_at,
            created_by,
            updated_at,
            updated_by
        )
        VALUES (
            p_currency_id,
            p_base_currency_id,
            p_buy_rate,
            p_sell_rate,
            l_rate_date,
            SYSDATE,
            l_created_by,
            NULL,
            NULL
        )
        RETURNING rate_id INTO p_rate_id;

        pkg_audit.log_action(
            p_action_type    => 'INSERT',
            p_entity_name    => 'EXCHANGE_RATES',
            p_entity_id      => TO_CHAR(p_rate_id),
            p_operation_name => 'ADD_EXCHANGE_RATE',
            p_new_data       => JSON_OBJECT(
                                    'currency_id' VALUE p_currency_id,
                                    'base_currency_id' VALUE p_base_currency_id,
                                    'buy_rate' VALUE p_buy_rate,
                                    'sell_rate' VALUE p_sell_rate,
                                    'rate_date' VALUE TO_CHAR(l_rate_date, 'YYYY-MM-DD'),
                                    'created_by' VALUE l_created_by
                                    RETURNING VARCHAR2
                                ),
            p_context_data   => JSON_OBJECT(
                                    'package' VALUE 'PKG_EXCHANGE_RATE_MANAGEMENT',
                                    'result' VALUE 'SUCCESS'
                                    RETURNING VARCHAR2
                                )
        );

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            p_rate_id := NULL;
            RAISE_APPLICATION_ERROR(
                -20609,
                'An exchange rate already exists for this currency pair and date.'
            );

        WHEN OTHERS THEN
            log_error_safely(
                'PKG_EXCHANGE_RATE_MANAGEMENT.ADD_EXCHANGE_RATE',
                'EXCHANGE_RATES',
                TO_CHAR(p_rate_id),
                JSON_OBJECT(
                    'currency_id' VALUE p_currency_id,
                    'base_currency_id' VALUE p_base_currency_id,
                    'buy_rate' VALUE p_buy_rate,
                    'sell_rate' VALUE p_sell_rate,
                    'rate_date' VALUE TO_CHAR(p_rate_date, 'YYYY-MM-DD'),
                    'sqlcode' VALUE SQLCODE,
                    'sqlerrm' VALUE SQLERRM
                    RETURNING VARCHAR2
                )
            );
            p_rate_id := NULL;
            RAISE;
    END add_exchange_rate;


    PROCEDURE update_exchange_rate (
        p_rate_id    IN exchange_rates.rate_id%TYPE,
        p_buy_rate   IN exchange_rates.buy_rate%TYPE,
        p_sell_rate  IN exchange_rates.sell_rate%TYPE,
        p_updated_by IN exchange_rates.updated_by%TYPE DEFAULT USER
    )
    IS
        l_old_buy_rate  exchange_rates.buy_rate%TYPE;
        l_old_sell_rate exchange_rates.sell_rate%TYPE;
        l_currency_id   exchange_rates.currency_id%TYPE;
        l_base_currency exchange_rates.base_currency_id%TYPE;
        l_rate_date     exchange_rates.rate_date%TYPE;
        l_updated_by    exchange_rates.updated_by%TYPE;
    BEGIN
        IF p_rate_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20620, 'Rate ID cannot be null.');
        END IF;

        IF p_buy_rate IS NULL OR p_buy_rate <= 0 THEN
            RAISE_APPLICATION_ERROR(-20621, 'Buy rate must be greater than zero.');
        END IF;

        IF p_sell_rate IS NULL OR p_sell_rate <= 0 THEN
            RAISE_APPLICATION_ERROR(-20622, 'Sell rate must be greater than zero.');
        END IF;

        IF p_sell_rate < p_buy_rate THEN
            RAISE_APPLICATION_ERROR(-20623, 'Sell rate cannot be lower than buy rate.');
        END IF;

        l_updated_by := NVL(TRIM(p_updated_by), USER);

        BEGIN
            SELECT buy_rate,
                   sell_rate,
                   currency_id,
                   base_currency_id,
                   rate_date
              INTO l_old_buy_rate,
                   l_old_sell_rate,
                   l_currency_id,
                   l_base_currency,
                   l_rate_date
              FROM exchange_rates
             WHERE rate_id = p_rate_id
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20624, 'Exchange rate does not exist.');
        END;

        IF l_old_buy_rate = p_buy_rate
           AND l_old_sell_rate = p_sell_rate
        THEN
            RAISE_APPLICATION_ERROR(
                -20625,
                'New rates must be different from the current rates.'
            );
        END IF;

        UPDATE exchange_rates
           SET buy_rate   = p_buy_rate,
               sell_rate  = p_sell_rate,
               updated_at = SYSDATE,
               updated_by = l_updated_by
         WHERE rate_id = p_rate_id;

        pkg_audit.log_action(
            p_action_type    => 'UPDATE',
            p_entity_name    => 'EXCHANGE_RATES',
            p_entity_id      => TO_CHAR(p_rate_id),
            p_operation_name => 'UPDATE_EXCHANGE_RATE',
            p_old_data       => JSON_OBJECT(
                                    'buy_rate' VALUE l_old_buy_rate,
                                    'sell_rate' VALUE l_old_sell_rate
                                    RETURNING VARCHAR2
                                ),
            p_new_data       => JSON_OBJECT(
                                    'buy_rate' VALUE p_buy_rate,
                                    'sell_rate' VALUE p_sell_rate,
                                    'updated_by' VALUE l_updated_by
                                    RETURNING VARCHAR2
                                ),
            p_context_data   => JSON_OBJECT(
                                    'package' VALUE 'PKG_EXCHANGE_RATE_MANAGEMENT',
                                    'currency_id' VALUE l_currency_id,
                                    'base_currency_id' VALUE l_base_currency,
                                    'rate_date' VALUE TO_CHAR(l_rate_date, 'YYYY-MM-DD'),
                                    'result' VALUE 'SUCCESS'
                                    RETURNING VARCHAR2
                                )
        );

    EXCEPTION
        WHEN OTHERS THEN
            log_error_safely(
                'PKG_EXCHANGE_RATE_MANAGEMENT.UPDATE_EXCHANGE_RATE',
                'EXCHANGE_RATES',
                TO_CHAR(p_rate_id),
                JSON_OBJECT(
                    'buy_rate' VALUE p_buy_rate,
                    'sell_rate' VALUE p_sell_rate,
                    'sqlcode' VALUE SQLCODE,
                    'sqlerrm' VALUE SQLERRM
                    RETURNING VARCHAR2
                )
            );
            RAISE;
    END update_exchange_rate;


    PROCEDURE get_latest_rate (
        p_currency_id      IN  exchange_rates.currency_id%TYPE,
        p_base_currency_id IN  exchange_rates.base_currency_id%TYPE,
        p_result           OUT SYS_REFCURSOR
    )
    IS
        l_rate_id exchange_rates.rate_id%TYPE;
    BEGIN
        IF p_currency_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20630, 'Currency ID cannot be null.');
        END IF;

        IF p_base_currency_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20631, 'Base currency ID cannot be null.');
        END IF;

        IF p_currency_id = p_base_currency_id THEN
            RAISE_APPLICATION_ERROR(-20632, 'Currency and base currency must be different.');
        END IF;

        validate_currency(p_currency_id, -20633, 'Currency does not exist.');
        validate_currency(p_base_currency_id, -20634, 'Base currency does not exist.');

        BEGIN
            SELECT rate_id
              INTO l_rate_id
              FROM (
                    SELECT rate_id
                      FROM exchange_rates
                     WHERE currency_id = p_currency_id
                       AND base_currency_id = p_base_currency_id
                     ORDER BY rate_date DESC, rate_id DESC
                   )
             WHERE ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20635,
                    'No exchange rate exists for this currency pair.'
                );
        END;

        OPEN p_result FOR
            SELECT er.rate_id,
                   er.currency_id,
                   c.currency_code,
                   er.base_currency_id,
                   bc.currency_code AS base_currency_code,
                   er.buy_rate,
                   er.sell_rate,
                   er.rate_date,
                   er.created_at,
                   er.created_by,
                   er.updated_at,
                   er.updated_by
              FROM exchange_rates er
              JOIN currencies c
                ON c.currency_id = er.currency_id
              JOIN currencies bc
                ON bc.currency_id = er.base_currency_id
             WHERE er.rate_id = l_rate_id;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_result%ISOPEN THEN
                CLOSE p_result;
            END IF;

            log_error_safely(
                'PKG_EXCHANGE_RATE_MANAGEMENT.GET_LATEST_RATE',
                'EXCHANGE_RATES',
                NULL,
                JSON_OBJECT(
                    'currency_id' VALUE p_currency_id,
                    'base_currency_id' VALUE p_base_currency_id,
                    'sqlcode' VALUE SQLCODE,
                    'sqlerrm' VALUE SQLERRM
                    RETURNING VARCHAR2
                )
            );
            RAISE;
    END get_latest_rate;


    PROCEDURE get_rate_by_date (
        p_currency_id      IN  exchange_rates.currency_id%TYPE,
        p_base_currency_id IN  exchange_rates.base_currency_id%TYPE,
        p_rate_date        IN  exchange_rates.rate_date%TYPE,
        p_result           OUT SYS_REFCURSOR
    )
    IS
        l_rate_id   exchange_rates.rate_id%TYPE;
        l_rate_date exchange_rates.rate_date%TYPE;
    BEGIN
        IF p_currency_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20640, 'Currency ID cannot be null.');
        END IF;

        IF p_base_currency_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20641, 'Base currency ID cannot be null.');
        END IF;

        IF p_currency_id = p_base_currency_id THEN
            RAISE_APPLICATION_ERROR(-20642, 'Currency and base currency must be different.');
        END IF;

        IF p_rate_date IS NULL THEN
            RAISE_APPLICATION_ERROR(-20643, 'Rate date cannot be null.');
        END IF;

        l_rate_date := TRUNC(p_rate_date);

        validate_currency(p_currency_id, -20644, 'Currency does not exist.');
        validate_currency(p_base_currency_id, -20645, 'Base currency does not exist.');

        BEGIN
            SELECT rate_id
              INTO l_rate_id
              FROM exchange_rates
             WHERE currency_id = p_currency_id
               AND base_currency_id = p_base_currency_id
               AND rate_date = l_rate_date;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20646,
                    'No exchange rate exists for this currency pair and date.'
                );
        END;

        OPEN p_result FOR
            SELECT er.rate_id,
                   er.currency_id,
                   c.currency_code,
                   er.base_currency_id,
                   bc.currency_code AS base_currency_code,
                   er.buy_rate,
                   er.sell_rate,
                   er.rate_date,
                   er.created_at,
                   er.created_by,
                   er.updated_at,
                   er.updated_by
              FROM exchange_rates er
              JOIN currencies c
                ON c.currency_id = er.currency_id
              JOIN currencies bc
                ON bc.currency_id = er.base_currency_id
             WHERE er.rate_id = l_rate_id;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_result%ISOPEN THEN
                CLOSE p_result;
            END IF;

            log_error_safely(
                'PKG_EXCHANGE_RATE_MANAGEMENT.GET_RATE_BY_DATE',
                'EXCHANGE_RATES',
                NULL,
                JSON_OBJECT(
                    'currency_id' VALUE p_currency_id,
                    'base_currency_id' VALUE p_base_currency_id,
                    'rate_date' VALUE TO_CHAR(p_rate_date, 'YYYY-MM-DD'),
                    'sqlcode' VALUE SQLCODE,
                    'sqlerrm' VALUE SQLERRM
                    RETURNING VARCHAR2
                )
            );
            RAISE;
    END get_rate_by_date;


    FUNCTION convert_amount (
        p_amount           IN transactions.amount%TYPE,
        p_currency_id      IN exchange_rates.currency_id%TYPE,
        p_base_currency_id IN exchange_rates.base_currency_id%TYPE,
        p_rate_type        IN VARCHAR2 DEFAULT 'SELL',
        p_rate_date        IN exchange_rates.rate_date%TYPE DEFAULT NULL
    )
    RETURN NUMBER
    IS
        l_rate_type VARCHAR2(4);
        l_rate      exchange_rates.sell_rate%TYPE;
    BEGIN
        IF p_amount IS NULL OR p_amount <= 0 THEN
            RAISE_APPLICATION_ERROR(-20650, 'Amount must be greater than zero.');
        END IF;

        IF p_currency_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20651, 'Currency ID cannot be null.');
        END IF;

        IF p_base_currency_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20652, 'Base currency ID cannot be null.');
        END IF;

        IF p_currency_id = p_base_currency_id THEN
            RAISE_APPLICATION_ERROR(-20653, 'Currency and base currency must be different.');
        END IF;

        l_rate_type := UPPER(TRIM(p_rate_type));

        IF l_rate_type NOT IN (c_rate_type_buy, c_rate_type_sell) THEN
            RAISE_APPLICATION_ERROR(-20654, 'Rate type must be BUY or SELL.');
        END IF;

        validate_currency(p_currency_id, -20655, 'Currency does not exist.');
        validate_currency(p_base_currency_id, -20656, 'Base currency does not exist.');

        BEGIN
            IF p_rate_date IS NULL THEN
                SELECT CASE
                           WHEN l_rate_type = c_rate_type_buy THEN buy_rate
                           ELSE sell_rate
                       END
                  INTO l_rate
                  FROM (
                        SELECT buy_rate, sell_rate
                          FROM exchange_rates
                         WHERE currency_id = p_currency_id
                           AND base_currency_id = p_base_currency_id
                         ORDER BY rate_date DESC, rate_id DESC
                       )
                 WHERE ROWNUM = 1;
            ELSE
                SELECT CASE
                           WHEN l_rate_type = c_rate_type_buy THEN buy_rate
                           ELSE sell_rate
                       END
                  INTO l_rate
                  FROM exchange_rates
                 WHERE currency_id = p_currency_id
                   AND base_currency_id = p_base_currency_id
                   AND rate_date = TRUNC(p_rate_date);
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                IF p_rate_date IS NULL THEN
                    RAISE_APPLICATION_ERROR(
                        -20657,
                        'No exchange rate exists for this currency pair.'
                    );
                ELSE
                    RAISE_APPLICATION_ERROR(
                        -20658,
                        'No exchange rate exists for this currency pair and date.'
                    );
                END IF;
        END;

        RETURN ROUND(p_amount * l_rate, 2);

    EXCEPTION
        WHEN OTHERS THEN
            log_error_safely(
                'PKG_EXCHANGE_RATE_MANAGEMENT.CONVERT_AMOUNT',
                'EXCHANGE_RATES',
                NULL,
                JSON_OBJECT(
                    'amount' VALUE p_amount,
                    'currency_id' VALUE p_currency_id,
                    'base_currency_id' VALUE p_base_currency_id,
                    'rate_type' VALUE p_rate_type,
                    'rate_date' VALUE TO_CHAR(p_rate_date, 'YYYY-MM-DD'),
                    'sqlcode' VALUE SQLCODE,
                    'sqlerrm' VALUE SQLERRM
                    RETURNING VARCHAR2
                )
            );
            RAISE;
    END convert_amount;

END pkg_exchange_rate_management;
