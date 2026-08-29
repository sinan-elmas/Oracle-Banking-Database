-- ============================================================================
-- Package Body         : PKG_ERROR_LOG
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Implements centralized error logging for PL/SQL modules.
--
-- Implementation Notes
--   * Captures the current Oracle error code and message.
--   * Stores formatted error, backtrace, and call-stack information.
--   * Derives the calling module and procedure through UTL_CALL_STACK.
--   * Normalizes severity to INFO, WARN, ERROR, or FATAL.
--   * Uses an autonomous transaction so error records remain available even
--     when the caller rolls back its business transaction.
--
-- Transaction Policy
--   * Error logging uses an autonomous transaction.
--   * Each log record is committed independently of the caller's transaction.
--
-- Dependency
--   * ERROR_LOGS
-- ============================================================================

create or replace PACKAGE BODY pkg_error_log AS

    PROCEDURE log_error (
        p_operation_name IN VARCHAR2,
        p_entity_name    IN VARCHAR2 DEFAULT NULL,
        p_entity_id      IN VARCHAR2 DEFAULT NULL,
        p_context_data   IN CLOB     DEFAULT NULL,
        p_severity       IN VARCHAR2 DEFAULT 'ERROR'
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        l_error_code      NUMBER;
        l_error_message   VARCHAR2(4000);
        l_error_stack     CLOB;
        l_error_backtrace CLOB;
        l_call_stack      CLOB;
        l_caller_path     VARCHAR2(4000);
        l_module_name     VARCHAR2(128);
        l_procedure_name  VARCHAR2(128);
        l_transaction_id  VARCHAR2(100);
        l_severity        VARCHAR2(10);
    BEGIN
        l_error_code      := SQLCODE;
        l_error_message   := SQLERRM;
        l_error_stack     := DBMS_UTILITY.FORMAT_ERROR_STACK;
        l_error_backtrace := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        l_call_stack      := DBMS_UTILITY.FORMAT_CALL_STACK;

        l_severity := UPPER(TRIM(NVL(p_severity, 'ERROR')));

        IF l_severity NOT IN ('INFO', 'WARN', 'ERROR', 'FATAL') THEN
            l_severity := 'ERROR';
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

        INSERT INTO error_logs (
            logged_at,
            severity,
            error_code,
            error_message,
            error_stack,
            error_backtrace,
            call_stack,
            module_name,
            procedure_name,
            operation_name,
            entity_name,
            entity_id,
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
            l_severity,
            l_error_code,
            l_error_message,
            l_error_stack,
            l_error_backtrace,
            l_call_stack,
            l_module_name,
            l_procedure_name,
            p_operation_name,
            p_entity_name,
            p_entity_id,
            p_context_data,
            SYS_CONTEXT('USERENV', 'SESSION_USER'),
            SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'),
            SYS_CONTEXT('USERENV', 'HOST'),
            SYS_CONTEXT('USERENV', 'OS_USER'),
            TO_NUMBER(SYS_CONTEXT('USERENV', 'SESSIONID')),
            l_transaction_id
        );

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END log_error;

END pkg_error_log;
