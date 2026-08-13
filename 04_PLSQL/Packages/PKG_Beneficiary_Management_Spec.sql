-- ============================================================================
-- Package Specification: PKG_BENEFICIARY_MANAGEMENT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Defines the public interface for managing customer beneficiaries.
--
-- Responsibilities
--   * Register beneficiary accounts
--   * Update beneficiary nicknames
--   * Remove beneficiary registrations
--   * Retrieve beneficiary details and customer beneficiary lists
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Transaction control remains with the calling application or script.
--
-- Dependencies
--   * BENEFICIARIES, CUSTOMERS, and ACCOUNTS
--   * PKG_AUDIT
--   * PKG_ERROR_LOG
-- ============================================================================

create or replace PACKAGE pkg_beneficiary_management
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
    );

    ----------------------------------------------------------------------------
    -- Updates only the user-defined nickname of an existing beneficiary.
    ----------------------------------------------------------------------------
    PROCEDURE update_beneficiary_nickname (
        p_beneficiary_id IN beneficiaries.beneficiary_id%TYPE,
        p_nickname       IN beneficiaries.nickname%TYPE,
        p_updated_by     IN beneficiaries.updated_by%TYPE DEFAULT USER
    );

    ----------------------------------------------------------------------------
    -- Removes a beneficiary registration.
    ----------------------------------------------------------------------------
    PROCEDURE remove_beneficiary (
        p_beneficiary_id IN beneficiaries.beneficiary_id%TYPE,
        p_removed_by     IN beneficiaries.updated_by%TYPE DEFAULT USER
    );

    ----------------------------------------------------------------------------
    -- Returns detailed information for one beneficiary registration.
    ----------------------------------------------------------------------------
    PROCEDURE get_beneficiary_info (
        p_beneficiary_id IN  beneficiaries.beneficiary_id%TYPE,
        p_result         OUT SYS_REFCURSOR
    );

    ----------------------------------------------------------------------------
    -- Returns all beneficiary registrations belonging to one customer.
    ----------------------------------------------------------------------------
    PROCEDURE get_customer_beneficiaries (
        p_customer_id IN  beneficiaries.customer_id%TYPE,
        p_result      OUT SYS_REFCURSOR
    );
END pkg_beneficiary_management;
