-- ============================================================================
-- Script Name : 02_PLSQL_SQL_Activity_Review.sql
-- Module      : 05_Performance / 05_PLSQL_Performance_Review
-- Project     : Oracle Banking Database
-- Database    : Oracle AI Database 26ai Enterprise Edition
-- Version     : 23.26.1.0.0
-- Schema      : BANKING_DB
-- Tool        : Oracle SQL Developer
--
-- Purpose
--   Reviews SQL activity currently retained in the shared SQL area for the
--   project's PL/SQL packages and triggers.
--
-- Data Source
--   * V$SQL
--   * USER_OBJECTS
--
-- Important Notes
--   * V$SQL is a current shared-pool snapshot, not a permanent workload
--     repository.
--   * Missing rows do not prove that an object has never executed.
--   * Metrics are cumulative for each captured child cursor.
--   * This report is read-only and does not execute application code.
--
-- Required Privilege
--   SELECT on V_$SQL (or equivalent access to V$SQL)
--
-- Safety
--   Read-only. No DDL, DML, cursor flush, statistics collection, or package
--   execution is performed.
-- ============================================================================

SET PAGESIZE 500
SET LINESIZE 260
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON
SET NUMWIDTH 20

COLUMN schema_name          FORMAT A20
COLUMN report_time          FORMAT A22
COLUMN object_name          FORMAT A40
COLUMN object_type          FORMAT A14
COLUMN sql_id               FORMAT A13
COLUMN child_number         FORMAT 999
COLUMN plan_hash_value      FORMAT 9999999999
COLUMN program_line#        FORMAT 999999
COLUMN module               FORMAT A25
COLUMN action               FORMAT A25
COLUMN last_active_time     FORMAT A22
COLUMN sql_text             FORMAT A100 WORD_WRAPPED
COLUMN capture_status       FORMAT A18

COLUMN project_runtime_objects  FORMAT 999,999
COLUMN captured_runtime_objects FORMAT 999,999
COLUMN distinct_sql_ids         FORMAT 999,999
COLUMN child_cursors            FORMAT 999,999
COLUMN executions               FORMAT 999,999,999,999
COLUMN parse_calls              FORMAT 999,999,999,999
COLUMN loads                    FORMAT 999,999,999
COLUMN invalidations            FORMAT 999,999,999
COLUMN rows_processed           FORMAT 999,999,999,999
COLUMN buffer_gets              FORMAT 999,999,999,999
COLUMN disk_reads               FORMAT 999,999,999,999

COLUMN elapsed_seconds      FORMAT 999,999,990.000
COLUMN cpu_seconds          FORMAT 999,999,990.000
COLUMN plsql_seconds        FORMAT 999,999,990.000
COLUMN user_io_seconds      FORMAT 999,999,990.000
COLUMN application_seconds FORMAT 999,999,990.000
COLUMN concurrency_seconds FORMAT 999,999,990.000

COLUMN elapsed_ms_per_exec  FORMAT 999,999,990.000
COLUMN cpu_ms_per_exec      FORMAT 999,999,990.000
COLUMN buffer_gets_per_exec FORMAT 999,999,999.00
COLUMN disk_reads_per_exec  FORMAT 999,999,999.00
COLUMN rows_per_exec        FORMAT 999,999,999.00
COLUMN parses_per_exec      FORMAT 999,999,999.000

PROMPT
PROMPT ================================================================================
PROMPT PL/SQL SQL ACTIVITY REVIEW - CAPTURE SCOPE
PROMPT ================================================================================
PROMPT

SELECT
    USER AS schema_name,
    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time
FROM dual;

PROMPT
PROMPT ================================================================================
PROMPT SHARED SQL AREA COVERAGE SUMMARY
PROMPT ================================================================================
PROMPT

