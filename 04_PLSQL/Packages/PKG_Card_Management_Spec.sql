-- ============================================================================
-- Package Specification: PKG_CARD_MANAGEMENT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Defines the public interface for card issuance, status management, and
--   card information retrieval.
--
-- Responsibilities
--   * Issue cards for eligible customer accounts
--   * Activate, block, and close cards
--   * Retrieve card details
--   * Return all cards linked to an account
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Transaction control remains with the calling application or script.
--
-- Dependencies
--   * CARDS, CARD_TYPES, and ACCOUNTS
--   * CARD_SEQ
--   * PKG_AUDIT
--   * PKG_ERROR_LOG
-- ============================================================================

create or replace PACKAGE pkg_card_management AS

    ----------------------------------------------------------------------------
    -- Creates a new card for an account.
    ----------------------------------------------------------------------------
    PROCEDURE issue_card (
        p_account_id      IN cards.account_id%TYPE,
        p_card_type_id    IN cards.card_type_id%TYPE,
        p_created_by      IN cards.created_by%TYPE DEFAULT USER,
        p_card_id         OUT cards.card_id%TYPE,
        p_card_number     OUT cards.card_number%TYPE
    );

    ----------------------------------------------------------------------------
    -- Activates a blocked card.
    ----------------------------------------------------------------------------
    PROCEDURE activate_card (
        p_card_id      IN cards.card_id%TYPE,
        p_updated_by   IN cards.updated_by%TYPE DEFAULT USER
    );

    ----------------------------------------------------------------------------
    -- Blocks an active card.
    ----------------------------------------------------------------------------
    PROCEDURE block_card (
        p_card_id      IN cards.card_id%TYPE,
        p_updated_by   IN cards.updated_by%TYPE DEFAULT USER
    );

    ----------------------------------------------------------------------------
    -- Permanently closes a card.
    ----------------------------------------------------------------------------
    PROCEDURE close_card (
        p_card_id      IN cards.card_id%TYPE,
        p_updated_by   IN cards.updated_by%TYPE DEFAULT USER
    );

    ----------------------------------------------------------------------------
    -- Returns a single card.
    ----------------------------------------------------------------------------
    PROCEDURE get_card_info (
        p_card_id   IN cards.card_id%TYPE,
        p_result    OUT SYS_REFCURSOR
    );

    ----------------------------------------------------------------------------
    -- Returns all cards of an account.
    ----------------------------------------------------------------------------
    PROCEDURE get_account_cards (
        p_account_id IN cards.account_id%TYPE,
        p_result     OUT SYS_REFCURSOR
    );

END pkg_card_management;
