-- ============================================================================
-- Package Specification: PKG_LOG_MAINTENANCE
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Defines the public interface for operational log monitoring and retention
--   maintenance.
--
-- Responsibilities
--   * Return summary statistics for audit and error logs
--   * Purge historical audit records in controlled batches
--   * Purge historical error records in controlled batches
--   * Report deleted and failed row counts to the caller
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Purge operations participate in the caller's transaction.
--
-- Dependencies
--   * AUDIT_LOGS
--   * ERROR_LOGS
--   * PKG_AUDIT
--   * PKG_ERROR_LOG
-- ============================================================================

create or replace PACKAGE pkg_log_maintenance AS

    ----------------------------------------------------------------------------
    -- Returns one summary row for AUDIT_LOGS and one for ERROR_LOGS.
    ----------------------------------------------------------------------------
    PROCEDURE get_log_summary (
        p_result OUT SYS_REFCURSOR
    );

    ----------------------------------------------------------------------------
    -- Deletes AUDIT_LOGS rows older than P_RETENTION_DAYS in controlled batches.
    ----------------------------------------------------------------------------
    PROCEDURE purge_audit_logs (
        p_retention_days IN  PLS_INTEGER DEFAULT 90,
        p_batch_size     IN  PLS_INTEGER DEFAULT 1000,
        p_deleted_count  OUT PLS_INTEGER,
        p_failed_count   OUT PLS_INTEGER
    );

    ----------------------------------------------------------------------------
    -- Deletes ERROR_LOGS rows older than P_RETENTION_DAYS in controlled batches.
    ----------------------------------------------------------------------------
    PROCEDURE purge_error_logs (
        p_retention_days IN  PLS_INTEGER DEFAULT 90,
        p_batch_size     IN  PLS_INTEGER DEFAULT 1000,
        p_deleted_count  OUT PLS_INTEGER,
        p_failed_count   OUT PLS_INTEGER
    );

END pkg_log_maintenance;