WITH project_objects AS
(
    SELECT
        object_id,
        object_name,
        object_type
    FROM user_objects
    WHERE object_name IN (
        'PKG_ERROR_LOG',
        'PKG_AUDIT',
        'PKG_CUSTOMER_MANAGEMENT',
        'PKG_ACCOUNT_MANAGEMENT',
        'PKG_BENEFICIARY_MANAGEMENT',
        'PKG_CARD_MANAGEMENT',
        'PKG_EXCHANGE_RATE_MANAGEMENT',
        'PKG_TRANSACTION_MANAGEMENT',
        'PKG_LOG_MAINTENANCE',
        'TRG_CUSTOMERS_NO_DELETE',
        'TRG_ACCOUNTS_NO_DELETE',
        'TRG_TRANSACTIONS_NO_DELETE',
        'TRG_BRANCHES_AUDIT',
        'TRG_EXCHANGE_RATES_AUDIT',
        'TRG_TRANSACTION_STATUS_HISTORY',
        'TRG_SCHEMA_DDL_AUDIT'
    )
      AND object_type IN (
          'PACKAGE BODY',
          'TRIGGER'
      )
),
captured_sql AS
(
    SELECT
        obj.object_name,
        obj.object_type,
        sqlarea.sql_id,
        sqlarea.child_number
    FROM project_objects obj
    JOIN v$sql sqlarea
      ON sqlarea.program_id = obj.object_id
    WHERE sqlarea.parsing_schema_name = USER
),
project_totals AS
(
    SELECT COUNT(*) AS project_runtime_objects
    FROM project_objects
),
capture_totals AS
(
    SELECT
        COUNT(DISTINCT object_name || ':' || object_type)
            AS captured_runtime_objects,
        COUNT(DISTINCT sql_id)
            AS distinct_sql_ids,
        COUNT(*)
            AS child_cursors
    FROM captured_sql
)
SELECT
    p.project_runtime_objects,
    c.captured_runtime_objects,
    c.distinct_sql_ids,
    c.child_cursors
FROM project_totals p
CROSS JOIN capture_totals c;

PROMPT
PROMPT ================================================================================
PROMPT ACTIVITY AGGREGATED BY PL/SQL OBJECT
PROMPT ================================================================================
PROMPT

