-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / PL/SQL Tests / Trigger Tests
-- Script       : 04_SCHEMA_DDL_AUDIT_TRIGGER_Test.sql
-- Purpose      : Validate schema-level CREATE, ALTER, and DROP auditing
-- Scope        : TRG_SCHEMA_DDL_AUDIT
-- Safety       : Creates one temporary test table, drops it, and removes only
--                the DDL_AUDIT_LOGS rows generated for that test object
-- Note         : DDL and trigger audit inserts commit independently
-- Environment  : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
SET VERIFY OFF
SET FEEDBACK ON
SET SQLBLANKLINES ON

WHENEVER SQLERROR CONTINUE

PROMPT
PROMPT ================================================================================
PROMPT SCHEMA DDL AUDIT TRIGGER - REGRESSION TEST SUITE
PROMPT ================================================================================
PROMPT

DECLARE
    l_object_name       VARCHAR2(30);
    l_test_started_at   TIMESTAMP := SYSTIMESTAMP;
    l_count             PLS_INTEGER;
    l_pass_count        PLS_INTEGER := 0;
    l_fail_count        PLS_INTEGER := 0;

    l_event_type        ddl_audit_logs.event_type%TYPE;
    l_object_owner      ddl_audit_logs.object_owner%TYPE;
    l_object_type       ddl_audit_logs.object_type%TYPE;
    l_login_user        ddl_audit_logs.login_user%TYPE;
    l_session_user      ddl_audit_logs.session_user%TYPE;
    l_current_schema    ddl_audit_logs.current_schema%TYPE;
    l_event_timestamp   ddl_audit_logs.event_timestamp%TYPE;
    l_sql_text          ddl_audit_logs.sql_text%TYPE;

    PROCEDURE record_result (
        p_test_name IN VARCHAR2,
        p_passed    IN BOOLEAN,
        p_details   IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        IF p_passed THEN
            l_pass_count := l_pass_count + 1;
            DBMS_OUTPUT.PUT_LINE('[PASS] ' || p_test_name);
        ELSE
            l_fail_count := l_fail_count + 1;
            DBMS_OUTPUT.PUT_LINE(
                '[FAIL] ' || p_test_name ||
                CASE
                    WHEN p_details IS NOT NULL THEN ' -> ' || p_details
                END
            );
        END IF;
    END record_result;

    PROCEDURE drop_test_object_safely IS
    BEGIN
        EXECUTE IMMEDIATE
            'DROP TABLE ' || DBMS_ASSERT.SIMPLE_SQL_NAME(l_object_name) ||
            ' PURGE';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -942 THEN
                RAISE;
            END IF;
    END drop_test_object_safely;

    PROCEDURE cleanup_test_logs IS
    BEGIN
        DELETE FROM ddl_audit_logs
         WHERE object_name = l_object_name
           AND event_timestamp >= l_test_started_at - INTERVAL '5' SECOND
           AND event_type IN ('CREATE', 'ALTER', 'DROP');

        COMMIT;
    END cleanup_test_logs;

BEGIN
    ---------------------------------------------------------------------------
    -- Generate a unique, Oracle-safe test object name
    ---------------------------------------------------------------------------
    l_object_name :=
        'T_DDL_AUD_' ||
        TO_CHAR(SYSTIMESTAMP, 'HH24MISSFF6');

    l_object_name := SUBSTR(UPPER(l_object_name), 1, 30);

    ---------------------------------------------------------------------------
    -- A. Trigger health
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- A. TRIGGER HEALTH ---');

    SELECT COUNT(*)
      INTO l_count
      FROM user_triggers
     WHERE trigger_name = 'TRG_SCHEMA_DDL_AUDIT'
       AND status = 'ENABLED';

    record_result(
        'Schema DDL audit trigger is ENABLED',
        l_count = 1,
        'Expected=1, Actual=' || l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM user_objects
     WHERE object_name = 'TRG_SCHEMA_DDL_AUDIT'
       AND object_type = 'TRIGGER'
       AND status = 'VALID';

    record_result(
        'Schema DDL audit trigger is VALID',
        l_count = 1,
        'Expected=1, Actual=' || l_count
    );

    DBMS_OUTPUT.PUT_LINE('Temporary object : ' || l_object_name);

    ---------------------------------------------------------------------------
    -- B. CREATE event
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- B. CREATE EVENT ---');

    EXECUTE IMMEDIATE
        'CREATE TABLE ' || DBMS_ASSERT.SIMPLE_SQL_NAME(l_object_name) ||
        ' (id NUMBER PRIMARY KEY, note_text VARCHAR2(100))';

    SELECT COUNT(*)
      INTO l_count
      FROM user_tables
     WHERE table_name = l_object_name;

    record_result(
        'Temporary test table is created',
        l_count = 1,
        'Expected=1, Actual=' || l_count
    );

    SELECT event_type,
           object_owner,
           object_type,
           login_user,
           session_user,
           current_schema,
           event_timestamp,
           sql_text
      INTO l_event_type,
           l_object_owner,
           l_object_type,
           l_login_user,
           l_session_user,
           l_current_schema,
           l_event_timestamp,
           l_sql_text
      FROM (
            SELECT event_type,
                   object_owner,
                   object_type,
                   login_user,
                   session_user,
                   current_schema,
                   event_timestamp,
                   sql_text
              FROM ddl_audit_logs
             WHERE object_name = l_object_name
               AND event_type = 'CREATE'
               AND event_timestamp >=
                   l_test_started_at - INTERVAL '5' SECOND
             ORDER BY event_timestamp DESC
           )
     WHERE ROWNUM = 1;

    record_result(
        'CREATE event is written to DDL_AUDIT_LOGS',
        l_event_type = 'CREATE',
        'Actual event=' || NVL(l_event_type, 'NULL')
    );

    record_result(
        'CREATE audit stores object owner and type',
        l_object_owner = USER
        AND l_object_type = 'TABLE',
        'Owner=' || NVL(l_object_owner, 'NULL') ||
        ', Type=' || NVL(l_object_type, 'NULL')
    );

    record_result(
        'CREATE audit stores session identity',
        l_login_user = USER
        AND l_session_user = USER
        AND l_current_schema = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
        'Login=' || NVL(l_login_user, 'NULL') ||
        ', Session=' || NVL(l_session_user, 'NULL') ||
        ', Schema=' || NVL(l_current_schema, 'NULL')
    );

    record_result(
        'CREATE audit stores event timestamp and SQL text',
        l_event_timestamp IS NOT NULL
        AND l_sql_text IS NOT NULL
        AND INSTR(UPPER(l_sql_text), 'CREATE TABLE') > 0
        AND INSTR(UPPER(l_sql_text), l_object_name) > 0,
        'SQL_TEXT=' || NVL(DBMS_LOB.SUBSTR(l_sql_text, 500, 1), 'NULL')
    );

    ---------------------------------------------------------------------------
    -- C. ALTER event
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- C. ALTER EVENT ---');

    EXECUTE IMMEDIATE
        'ALTER TABLE ' || DBMS_ASSERT.SIMPLE_SQL_NAME(l_object_name) ||
        ' ADD created_at TIMESTAMP';

    SELECT COUNT(*)
      INTO l_count
      FROM user_tab_columns
     WHERE table_name = l_object_name
       AND column_name = 'CREATED_AT';

    record_result(
        'ALTER TABLE adds the test column',
        l_count = 1,
        'Expected=1, Actual=' || l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM ddl_audit_logs
     WHERE object_name = l_object_name
       AND event_type = 'ALTER'
       AND object_type = 'TABLE'
       AND event_timestamp >=
           l_test_started_at - INTERVAL '5' SECOND
       AND INSTR(UPPER(sql_text), 'ALTER TABLE') > 0;

    record_result(
        'ALTER event is written to DDL_AUDIT_LOGS',
        l_count = 1,
        'Expected=1, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- D. DROP event
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- D. DROP EVENT ---');

    EXECUTE IMMEDIATE
        'DROP TABLE ' || DBMS_ASSERT.SIMPLE_SQL_NAME(l_object_name) ||
        ' PURGE';

    SELECT COUNT(*)
      INTO l_count
      FROM user_tables
     WHERE table_name = l_object_name;

    record_result(
        'Temporary test table is dropped',
        l_count = 0,
        'Expected=0, Actual=' || l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM ddl_audit_logs
     WHERE object_name = l_object_name
       AND event_type = 'DROP'
       AND object_type = 'TABLE'
       AND event_timestamp >=
           l_test_started_at - INTERVAL '5' SECOND
       AND INSTR(UPPER(sql_text), 'DROP TABLE') > 0;

    record_result(
        'DROP event is written to DDL_AUDIT_LOGS',
        l_count = 1,
        'Expected=1, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- E. Complete event set and autonomous behavior
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '--- E. COMPLETE EVENT SET AND AUTONOMOUS BEHAVIOR ---'
    );

    SELECT COUNT(*)
      INTO l_count
      FROM ddl_audit_logs
     WHERE object_name = l_object_name
       AND event_type IN ('CREATE', 'ALTER', 'DROP')
       AND event_timestamp >=
           l_test_started_at - INTERVAL '5' SECOND;

    record_result(
        'Exactly three test DDL events are retained',
        l_count = 3,
        'Expected=3, Actual=' || l_count
    );

    ROLLBACK;

    SELECT COUNT(*)
      INTO l_count
      FROM ddl_audit_logs
     WHERE object_name = l_object_name
       AND event_type IN ('CREATE', 'ALTER', 'DROP')
       AND event_timestamp >=
           l_test_started_at - INTERVAL '5' SECOND;

    record_result(
        'DDL audit rows survive caller ROLLBACK',
        l_count = 3,
        'Expected=3, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- F. Targeted cleanup
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- F. TARGETED CLEANUP ---');

    cleanup_test_logs;

    SELECT COUNT(*)
      INTO l_count
      FROM ddl_audit_logs
     WHERE object_name = l_object_name
       AND event_type IN ('CREATE', 'ALTER', 'DROP')
       AND event_timestamp >=
           l_test_started_at - INTERVAL '5' SECOND;

    record_result(
        'Test-generated DDL audit rows are removed',
        l_count = 0,
        'Expected=0, Actual=' || l_count
    );

    SELECT COUNT(*)
      INTO l_count
      FROM user_tables
     WHERE table_name = l_object_name;

    record_result(
        'No temporary test table remains',
        l_count = 0,
        'Expected=0, Actual=' || l_count
    );

    ---------------------------------------------------------------------------
    -- Final summary
    ---------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) ||
        '================================================================================'
    );
    DBMS_OUTPUT.PUT_LINE('SCHEMA DDL AUDIT TRIGGER TEST SUMMARY');
    DBMS_OUTPUT.PUT_LINE(
        'PASSED=' || l_pass_count ||
        ' FAILED=' || l_fail_count ||
        ' TOTAL=' || (l_pass_count + l_fail_count)
    );

    IF l_fail_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=PASS');
    ELSE
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=FAIL');
    END IF;

    DBMS_OUTPUT.PUT_LINE(
        '================================================================================'
    );

EXCEPTION
    WHEN OTHERS THEN
        BEGIN
            drop_test_object_safely;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        BEGIN
            cleanup_test_logs;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        l_fail_count := l_fail_count + 1;

        DBMS_OUTPUT.PUT_LINE(
            '[FAIL] Unexpected suite-level error -> SQLCODE=' ||
            SQLCODE || ', SQLERRM=' || SQLERRM
        );
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        DBMS_OUTPUT.PUT_LINE(
            'PASSED=' || l_pass_count ||
            ' FAILED=' || l_fail_count ||
            ' TOTAL=' || (l_pass_count + l_fail_count)
        );
        DBMS_OUTPUT.PUT_LINE('OVERALL_STATUS=FAIL');
END;
/

PROMPT
PROMPT ================================================================================
PROMPT TRIGGER COMPILATION ERROR CHECK
PROMPT ================================================================================
PROMPT

COLUMN name     FORMAT A35
COLUMN type     FORMAT A20
COLUMN line     FORMAT 999,999
COLUMN position FORMAT 999,999
COLUMN text     FORMAT A120

SELECT
    name,
    type,
    line,
    position,
    text
FROM user_errors
WHERE name = 'TRG_SCHEMA_DDL_AUDIT'
ORDER BY sequence;