-- ============================================================================
-- Trigger : TRG_SCHEMA_DDL_AUDIT
-- Project : Oracle Banking Database
-- Database: Oracle AI Database 26ai Enterprise Edition
-- Version : 23.26.1.0.0
-- Schema  : BANKING_DB
--
-- Purpose
--   Records schema-level CREATE, ALTER, and DROP events.
--
-- Behavior
--   Captures object metadata, session context, event time, and the triggering
--   SQL text in DDL_AUDIT_LOGS.
--
-- Timing and Event
--   AFTER CREATE OR ALTER OR DROP ON SCHEMA
--
-- Transaction Policy
--   * Uses an autonomous transaction.
--   * Audit records are committed independently of the triggering DDL.
--
-- Dependency
--   * DDL_AUDIT_LOGS
-- ============================================================================

CREATE OR REPLACE TRIGGER trg_schema_ddl_audit 
AFTER CREATE OR ALTER OR DROP ON SCHEMA
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;

    l_sql_parts  ora_name_list_t;
    l_part_count PLS_INTEGER;
    l_sql_text   VARCHAR2(32767);
BEGIN
    l_part_count := ORA_SQL_TXT(l_sql_parts);

    IF l_part_count IS NOT NULL THEN
        FOR i IN 1 .. l_part_count LOOP
            IF NVL(LENGTH(l_sql_text), 0) + LENGTH(l_sql_parts(i)) <= 32767 THEN
                l_sql_text := l_sql_text || l_sql_parts(i);
            ELSE
                l_sql_text := l_sql_text ||
                              SUBSTR(
                                  l_sql_parts(i),
                                  1,
                                  32767 - NVL(LENGTH(l_sql_text), 0)
                              );
                EXIT;
            END IF;
        END LOOP;
    END IF;

    INSERT INTO ddl_audit_logs (
        event_type,
        object_owner,
        object_name,
        object_type,
        login_user,
        session_user,
        current_schema,
        os_user,
        host_name,
        ip_address,
        module_name,
        event_timestamp,
        sql_text
    )
    VALUES (
        ORA_SYSEVENT,
        ORA_DICT_OBJ_OWNER,
        ORA_DICT_OBJ_NAME,
        ORA_DICT_OBJ_TYPE,
        ORA_LOGIN_USER,
        SYS_CONTEXT('USERENV', 'SESSION_USER'),
        SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
        SYS_CONTEXT('USERENV', 'OS_USER'),
        SYS_CONTEXT('USERENV', 'HOST'),
        SYS_CONTEXT('USERENV', 'IP_ADDRESS'),
        SYS_CONTEXT('USERENV', 'MODULE'),
        SYSTIMESTAMP,
        l_sql_text
    );

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        NULL;
END trg_schema_ddl_audit;

/
