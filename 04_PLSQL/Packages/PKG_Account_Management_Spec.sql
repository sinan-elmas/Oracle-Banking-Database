-- ============================================================================
-- Package Specification: PKG_ACCOUNT_MANAGEMENT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Defines the public interface for account lifecycle management.
--
-- Responsibilities
--   * Open customer accounts
--   * Update account status
--   * Retrieve account details
--   * Return the current available balance
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Transaction control remains with the calling application or script.
--
-- Dependencies
--   * ACCOUNTS and related reference tables
--   * PKG_AUDIT
--   * PKG_ERROR_LOG
-- ============================================================================

create or replace PACKAGE pkg_account_management AS

    ----------------------------------------------------------------------------
    -- Opens a new bank account for an existing customer.
    ----------------------------------------------------------------------------
    PROCEDURE open_account(
        p_customer_id        IN  accounts.customer_id%TYPE,
        p_branch_id          IN  accounts.branch_id%TYPE,
        p_account_type_id    IN  accounts.account_type_id%TYPE,
        p_currency_id        IN  accounts.currency_id%TYPE,
        p_initial_balance    IN  accounts.balance%TYPE DEFAULT 0,
        p_created_by         IN  accounts.created_by%TYPE DEFAULT NULL,
        p_account_id         OUT accounts.account_id%TYPE,
        p_account_number     OUT accounts.account_number%TYPE,
        p_iban               OUT accounts.iban%TYPE
    );

    ----------------------------------------------------------------------------
    -- Updates the status of an existing bank account.
    --
    -- Supported statuses:
    --   ACTIVE
    --   BLOCKED
    --   CLOSED
    ----------------------------------------------------------------------------
    PROCEDURE update_account_status(
        p_account_id         IN accounts.account_id%TYPE,
        p_new_status         IN accounts.status%TYPE,
        p_updated_by         IN accounts.updated_by%TYPE DEFAULT NULL
    );

    ----------------------------------------------------------------------------
    -- Returns detailed account information through a reference cursor.
    ----------------------------------------------------------------------------
    PROCEDURE get_account_info(
        p_account_id         IN  accounts.account_id%TYPE,
        p_result             OUT SYS_REFCURSOR
    );

    ----------------------------------------------------------------------------
    -- Returns the available balance of an account.
    ----------------------------------------------------------------------------
    FUNCTION get_available_balance(
        p_account_id         IN accounts.account_id%TYPE
    ) RETURN accounts.balance%TYPE;

END pkg_account_management;
