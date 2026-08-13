-- ============================================================================
-- Package Specification: PKG_ERROR_LOG
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Defines the public interface used to record application and database
--   errors in ERROR_LOGS.
--
-- Responsibilities
--   * Record Oracle error codes and messages
--   * Preserve stack, backtrace, call-stack, and session diagnostics
--   * Store optional entity and business context
--
-- Transaction Policy
--   * Error logging uses an autonomous transaction.
--   * Log records are committed independently of the caller's transaction.
-- ============================================================================

create or replace PACKAGE pkg_error_log AS

    PROCEDURE log_error (
        p_operation_name IN VARCHAR2,
        p_entity_name    IN VARCHAR2 DEFAULT NULL,
        p_entity_id      IN VARCHAR2 DEFAULT NULL,
        p_context_data   IN CLOB     DEFAULT NULL,
        p_severity       IN VARCHAR2 DEFAULT 'ERROR'
    );

END pkg_error_log;
