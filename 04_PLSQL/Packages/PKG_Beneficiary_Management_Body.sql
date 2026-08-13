-- ============================================================================
-- Package Body         : PKG_BENEFICIARY_MANAGEMENT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Implements beneficiary registration, maintenance, and retrieval logic.
--
-- Implementation Notes
--   * Validates customer and beneficiary-account status before registration.
--   * Prevents customers from registering their own accounts as beneficiaries.
--   * Prevents duplicate beneficiary registrations.
--   * Uses the BENEFICIARIES identity column for primary-key generation.
--   * Records successful business actions through PKG_AUDIT.
--   * Records unexpected errors through PKG_ERROR_LOG.
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Transaction control remains with the calling application or script.
-- ============================================================================

create or replace PACKAGE BODY pkg_beneficiary_management
AS
    ----------------------------------------------------------------------------
    -- Adds a beneficiary account for a customer.
    ----------------------------------------------------------------------------
    PROCEDURE add_beneficiary (
        p_customer_id            IN  beneficiaries.customer_id%TYPE,
        p_beneficiary_account_id IN  beneficiaries.beneficiary_account_id%TYPE,
        p_nickname               IN  beneficiaries.nickname%TYPE,
        p_created_by             IN  beneficiaries.created_by%TYPE DEFAULT USER,
        p_beneficiary_id         OUT beneficiaries.beneficiary_id%TYPE
    )
    IS
        l_customer_status  customers.status%TYPE;
        l_account_owner_id accounts.customer_id%TYPE;
        l_account_status   accounts.status%TYPE;
        l_created_by       beneficiaries.created_by%TYPE;
        l_nickname         beneficiaries.nickname%TYPE;
        l_duplicate_count  PLS_INTEGER;
    BEGIN
        p_beneficiary_id := NULL;

        ------------------------------------------------------------------------
        -- Parameter validation
        ------------------------------------------------------------------------
        IF p_customer_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20500,
                'Customer ID cannot be null.'
            );
        END IF;

        IF p_beneficiary_account_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20501,
                'Beneficiary account ID cannot be null.'
            );
        END IF;

        l_created_by := NVL(TRIM(p_created_by), USER);
        l_nickname   := NULLIF(TRIM(p_nickname), '');

        ------------------------------------------------------------------------
        -- Validate customer
        ------------------------------------------------------------------------
        BEGIN
            SELECT status
              INTO l_customer_status
              FROM customers
             WHERE customer_id = p_customer_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20502,
                    'Customer does not exist.'
                );
        END;

        IF UPPER(TRIM(l_customer_status)) <> 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(
                -20503,
                'Beneficiaries can only be added for active customers.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Validate beneficiary account
        ------------------------------------------------------------------------
        BEGIN
            SELECT customer_id,
                   status
              INTO l_account_owner_id,
                   l_account_status
              FROM accounts
             WHERE account_id = p_beneficiary_account_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20504,
                    'Beneficiary account does not exist.'
                );
        END;

        IF UPPER(TRIM(l_account_status)) <> 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(
                -20505,
                'Beneficiary account must be active.'
            );
        END IF;

        IF l_account_owner_id = p_customer_id THEN
            RAISE_APPLICATION_ERROR(
                -20506,
                'A customer cannot register their own account as a beneficiary.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Validate duplicate registration
        ------------------------------------------------------------------------
        SELECT COUNT(*)
          INTO l_duplicate_count
          FROM beneficiaries
         WHERE customer_id = p_customer_id
           AND beneficiary_account_id = p_beneficiary_account_id;

        IF l_duplicate_count > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20507,
                'This beneficiary account is already registered for the customer.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Create beneficiary
        --
        -- BENEFICIARY_ID is a BY DEFAULT identity column. Oracle generates the
        -- primary key, and RETURNING retrieves it for the caller.
        ------------------------------------------------------------------------
        INSERT INTO beneficiaries (
            customer_id,
            beneficiary_account_id,
            nickname,
            created_at,
            created_by,
            updated_at,
            updated_by
        )
        VALUES (
            p_customer_id,
            p_beneficiary_account_id,
            l_nickname,
            SYSTIMESTAMP,
            l_created_by,
            NULL,
            NULL
        )
        RETURNING beneficiary_id
        INTO p_beneficiary_id;

        ------------------------------------------------------------------------
        -- Audit successful operation
        ------------------------------------------------------------------------
        pkg_audit.log_action(
            p_action_type    => 'INSERT',
            p_entity_name    => 'BENEFICIARIES',
            p_entity_id      => TO_CHAR(p_beneficiary_id),
            p_operation_name => 'ADD_BENEFICIARY',
            p_old_data       => NULL,
            p_new_data       => JSON_OBJECT(
                                    'customer_id'
                                        VALUE p_customer_id,
                                    'beneficiary_account_id'
                                        VALUE p_beneficiary_account_id,
                                    'nickname'
                                        VALUE l_nickname,
                                    'created_by'
                                        VALUE l_created_by
                                    RETURNING VARCHAR2
                                ),
            p_context_data   => JSON_OBJECT(
                                    'package'
                                        VALUE 'PKG_BENEFICIARY_MANAGEMENT',
                                    'result'
                                        VALUE 'SUCCESS'
                                    RETURNING VARCHAR2
                                )
        );

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            pkg_error_log.log_error(
                p_operation_name => 'PKG_BENEFICIARY_MANAGEMENT.ADD_BENEFICIARY',
                p_entity_name    => 'BENEFICIARIES',
                p_entity_id      => TO_CHAR(p_beneficiary_id),
                p_context_data   => JSON_OBJECT(
                                        'customer_id'
                                            VALUE p_customer_id,
                                        'beneficiary_account_id'
                                            VALUE p_beneficiary_account_id,
                                        'sqlcode'
                                            VALUE SQLCODE,
                                        'sqlerrm'
                                            VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            p_beneficiary_id := NULL;

            RAISE_APPLICATION_ERROR(
                -20507,
                'This beneficiary account is already registered for the customer.'
            );

        WHEN OTHERS THEN
            pkg_error_log.log_error(
                p_operation_name => 'PKG_BENEFICIARY_MANAGEMENT.ADD_BENEFICIARY',
                p_entity_name    => 'BENEFICIARIES',
                p_entity_id      => TO_CHAR(p_beneficiary_id),
                p_context_data   => JSON_OBJECT(
                                        'customer_id'
                                            VALUE p_customer_id,
                                        'beneficiary_account_id'
                                            VALUE p_beneficiary_account_id,
                                        'created_by'
                                            VALUE NVL(TRIM(p_created_by), USER),
                                        'sqlcode'
                                            VALUE SQLCODE,
                                        'sqlerrm'
                                            VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            p_beneficiary_id := NULL;
            RAISE;
    END add_beneficiary;


    ----------------------------------------------------------------------------
    -- Updates only the user-defined nickname of an existing beneficiary.
    ----------------------------------------------------------------------------
    PROCEDURE update_beneficiary_nickname (
        p_beneficiary_id IN beneficiaries.beneficiary_id%TYPE,
        p_nickname       IN beneficiaries.nickname%TYPE,
        p_updated_by     IN beneficiaries.updated_by%TYPE DEFAULT USER
    )
    IS
        l_old_nickname beneficiaries.nickname%TYPE;
        l_new_nickname beneficiaries.nickname%TYPE;
        l_customer_id  beneficiaries.customer_id%TYPE;
        l_account_id   beneficiaries.beneficiary_account_id%TYPE;
        l_updated_by   beneficiaries.updated_by%TYPE;
    BEGIN
        ------------------------------------------------------------------------
        -- Parameter validation
        ------------------------------------------------------------------------
        IF p_beneficiary_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20510,
                'Beneficiary ID cannot be null.'
            );
        END IF;

        l_new_nickname := NULLIF(TRIM(p_nickname), '');
        l_updated_by   := NVL(TRIM(p_updated_by), USER);

        ------------------------------------------------------------------------
        -- Retrieve and lock beneficiary
        ------------------------------------------------------------------------
        BEGIN
            SELECT nickname,
                   customer_id,
                   beneficiary_account_id
              INTO l_old_nickname,
                   l_customer_id,
                   l_account_id
              FROM beneficiaries
             WHERE beneficiary_id = p_beneficiary_id
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20511,
                    'Beneficiary does not exist.'
                );
        END;

        ------------------------------------------------------------------------
        -- Prevent a meaningless update
        ------------------------------------------------------------------------
        IF NVL(l_old_nickname, CHR(0)) = NVL(l_new_nickname, CHR(0)) THEN
            RAISE_APPLICATION_ERROR(
                -20512,
                'The new nickname must be different from the current nickname.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Update nickname
        ------------------------------------------------------------------------
        UPDATE beneficiaries
           SET nickname   = l_new_nickname,
               updated_at = SYSTIMESTAMP,
               updated_by = l_updated_by
         WHERE beneficiary_id = p_beneficiary_id;

        ------------------------------------------------------------------------
        -- Audit successful operation
        ------------------------------------------------------------------------
        pkg_audit.log_action(
            p_action_type    => 'UPDATE',
            p_entity_name    => 'BENEFICIARIES',
            p_entity_id      => TO_CHAR(p_beneficiary_id),
            p_operation_name => 'UPDATE_BENEFICIARY_NICKNAME',
            p_old_data       => JSON_OBJECT(
                                    'nickname'
                                        VALUE l_old_nickname
                                    RETURNING VARCHAR2
                                ),
            p_new_data       => JSON_OBJECT(
                                    'nickname'
                                        VALUE l_new_nickname,
                                    'updated_by'
                                        VALUE l_updated_by
                                    RETURNING VARCHAR2
                                ),
            p_context_data   => JSON_OBJECT(
                                    'package'
                                        VALUE 'PKG_BENEFICIARY_MANAGEMENT',
                                    'customer_id'
                                        VALUE l_customer_id,
                                    'beneficiary_account_id'
                                        VALUE l_account_id,
                                    'result'
                                        VALUE 'SUCCESS'
                                    RETURNING VARCHAR2
                                )
        );

    EXCEPTION
        WHEN OTHERS THEN
            pkg_error_log.log_error(
                p_operation_name =>
                    'PKG_BENEFICIARY_MANAGEMENT.UPDATE_BENEFICIARY_NICKNAME',
                p_entity_name    => 'BENEFICIARIES',
                p_entity_id      => TO_CHAR(p_beneficiary_id),
                p_context_data   => JSON_OBJECT(
                                        'nickname'
                                            VALUE NULLIF(TRIM(p_nickname), ''),
                                        'updated_by'
                                            VALUE NVL(TRIM(p_updated_by), USER),
                                        'sqlcode'
                                            VALUE SQLCODE,
                                        'sqlerrm'
                                            VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END update_beneficiary_nickname;


    ----------------------------------------------------------------------------
    -- Removes a beneficiary registration.
    ----------------------------------------------------------------------------
    PROCEDURE remove_beneficiary (
        p_beneficiary_id IN beneficiaries.beneficiary_id%TYPE,
        p_removed_by     IN beneficiaries.updated_by%TYPE DEFAULT USER
    )
    IS
        l_customer_id beneficiaries.customer_id%TYPE;
        l_account_id  beneficiaries.beneficiary_account_id%TYPE;
        l_nickname    beneficiaries.nickname%TYPE;
        l_removed_by  beneficiaries.updated_by%TYPE;
    BEGIN
        ------------------------------------------------------------------------
        -- Parameter validation
        ------------------------------------------------------------------------
        IF p_beneficiary_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20520,
                'Beneficiary ID cannot be null.'
            );
        END IF;

        l_removed_by := NVL(TRIM(p_removed_by), USER);

        ------------------------------------------------------------------------
        -- Retrieve and lock beneficiary
        ------------------------------------------------------------------------
        BEGIN
            SELECT customer_id,
                   beneficiary_account_id,
                   nickname
              INTO l_customer_id,
                   l_account_id,
                   l_nickname
              FROM beneficiaries
             WHERE beneficiary_id = p_beneficiary_id
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20521,
                    'Beneficiary does not exist.'
                );
        END;

        ------------------------------------------------------------------------
        -- Audit before deletion so the removed values remain available
        ------------------------------------------------------------------------
        pkg_audit.log_action(
            p_action_type    => 'DELETE',
            p_entity_name    => 'BENEFICIARIES',
            p_entity_id      => TO_CHAR(p_beneficiary_id),
            p_operation_name => 'REMOVE_BENEFICIARY',
            p_old_data       => JSON_OBJECT(
                                    'customer_id'
                                        VALUE l_customer_id,
                                    'beneficiary_account_id'
                                        VALUE l_account_id,
                                    'nickname'
                                        VALUE l_nickname
                                    RETURNING VARCHAR2
                                ),
            p_new_data       => NULL,
            p_context_data   => JSON_OBJECT(
                                    'package'
                                        VALUE 'PKG_BENEFICIARY_MANAGEMENT',
                                    'removed_by'
                                        VALUE l_removed_by,
                                    'result'
                                        VALUE 'SUCCESS'
                                    RETURNING VARCHAR2
                                )
        );

        DELETE FROM beneficiaries
         WHERE beneficiary_id = p_beneficiary_id;

    EXCEPTION
        WHEN OTHERS THEN
            pkg_error_log.log_error(
                p_operation_name => 'PKG_BENEFICIARY_MANAGEMENT.REMOVE_BENEFICIARY',
                p_entity_name    => 'BENEFICIARIES',
                p_entity_id      => TO_CHAR(p_beneficiary_id),
                p_context_data   => JSON_OBJECT(
                                        'removed_by'
                                            VALUE NVL(TRIM(p_removed_by), USER),
                                        'sqlcode'
                                            VALUE SQLCODE,
                                        'sqlerrm'
                                            VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END remove_beneficiary;


    ----------------------------------------------------------------------------
    -- Returns detailed information for one beneficiary registration.
    ----------------------------------------------------------------------------
    PROCEDURE get_beneficiary_info (
        p_beneficiary_id IN  beneficiaries.beneficiary_id%TYPE,
        p_result         OUT SYS_REFCURSOR
    )
    IS
        l_count PLS_INTEGER;
    BEGIN
        ------------------------------------------------------------------------
        -- Parameter validation
        ------------------------------------------------------------------------
        IF p_beneficiary_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20530,
                'Beneficiary ID cannot be null.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Verify beneficiary existence
        ------------------------------------------------------------------------
        SELECT COUNT(*)
          INTO l_count
          FROM beneficiaries
         WHERE beneficiary_id = p_beneficiary_id;

        IF l_count = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20531,
                'Beneficiary does not exist.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Return beneficiary details
        ------------------------------------------------------------------------
        OPEN p_result FOR
            SELECT b.beneficiary_id,
                   b.customer_id,
                   b.beneficiary_account_id,
                   b.nickname,
                   a.account_number AS beneficiary_account_number,
                   a.iban           AS beneficiary_iban,
                   a.status         AS beneficiary_account_status,
                   b.created_at,
                   b.created_by,
                   b.updated_at,
                   b.updated_by
              FROM beneficiaries b
              JOIN accounts a
                ON a.account_id = b.beneficiary_account_id
             WHERE b.beneficiary_id = p_beneficiary_id;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_result%ISOPEN THEN
                CLOSE p_result;
            END IF;

            pkg_error_log.log_error(
                p_operation_name =>
                    'PKG_BENEFICIARY_MANAGEMENT.GET_BENEFICIARY_INFO',
                p_entity_name    => 'BENEFICIARIES',
                p_entity_id      => TO_CHAR(p_beneficiary_id),
                p_context_data   => JSON_OBJECT(
                                        'sqlcode'
                                            VALUE SQLCODE,
                                        'sqlerrm'
                                            VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END get_beneficiary_info;


    ----------------------------------------------------------------------------
    -- Returns all beneficiary registrations belonging to one customer.
    ----------------------------------------------------------------------------
    PROCEDURE get_customer_beneficiaries (
        p_customer_id IN  beneficiaries.customer_id%TYPE,
        p_result      OUT SYS_REFCURSOR
    )
    IS
        l_customer_status customers.status%TYPE;
    BEGIN
        ------------------------------------------------------------------------
        -- Parameter validation
        ------------------------------------------------------------------------
        IF p_customer_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20540,
                'Customer ID cannot be null.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Verify customer existence
        ------------------------------------------------------------------------
        BEGIN
            SELECT status
              INTO l_customer_status
              FROM customers
             WHERE customer_id = p_customer_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20541,
                    'Customer does not exist.'
                );
        END;

        ------------------------------------------------------------------------
        -- Return customer beneficiaries
        ------------------------------------------------------------------------
        OPEN p_result FOR
            SELECT b.beneficiary_id,
                   b.customer_id,
                   b.beneficiary_account_id,
                   b.nickname,
                   a.account_number AS beneficiary_account_number,
                   a.iban           AS beneficiary_iban,
                   a.status         AS beneficiary_account_status,
                   b.created_at,
                   b.created_by,
                   b.updated_at,
                   b.updated_by
              FROM beneficiaries b
              JOIN accounts a
                ON a.account_id = b.beneficiary_account_id
             WHERE b.customer_id = p_customer_id
             ORDER BY UPPER(NVL(b.nickname, a.iban)),
                      b.beneficiary_id;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_result%ISOPEN THEN
                CLOSE p_result;
            END IF;

            pkg_error_log.log_error(
                p_operation_name =>
                    'PKG_BENEFICIARY_MANAGEMENT.GET_CUSTOMER_BENEFICIARIES',
                p_entity_name    => 'CUSTOMERS',
                p_entity_id      => TO_CHAR(p_customer_id),
                p_context_data   => JSON_OBJECT(
                                        'sqlcode'
                                            VALUE SQLCODE,
                                        'sqlerrm'
                                            VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END get_customer_beneficiaries;

END pkg_beneficiary_management;
