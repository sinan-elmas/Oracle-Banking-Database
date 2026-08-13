-- ============================================================================
-- Package Body         : PKG_CARD_MANAGEMENT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Implements card issuance, lifecycle management, and retrieval operations.
--
-- Implementation Notes
--   * Validates account and card-type eligibility before card issuance.
--   * Applies controlled status transitions for active, blocked, and closed
--     cards.
--   * Generates project-standard card numbers and expiry dates.
--   * Records successful business actions through PKG_AUDIT.
--   * Records unexpected errors through PKG_ERROR_LOG.
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Transaction control remains with the calling application or script.
-- ============================================================================

create or replace PACKAGE BODY pkg_card_management AS

    ----------------------------------------------------------------------------
    -- Creates a new card for an account.
    ----------------------------------------------------------------------------
    PROCEDURE issue_card (
        p_account_id      IN cards.account_id%TYPE,
        p_card_type_id    IN cards.card_type_id%TYPE,
        p_created_by      IN cards.created_by%TYPE DEFAULT USER,
        p_card_id         OUT cards.card_id%TYPE,
        p_card_number     OUT cards.card_number%TYPE
    )
    IS
        l_account_status  accounts.status%TYPE;
        l_card_type_count PLS_INTEGER;
        l_expiry_date     cards.expiry_date%TYPE;
    BEGIN
        ------------------------------------------------------------------------
        -- Parameter validation
        ------------------------------------------------------------------------
        IF p_account_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20410,
                'Account ID cannot be null.'
            );
        END IF;

        IF p_card_type_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20411,
                'Card type ID cannot be null.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Validate and lock account
        ------------------------------------------------------------------------
        BEGIN
            SELECT status
              INTO l_account_status
              FROM accounts
             WHERE account_id = p_account_id
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20412,
                    'Account does not exist.'
                );
        END;

        IF l_account_status <> 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(
                -20413,
                'Only active accounts can have new cards.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Validate card type
        ------------------------------------------------------------------------
        SELECT COUNT(*)
          INTO l_card_type_count
          FROM card_types
         WHERE card_type_id = p_card_type_id;

        IF l_card_type_count = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20414,
                'Card type does not exist.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Generate card values
        ------------------------------------------------------------------------
        p_card_id := card_seq.NEXTVAL;

        p_card_number :=
            '4000' ||
            LPAD(TO_CHAR(p_card_id), 12, '0');

        l_expiry_date := ADD_MONTHS(TRUNC(SYSDATE), 60);

        ------------------------------------------------------------------------
        -- Insert card
        ------------------------------------------------------------------------
        INSERT INTO cards (
            card_id,
            account_id,
            card_type_id,
            card_number,
            expiry_date,
            status,
            created_at,
            created_by
        )
        VALUES (
            p_card_id,
            p_account_id,
            p_card_type_id,
            p_card_number,
            l_expiry_date,
            'ACTIVE',
            SYSTIMESTAMP,
            NVL(p_created_by, USER)
        );

        ------------------------------------------------------------------------
        -- Audit
        ------------------------------------------------------------------------
        pkg_audit.log_action(
            p_action_type    => 'INSERT',
            p_entity_name    => 'CARDS',
            p_entity_id      => TO_CHAR(p_card_id),
            p_operation_name => 'ISSUE_CARD',
            p_new_data       => JSON_OBJECT(
                                    'card_id'      VALUE p_card_id,
                                    'account_id'   VALUE p_account_id,
                                    'card_type_id' VALUE p_card_type_id,
                                    'card_number'  VALUE p_card_number,
                                    'status'       VALUE 'ACTIVE'
                                    RETURNING VARCHAR2
                                ),
            p_context_data   => JSON_OBJECT(
                                    'package' VALUE 'PKG_CARD_MANAGEMENT',
                                    'result'  VALUE 'SUCCESS'
                                    RETURNING VARCHAR2
                                )
        );

    EXCEPTION
        WHEN OTHERS THEN
            pkg_error_log.log_error(
                p_operation_name => 'PKG_CARD_MANAGEMENT.ISSUE_CARD',
                p_entity_name    => 'CARDS',
                p_entity_id      => TO_CHAR(p_account_id),
                p_context_data   => JSON_OBJECT(
                                        'card_type_id' VALUE p_card_type_id,
                                        'sqlcode'      VALUE SQLCODE,
                                        'sqlerrm'      VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END issue_card;

    ----------------------------------------------------------------------------
    ----------------------------------------------------------------------------
    PROCEDURE activate_card (
    p_card_id    IN cards.card_id%TYPE,
    p_updated_by IN cards.updated_by%TYPE DEFAULT USER
)
IS
    l_card_status     cards.status%TYPE;
    l_account_id      cards.account_id%TYPE;
    l_account_status  accounts.status%TYPE;
    l_updated_by      cards.updated_by%TYPE;
BEGIN
    --------------------------------------------------------------------------
    -- Parameter validation
    --------------------------------------------------------------------------
    IF p_card_id IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20420,
            'Card ID cannot be null.'
        );
    END IF;

    l_updated_by := NVL(p_updated_by, USER);

    --------------------------------------------------------------------------
    -- Retrieve and lock card
    --------------------------------------------------------------------------
    BEGIN
        SELECT status,
               account_id
          INTO l_card_status,
               l_account_id
          FROM cards
         WHERE card_id = p_card_id
         FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20421,
                'Card does not exist.'
            );
    END;

    --------------------------------------------------------------------------
    -- Validate current card status
    --------------------------------------------------------------------------
    IF l_card_status = 'ACTIVE' THEN
        RAISE_APPLICATION_ERROR(
            -20422,
            'Card is already active.'
        );
    END IF;

    IF l_card_status = 'CLOSED' THEN
        RAISE_APPLICATION_ERROR(
            -20423,
            'Closed cards cannot be activated.'
        );
    END IF;

    IF l_card_status <> 'BLOCKED' THEN
        RAISE_APPLICATION_ERROR(
            -20424,
            'Only blocked cards can be activated.'
        );
    END IF;

    --------------------------------------------------------------------------
    -- Validate linked account
    --------------------------------------------------------------------------
    BEGIN
        SELECT status
          INTO l_account_status
          FROM accounts
         WHERE account_id = l_account_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20425,
                'The account linked to the card does not exist.'
            );
    END;

    IF l_account_status <> 'ACTIVE' THEN
        RAISE_APPLICATION_ERROR(
            -20426,
            'A card cannot be activated unless its account is active.'
        );
    END IF;

    --------------------------------------------------------------------------
    -- Activate card
    --------------------------------------------------------------------------
        UPDATE cards
           SET status     = 'ACTIVE',
               updated_at = SYSTIMESTAMP,
               updated_by = l_updated_by
         WHERE card_id = p_card_id;
    
        --------------------------------------------------------------------------
        -- Audit successful operation
        --------------------------------------------------------------------------
        pkg_audit.log_action(
            p_action_type    => 'UPDATE',
            p_entity_name    => 'CARDS',
            p_entity_id      => TO_CHAR(p_card_id),
            p_operation_name => 'ACTIVATE_CARD',
            p_old_data       => JSON_OBJECT(
                                    'status' VALUE l_card_status
                                    RETURNING VARCHAR2
                                ),
            p_new_data       => JSON_OBJECT(
                                    'status'     VALUE 'ACTIVE',
                                    'updated_by' VALUE l_updated_by
                                    RETURNING VARCHAR2
                                ),
            p_context_data   => JSON_OBJECT(
                                    'package'    VALUE 'PKG_CARD_MANAGEMENT',
                                    'account_id' VALUE l_account_id,
                                    'result'     VALUE 'SUCCESS'
                                    RETURNING VARCHAR2
                                )
        );
    
    EXCEPTION
        WHEN OTHERS THEN
            pkg_error_log.log_error(
                p_operation_name => 'PKG_CARD_MANAGEMENT.ACTIVATE_CARD',
                p_entity_name    => 'CARDS',
                p_entity_id      => TO_CHAR(p_card_id),
                p_context_data   => JSON_OBJECT(
                                        'updated_by' VALUE NVL(p_updated_by, USER),
                                        'sqlcode'    VALUE SQLCODE,
                                        'sqlerrm'    VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );
    
            RAISE;
    END activate_card;

    ----------------------------------------------------------------------------
    -- Blocks an active card.
    ----------------------------------------------------------------------------
    PROCEDURE block_card (
        p_card_id    IN cards.card_id%TYPE,
        p_updated_by IN cards.updated_by%TYPE DEFAULT USER
    )
    IS
        l_card_status cards.status%TYPE;
        l_account_id  cards.account_id%TYPE;
        l_updated_by  cards.updated_by%TYPE;
    BEGIN
        ------------------------------------------------------------------------
        -- Parameter validation
        ------------------------------------------------------------------------
        IF p_card_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20430,
                'Card ID cannot be null.'
            );
        END IF;

        l_updated_by := NVL(p_updated_by, USER);

        ------------------------------------------------------------------------
        -- Retrieve and lock card
        ------------------------------------------------------------------------
        BEGIN
            SELECT status,
                   account_id
              INTO l_card_status,
                   l_account_id
              FROM cards
             WHERE card_id = p_card_id
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20431,
                    'Card does not exist.'
                );
        END;

        ------------------------------------------------------------------------
        -- Validate current card status
        ------------------------------------------------------------------------
        IF l_card_status = 'BLOCKED' THEN
            RAISE_APPLICATION_ERROR(
                -20432,
                'Card is already blocked.'
            );
        END IF;

        IF l_card_status = 'CLOSED' THEN
            RAISE_APPLICATION_ERROR(
                -20433,
                'Closed cards cannot be blocked.'
            );
        END IF;

        IF l_card_status <> 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(
                -20434,
                'Only active cards can be blocked.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Block card
        ------------------------------------------------------------------------
        UPDATE cards
           SET status     = 'BLOCKED',
               updated_at = SYSTIMESTAMP,
               updated_by = l_updated_by
         WHERE card_id = p_card_id;

        ------------------------------------------------------------------------
        -- Audit successful operation
        ------------------------------------------------------------------------
        pkg_audit.log_action(
            p_action_type    => 'UPDATE',
            p_entity_name    => 'CARDS',
            p_entity_id      => TO_CHAR(p_card_id),
            p_operation_name => 'BLOCK_CARD',
            p_old_data       => JSON_OBJECT(
                                    'status' VALUE l_card_status
                                    RETURNING VARCHAR2
                                ),
            p_new_data       => JSON_OBJECT(
                                    'status'     VALUE 'BLOCKED',
                                    'updated_by' VALUE l_updated_by
                                    RETURNING VARCHAR2
                                ),
            p_context_data   => JSON_OBJECT(
                                    'package'    VALUE 'PKG_CARD_MANAGEMENT',
                                    'account_id' VALUE l_account_id,
                                    'result'     VALUE 'SUCCESS'
                                    RETURNING VARCHAR2
                                )
        );

    EXCEPTION
        WHEN OTHERS THEN
            pkg_error_log.log_error(
                p_operation_name => 'PKG_CARD_MANAGEMENT.BLOCK_CARD',
                p_entity_name    => 'CARDS',
                p_entity_id      => TO_CHAR(p_card_id),
                p_context_data   => JSON_OBJECT(
                                        'updated_by' VALUE NVL(p_updated_by, USER),
                                        'sqlcode'    VALUE SQLCODE,
                                        'sqlerrm'    VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END block_card;

    ----------------------------------------------------------------------------
    -- Permanently closes an active or blocked card.
    ----------------------------------------------------------------------------
    PROCEDURE close_card (
        p_card_id    IN cards.card_id%TYPE,
        p_updated_by IN cards.updated_by%TYPE DEFAULT USER
    )
    IS
        l_card_status cards.status%TYPE;
        l_account_id  cards.account_id%TYPE;
        l_updated_by  cards.updated_by%TYPE;
    BEGIN
        ------------------------------------------------------------------------
        -- Parameter validation
        ------------------------------------------------------------------------
        IF p_card_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20440,
                'Card ID cannot be null.'
            );
        END IF;

        l_updated_by := NVL(p_updated_by, USER);

        ------------------------------------------------------------------------
        -- Retrieve and lock card
        ------------------------------------------------------------------------
        BEGIN
            SELECT status,
                   account_id
              INTO l_card_status,
                   l_account_id
              FROM cards
             WHERE card_id = p_card_id
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20441,
                    'Card does not exist.'
                );
        END;

        ------------------------------------------------------------------------
        -- Validate current card status
        ------------------------------------------------------------------------
        IF l_card_status = 'CLOSED' THEN
            RAISE_APPLICATION_ERROR(
                -20442,
                'Card is already closed.'
            );
        END IF;

        IF l_card_status NOT IN ('ACTIVE', 'BLOCKED') THEN
            RAISE_APPLICATION_ERROR(
                -20443,
                'Only active or blocked cards can be closed.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Close card
        ------------------------------------------------------------------------
        UPDATE cards
           SET status     = 'CLOSED',
               updated_at = SYSTIMESTAMP,
               updated_by = l_updated_by
         WHERE card_id = p_card_id;

        ------------------------------------------------------------------------
        -- Audit successful operation
        ------------------------------------------------------------------------
        pkg_audit.log_action(
            p_action_type    => 'UPDATE',
            p_entity_name    => 'CARDS',
            p_entity_id      => TO_CHAR(p_card_id),
            p_operation_name => 'CLOSE_CARD',
            p_old_data       => JSON_OBJECT(
                                    'status' VALUE l_card_status
                                    RETURNING VARCHAR2
                                ),
            p_new_data       => JSON_OBJECT(
                                    'status'     VALUE 'CLOSED',
                                    'updated_by' VALUE l_updated_by
                                    RETURNING VARCHAR2
                                ),
            p_context_data   => JSON_OBJECT(
                                    'package'         VALUE 'PKG_CARD_MANAGEMENT',
                                    'account_id'      VALUE l_account_id,
                                    'previous_status' VALUE l_card_status,
                                    'result'          VALUE 'SUCCESS'
                                    RETURNING VARCHAR2
                                )
        );

    EXCEPTION
        WHEN OTHERS THEN
            pkg_error_log.log_error(
                p_operation_name => 'PKG_CARD_MANAGEMENT.CLOSE_CARD',
                p_entity_name    => 'CARDS',
                p_entity_id      => TO_CHAR(p_card_id),
                p_context_data   => JSON_OBJECT(
                                        'updated_by' VALUE NVL(p_updated_by, USER),
                                        'sqlcode'    VALUE SQLCODE,
                                        'sqlerrm'    VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END close_card;

    ----------------------------------------------------------------------------
    -- Returns detailed information for one card.
    ----------------------------------------------------------------------------
    PROCEDURE get_card_info (
        p_card_id IN cards.card_id%TYPE,
        p_result  OUT SYS_REFCURSOR
    )
    IS
        l_card_count PLS_INTEGER;
    BEGIN
        ------------------------------------------------------------------------
        -- Parameter validation
        ------------------------------------------------------------------------
        IF p_card_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20450,
                'Card ID cannot be null.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Verify card existence
        ------------------------------------------------------------------------
        SELECT COUNT(*)
          INTO l_card_count
          FROM cards
         WHERE card_id = p_card_id;

        IF l_card_count = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20451,
                'Card does not exist.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Return card details
        ------------------------------------------------------------------------
        OPEN p_result FOR
            SELECT c.card_id,
                   c.account_id,
                   c.card_type_id,
                   ct.type_name AS card_type_name,
                   c.card_number,
                   c.expiry_date,
                   c.status,
                   c.created_at,
                   c.created_by,
                   c.updated_at,
                   c.updated_by
              FROM cards c
              JOIN card_types ct
                ON ct.card_type_id = c.card_type_id
             WHERE c.card_id = p_card_id;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_result%ISOPEN THEN
                CLOSE p_result;
            END IF;

            pkg_error_log.log_error(
                p_operation_name => 'PKG_CARD_MANAGEMENT.GET_CARD_INFO',
                p_entity_name    => 'CARDS',
                p_entity_id      => TO_CHAR(p_card_id),
                p_context_data   => JSON_OBJECT(
                                        'sqlcode' VALUE SQLCODE,
                                        'sqlerrm' VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END get_card_info;

    ----------------------------------------------------------------------------
    -- Returns all cards belonging to one account.
    ----------------------------------------------------------------------------
    PROCEDURE get_account_cards (
        p_account_id IN cards.account_id%TYPE,
        p_result     OUT SYS_REFCURSOR
    )
    IS
        l_account_count PLS_INTEGER;
    BEGIN
        ------------------------------------------------------------------------
        -- Parameter validation
        ------------------------------------------------------------------------
        IF p_account_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20460,
                'Account ID cannot be null.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Verify account existence
        ------------------------------------------------------------------------
        SELECT COUNT(*)
          INTO l_account_count
          FROM accounts
         WHERE account_id = p_account_id;

        IF l_account_count = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20461,
                'Account does not exist.'
            );
        END IF;

        ------------------------------------------------------------------------
        -- Return account cards
        ------------------------------------------------------------------------
        OPEN p_result FOR
            SELECT c.card_id,
                   c.account_id,
                   c.card_type_id,
                   ct.type_name AS card_type_name,
                   c.card_number,
                   c.expiry_date,
                   c.status,
                   c.created_at,
                   c.created_by,
                   c.updated_at,
                   c.updated_by
              FROM cards c
              JOIN card_types ct
                ON ct.card_type_id = c.card_type_id
             WHERE c.account_id = p_account_id
             ORDER BY c.created_at DESC,
                      c.card_id DESC;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_result%ISOPEN THEN
                CLOSE p_result;
            END IF;

            pkg_error_log.log_error(
                p_operation_name => 'PKG_CARD_MANAGEMENT.GET_ACCOUNT_CARDS',
                p_entity_name    => 'ACCOUNTS',
                p_entity_id      => TO_CHAR(p_account_id),
                p_context_data   => JSON_OBJECT(
                                        'sqlcode' VALUE SQLCODE,
                                        'sqlerrm' VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END get_account_cards;

END pkg_card_management;