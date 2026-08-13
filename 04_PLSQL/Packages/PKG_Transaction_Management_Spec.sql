-- ============================================================================
-- Package Specification: PKG_TRANSACTION_MANAGEMENT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Defines the public interface for customer account transactions and
--   transaction history retrieval.
--
-- Responsibilities
--   * Transfer funds between eligible accounts
--   * Process deposits and withdrawals
--   * Retrieve transaction details
--   * Return account transaction history
--
-- Business Scope
--   * Transfers are supported only between accounts with the same currency.
--   * Supported transaction channels are validated by operation type.
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Transaction control remains with the calling application or script.
--
-- Dependencies
--   * TRANSACTIONS, ACCOUNTS, TRANSACTION_TYPES, TRANSACTION_CHANNELS
--   * CURRENCIES
--   * PKG_ERROR_LOG
-- ============================================================================

create or replace PACKAGE pkg_transaction_management AS

PROCEDURE transfer_funds(
    p_source_account_id IN  transactions.source_account_id%TYPE,
    p_target_account_id IN  transactions.target_account_id%TYPE,
    p_amount            IN  transactions.amount%TYPE,
    p_channel_id        IN  transactions.channel_id%TYPE,
    p_description       IN  transactions.description%TYPE DEFAULT NULL,
    p_transaction_id    OUT transactions.transaction_id%TYPE,
    p_reference_number  OUT transactions.reference_number%TYPE
);

PROCEDURE deposit_funds(
    p_account_id        IN  accounts.account_id%TYPE,
    p_amount            IN  transactions.amount%TYPE,
    p_channel_id        IN  transactions.channel_id%TYPE,
    p_description       IN  transactions.description%TYPE DEFAULT NULL,
    p_transaction_id    OUT transactions.transaction_id%TYPE,
    p_reference_number  OUT transactions.reference_number%TYPE
);

PROCEDURE withdraw_funds(
    p_account_id        IN  accounts.account_id%TYPE,
    p_amount            IN  transactions.amount%TYPE,
    p_channel_id        IN  transactions.channel_id%TYPE,
    p_description       IN  transactions.description%TYPE DEFAULT NULL,
    p_transaction_id    OUT transactions.transaction_id%TYPE,
    p_reference_number  OUT transactions.reference_number%TYPE
);

PROCEDURE get_transaction_info(
    p_transaction_id IN  transactions.transaction_id%TYPE,
    p_result         OUT SYS_REFCURSOR
);

PROCEDURE get_account_transactions(
    p_account_id IN  accounts.account_id%TYPE,
    p_result     OUT SYS_REFCURSOR
);

END pkg_transaction_management;