WITH project_objects AS
(
    SELECT
        object_id,
        object_name,
        object_type
    FROM user_objects
    WHERE object_name IN (
        'PKG_ERROR_LOG',
        'PKG_AUDIT',
        'PKG_CUSTOMER_MANAGEMENT',
        'PKG_ACCOUNT_MANAGEMENT',
        'PKG_BENEFICIARY_MANAGEMENT',
        'PKG_CARD_MANAGEMENT',
        'PKG_EXCHANGE_RATE_MANAGEMENT',
        'PKG_TRANSACTION_MANAGEMENT',
        'PKG_LOG_MAINTENANCE',
        'TRG_CUSTOMERS_NO_DELETE',
        'TRG_ACCOUNTS_NO_DELETE',
        'TRG_TRANSACTIONS_NO_DELETE',
        'TRG_BRANCHES_AUDIT',
        'TRG_EXCHANGE_RATES_AUDIT',
        'TRG_TRANSACTION_STATUS_HISTORY',
        'TRG_SCHEMA_DDL_AUDIT'
    )
      AND object_type IN (
          'PACKAGE BODY',
          'TRIGGER'
      )
),
object_activity AS
(
    SELECT
        obj.object_name,
        obj.object_type,
        COUNT(sqlarea.sql_id) AS child_cursors,
        COUNT(DISTINCT sqlarea.sql_id) AS distinct_sql_ids,
        SUM(sqlarea.executions) AS executions,
        SUM(sqlarea.parse_calls) AS parse_calls,
        SUM(sqlarea.loads) AS loads,
        SUM(sqlarea.invalidations) AS invalidations,
        SUM(sqlarea.rows_processed) AS rows_processed,
        SUM(sqlarea.buffer_gets) AS buffer_gets,
        SUM(sqlarea.disk_reads) AS disk_reads,
        SUM(sqlarea.elapsed_time) / 1000000 AS elapsed_seconds,
        SUM(sqlarea.cpu_time) / 1000000 AS cpu_seconds,
        SUM(sqlarea.plsql_exec_time) / 1000000 AS plsql_seconds,
        SUM(sqlarea.user_io_wait_time) / 1000000 AS user_io_seconds,
        SUM(sqlarea.application_wait_time) / 1000000 AS application_seconds,
        SUM(sqlarea.concurrency_wait_time) / 1000000 AS concurrency_seconds,
        MAX(sqlarea.last_active_time) AS last_active_time
    FROM project_objects obj
    LEFT JOIN v$sql sqlarea
      ON sqlarea.program_id = obj.object_id
     AND sqlarea.parsing_schema_name = USER
    GROUP BY
        obj.object_name,
        obj.object_type
)
SELECT
    object_name,
    object_type,
    child_cursors,
    distinct_sql_ids,
    NVL(executions, 0) AS executions,
    NVL(parse_calls, 0) AS parse_calls,
    NVL(loads, 0) AS loads,
    NVL(invalidations, 0) AS invalidations,
    NVL(rows_processed, 0) AS rows_processed,
    NVL(buffer_gets, 0) AS buffer_gets,
    NVL(disk_reads, 0) AS disk_reads,
    NVL(elapsed_seconds, 0) AS elapsed_seconds,
    NVL(cpu_seconds, 0) AS cpu_seconds,
    NVL(plsql_seconds, 0) AS plsql_seconds,
    NVL(user_io_seconds, 0) AS user_io_seconds,
    NVL(application_seconds, 0) AS application_seconds,
    NVL(concurrency_seconds, 0) AS concurrency_seconds,
    TO_CHAR(
        last_active_time,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS last_active_time,
    CASE
        WHEN distinct_sql_ids = 0
            THEN 'NOT CAPTURED'
        WHEN NVL(executions, 0) = 0
            THEN 'NO EXECUTIONS'
        ELSE
            'CAPTURED'
    END AS capture_status
FROM object_activity
ORDER BY
    NVL(elapsed_seconds, 0) DESC,
    NVL(buffer_gets, 0) DESC,
    object_name;

PROMPT
PROMPT ================================================================================
PROMPT TOP CAPTURED STATEMENTS BY TOTAL ELAPSED TIME
PROMPT ================================================================================
PROMPT

WITH project_objects AS
(
    SELECT
        object_id,
        object_name,
        object_type
    FROM user_objects
    WHERE object_name IN (
        'PKG_ERROR_LOG',
        'PKG_AUDIT',
        'PKG_CUSTOMER_MANAGEMENT',
        'PKG_ACCOUNT_MANAGEMENT',
        'PKG_BENEFICIARY_MANAGEMENT',
        'PKG_CARD_MANAGEMENT',
        'PKG_EXCHANGE_RATE_MANAGEMENT',
        'PKG_TRANSACTION_MANAGEMENT',
        'PKG_LOG_MAINTENANCE',
        'TRG_CUSTOMERS_NO_DELETE',
        'TRG_ACCOUNTS_NO_DELETE',
        'TRG_TRANSACTIONS_NO_DELETE',
        'TRG_BRANCHES_AUDIT',
        'TRG_EXCHANGE_RATES_AUDIT',
        'TRG_TRANSACTION_STATUS_HISTORY',
        'TRG_SCHEMA_DDL_AUDIT'
    )
      AND object_type IN (
          'PACKAGE BODY',
          'TRIGGER'
      )
),
statement_activity AS
(
    SELECT
        obj.object_name,
        obj.object_type,
        sqlarea.sql_id,
        sqlarea.child_number,
        sqlarea.plan_hash_value,
        sqlarea.program_line#,
        sqlarea.executions,
        sqlarea.parse_calls,
        sqlarea.loads,
        sqlarea.invalidations,
        sqlarea.rows_processed,
        sqlarea.buffer_gets,
        sqlarea.disk_reads,
        sqlarea.elapsed_time / 1000000 AS elapsed_seconds,
        sqlarea.cpu_time / 1000000 AS cpu_seconds,
        sqlarea.plsql_exec_time / 1000000 AS plsql_seconds,
        CASE
            WHEN sqlarea.executions > 0
            THEN sqlarea.elapsed_time / sqlarea.executions / 1000
        END AS elapsed_ms_per_exec,
        CASE
            WHEN sqlarea.executions > 0
            THEN sqlarea.cpu_time / sqlarea.executions / 1000
        END AS cpu_ms_per_exec,
        CASE
            WHEN sqlarea.executions > 0
            THEN sqlarea.buffer_gets / sqlarea.executions
        END AS buffer_gets_per_exec,
        CASE
            WHEN sqlarea.executions > 0
            THEN sqlarea.disk_reads / sqlarea.executions
        END AS disk_reads_per_exec,
        CASE
            WHEN sqlarea.executions > 0
            THEN sqlarea.rows_processed / sqlarea.executions
        END AS rows_per_exec,
        CASE
            WHEN sqlarea.executions > 0
            THEN sqlarea.parse_calls / sqlarea.executions
        END AS parses_per_exec,
        sqlarea.module,
        sqlarea.action,
        sqlarea.last_active_time,
        REGEXP_REPLACE(
            SUBSTR(sqlarea.sql_text, 1, 1000),
            '[[:space:]]+',
            ' '
        ) AS sql_text
    FROM project_objects obj
    JOIN v$sql sqlarea
      ON sqlarea.program_id = obj.object_id
    WHERE sqlarea.parsing_schema_name = USER
)
SELECT *
FROM
(
    SELECT
        object_name,
        object_type,
        sql_id,
        child_number,
        plan_hash_value,
        program_line#,
        executions,
        parse_calls,
        loads,
        invalidations,
        rows_processed,
        buffer_gets,
        disk_reads,
        elapsed_seconds,
        cpu_seconds,
        plsql_seconds,
        elapsed_ms_per_exec,
        cpu_ms_per_exec,
        buffer_gets_per_exec,
        disk_reads_per_exec,
        rows_per_exec,
        parses_per_exec,
        module,
        action,
        TO_CHAR(
            last_active_time,
            'DD-MON-YYYY HH24:MI:SS'
        ) AS last_active_time,
        sql_text
    FROM statement_activity
    ORDER BY
        elapsed_seconds DESC,
        buffer_gets DESC,
        sql_id,
        child_number
)
WHERE ROWNUM <= 25;

PROMPT
PROMPT ================================================================================
PROMPT TOP CAPTURED STATEMENTS BY BUFFER GETS
PROMPT ================================================================================
PROMPT

WITH project_objects AS
(
    SELECT
        object_id,
        object_name,
        object_type
    FROM user_objects
    WHERE object_name IN (
        'PKG_ERROR_LOG',
        'PKG_AUDIT',
        'PKG_CUSTOMER_MANAGEMENT',
        'PKG_ACCOUNT_MANAGEMENT',
        'PKG_BENEFICIARY_MANAGEMENT',
        'PKG_CARD_MANAGEMENT',
        'PKG_EXCHANGE_RATE_MANAGEMENT',
        'PKG_TRANSACTION_MANAGEMENT',
        'PKG_LOG_MAINTENANCE',
        'TRG_CUSTOMERS_NO_DELETE',
        'TRG_ACCOUNTS_NO_DELETE',
        'TRG_TRANSACTIONS_NO_DELETE',
        'TRG_BRANCHES_AUDIT',
        'TRG_EXCHANGE_RATES_AUDIT',
        'TRG_TRANSACTION_STATUS_HISTORY',
        'TRG_SCHEMA_DDL_AUDIT'
    )
      AND object_type IN (
          'PACKAGE BODY',
          'TRIGGER'
      )
),
statement_activity AS
(
    SELECT
        obj.object_name,
        obj.object_type,
        sqlarea.sql_id,
        sqlarea.child_number,
        sqlarea.plan_hash_value,
        sqlarea.program_line#,
        sqlarea.executions,
        sqlarea.parse_calls,
        sqlarea.rows_processed,
        sqlarea.buffer_gets,
        sqlarea.disk_reads,
        sqlarea.elapsed_time / 1000000 AS elapsed_seconds,
        sqlarea.cpu_time / 1000000 AS cpu_seconds,
        CASE
            WHEN sqlarea.executions > 0
            THEN sqlarea.elapsed_time / sqlarea.executions / 1000
        END AS elapsed_ms_per_exec,
        CASE
            WHEN sqlarea.executions > 0
            THEN sqlarea.buffer_gets / sqlarea.executions
        END AS buffer_gets_per_exec,
        CASE
            WHEN sqlarea.executions > 0
            THEN sqlarea.disk_reads / sqlarea.executions
        END AS disk_reads_per_exec,
        CASE
            WHEN sqlarea.executions > 0
            THEN sqlarea.rows_processed / sqlarea.executions
        END AS rows_per_exec,
        sqlarea.last_active_time,
        REGEXP_REPLACE(
            SUBSTR(sqlarea.sql_text, 1, 1000),
            '[[:space:]]+',
            ' '
        ) AS sql_text
    FROM project_objects obj
    JOIN v$sql sqlarea
      ON sqlarea.program_id = obj.object_id
    WHERE sqlarea.parsing_schema_name = USER
)
SELECT *
FROM
(
    SELECT
        object_name,
        object_type,
        sql_id,
        child_number,
        plan_hash_value,
        program_line#,
        executions,
        parse_calls,
        rows_processed,
        buffer_gets,
        disk_reads,
        elapsed_seconds,
        cpu_seconds,
        elapsed_ms_per_exec,
        buffer_gets_per_exec,
        disk_reads_per_exec,
        rows_per_exec,
        TO_CHAR(
            last_active_time,
            'DD-MON-YYYY HH24:MI:SS'
        ) AS last_active_time,
        sql_text
    FROM statement_activity
    ORDER BY
        buffer_gets DESC,
        elapsed_seconds DESC,
        sql_id,
        child_number
)
WHERE ROWNUM <= 25;

PROMPT
PROMPT ================================================================================
PROMPT CAPTURED STATEMENTS WITH LOADS OR INVALIDATIONS
PROMPT ================================================================================
PROMPT

WITH project_objects AS
(
    SELECT
        object_id,
        object_name,
        object_type
    FROM user_objects
    WHERE object_name IN (
        'PKG_ERROR_LOG',
        'PKG_AUDIT',
        'PKG_CUSTOMER_MANAGEMENT',
        'PKG_ACCOUNT_MANAGEMENT',
        'PKG_BENEFICIARY_MANAGEMENT',
        'PKG_CARD_MANAGEMENT',
        'PKG_EXCHANGE_RATE_MANAGEMENT',
        'PKG_TRANSACTION_MANAGEMENT',
        'PKG_LOG_MAINTENANCE',
        'TRG_CUSTOMERS_NO_DELETE',
        'TRG_ACCOUNTS_NO_DELETE',
        'TRG_TRANSACTIONS_NO_DELETE',
        'TRG_BRANCHES_AUDIT',
        'TRG_EXCHANGE_RATES_AUDIT',
        'TRG_TRANSACTION_STATUS_HISTORY',
        'TRG_SCHEMA_DDL_AUDIT'
    )
      AND object_type IN (
          'PACKAGE BODY',
          'TRIGGER'
      )
)
SELECT
    obj.object_name,
    obj.object_type,
    sqlarea.sql_id,
    sqlarea.child_number,
    sqlarea.program_line#,
    sqlarea.executions,
    sqlarea.parse_calls,
    sqlarea.loads,
    sqlarea.invalidations,
    TO_CHAR(
        sqlarea.last_active_time,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS last_active_time,
    REGEXP_REPLACE(
        SUBSTR(sqlarea.sql_text, 1, 1000),
        '[[:space:]]+',
        ' '
    ) AS sql_text
FROM project_objects obj
JOIN v$sql sqlarea
  ON sqlarea.program_id = obj.object_id
WHERE sqlarea.parsing_schema_name = USER
  AND (
      sqlarea.loads > 1
      OR sqlarea.invalidations > 0
  )
ORDER BY
    sqlarea.invalidations DESC,
    sqlarea.loads DESC,
    obj.object_name,
    sqlarea.sql_id,
    sqlarea.child_number;

PROMPT
PROMPT ================================================================================
PROMPT PROJECT PL/SQL OBJECTS WITHOUT CURRENT V$SQL CAPTURE
PROMPT ================================================================================
PROMPT

WITH project_objects AS
(
    SELECT
        object_id,
        object_name,
        object_type
    FROM user_objects
    WHERE object_name IN (
        'PKG_ERROR_LOG',
        'PKG_AUDIT',
        'PKG_CUSTOMER_MANAGEMENT',
        'PKG_ACCOUNT_MANAGEMENT',
        'PKG_BENEFICIARY_MANAGEMENT',
        'PKG_CARD_MANAGEMENT',
        'PKG_EXCHANGE_RATE_MANAGEMENT',
        'PKG_TRANSACTION_MANAGEMENT',
        'PKG_LOG_MAINTENANCE',
        'TRG_CUSTOMERS_NO_DELETE',
        'TRG_ACCOUNTS_NO_DELETE',
        'TRG_TRANSACTIONS_NO_DELETE',
        'TRG_BRANCHES_AUDIT',
        'TRG_EXCHANGE_RATES_AUDIT',
        'TRG_TRANSACTION_STATUS_HISTORY',
        'TRG_SCHEMA_DDL_AUDIT'
    )
      AND object_type IN (
          'PACKAGE BODY',
          'TRIGGER'
      )
)
SELECT
    obj.object_name,
    obj.object_type,
    'NOT CAPTURED' AS capture_status
FROM project_objects obj
WHERE NOT EXISTS
(
    SELECT 1
    FROM v$sql sqlarea
    WHERE sqlarea.program_id = obj.object_id
      AND sqlarea.parsing_schema_name = USER
)
ORDER BY
    obj.object_type,
    obj.object_name;

PROMPT
PROMPT ================================================================================
PROMPT INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT V$SQL is a current shared-pool snapshot, not a permanent history.
PROMPT NOT CAPTURED means no matching child cursor is currently available.
PROMPT Per-execution values are NULL when EXECUTIONS equals zero.
PROMPT High total cost may reflect high execution frequency rather than a slow call.
PROMPT High per-execution cost requires plan and business-context review.
PROMPT Loads and invalidations require interpretation with DDL and shared-pool history.
PROMPT

PROMPT End of PL/SQL SQL activity review.