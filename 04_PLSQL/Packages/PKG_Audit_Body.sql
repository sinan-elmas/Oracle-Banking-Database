-- ============================================================================
-- Package Body         : PKG_AUDIT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Implements centralized audit logging for business operations.
--
-- Implementation Notes
--   * Validates supported audit action types.
--   * Identifies the calling module and procedure through UTL_CALL_STACK.
--   * Captures entity, operation, session, and transaction context.
--   * Records unexpected logging failures through PKG_ERROR_LOG.
--
-- Supported Actions
--   * INSERT
--   * UPDATE
--   * DELETE
--   * STATUS_CHANGE
--   * BUSINESS_ACTION
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Audit records participate in the caller's transaction.
--
-- Dependencies
--   * AUDIT_LOGS
--   * PKG_ERROR_LOG
-- ============================================================================

create or replace PACKAGE BODY pkg_audit AS

    PROCEDURE log_action (
        p_action_type    IN VARCHAR2,
        p_entity_name    IN VARCHAR2,
        p_entity_id      IN VARCHAR2 DEFAULT NULL,
        p_operation_name IN VARCHAR2 DEFAULT NULL,
        p_old_data       IN CLOB     DEFAULT NULL,
        p_new_data       IN CLOB     DEFAULT NULL,
        p_context_data   IN CLOB     DEFAULT NULL
    ) IS
        l_action_type    VARCHAR2(20);
        l_caller_path    VARCHAR2(4000);
        l_module_name    VARCHAR2(128);
        l_procedure_name VARCHAR2(128);
        l_transaction_id  VARCHAR2(100);
    BEGIN
        l_action_type := UPPER(TRIM(p_action_type));

        IF l_action_type NOT IN (
            'INSERT',
            'UPDATE',
            'DELETE',
            'STATUS_CHANGE',
            'BUSINESS_ACTION'
        ) THEN
            RAISE_APPLICATION_ERROR(
                -20010,
                'Invalid audit action type: ' || p_action_type
            );
        END IF;

        l_caller_path :=
            UTL_CALL_STACK.CONCATENATE_SUBPROGRAM(
                UTL_CALL_STACK.SUBPROGRAM(2)
            );

        l_module_name :=
            REGEXP_SUBSTR(
                l_caller_path,
                '[^.]+',
                1,
                1
            );

        l_procedure_name :=
            REGEXP_SUBSTR(
                l_caller_path,
                '[^.]+',
                1,
                2
            );

        l_transaction_id :=
            DBMS_TRANSACTION.LOCAL_TRANSACTION_ID(FALSE);

        INSERT INTO audit_logs (
            logged_at,
            action_type,
            entity_name,
            entity_id,
            module_name,
            procedure_name,
            operation_name,
            old_data,
            new_data,
            context_data,
            session_user,
            client_identifier,
            host_name,
            os_user,
            session_id,
            transaction_id
        )
        VALUES (
            SYSTIMESTAMP,
            l_action_type,
            UPPER(TRIM(p_entity_name)),
            p_entity_id,
            l_module_name,
            l_procedure_name,
            p_operation_name,
            p_old_data,
            p_new_data,
            p_context_data,
            SYS_CONTEXT('USERENV', 'SESSION_USER'),
            SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
            SYS_CONTEXT('USERENV', 'HOST'),
            SYS_CONTEXT('USERENV', 'OS_USER'),
            TO_NUMBER(SYS_CONTEXT('USERENV', 'SESSIONID')),
            l_transaction_id
        );

    EXCEPTION
        WHEN OTHERS THEN

            pkg_error_log.log_error(
                p_operation_name => 'PKG_AUDIT.LOG_ACTION',
                p_entity_name    => p_entity_name,
                p_entity_id      => p_entity_id,
                p_context_data   => '{"source":"pkg_audit"}',
                p_severity       => 'ERROR'
            );

            RAISE;
    END log_action;

END pkg_audit;
