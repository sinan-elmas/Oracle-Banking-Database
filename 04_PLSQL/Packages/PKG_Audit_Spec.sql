-- ============================================================================
-- Package Specification: PKG_AUDIT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Defines the public interface for recording business audit events.
--
-- Responsibilities
--   * Record data changes and business actions
--   * Store optional before-and-after values
--   * Preserve entity, operation, and session context
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Audit records participate in the caller's transaction.
--
-- Dependency
--   * AUDIT_LOGS
-- ============================================================================

create or replace PACKAGE pkg_audit AS

    PROCEDURE log_action (
        p_action_type    IN VARCHAR2,
        p_entity_name    IN VARCHAR2,
        p_entity_id      IN VARCHAR2 DEFAULT NULL,
        p_operation_name IN VARCHAR2 DEFAULT NULL,
        p_old_data       IN CLOB     DEFAULT NULL,
        p_new_data       IN CLOB     DEFAULT NULL,
        p_context_data   IN CLOB     DEFAULT NULL
    );

END pkg_audit;
