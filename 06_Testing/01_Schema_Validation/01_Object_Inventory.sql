-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Schema Validation
-- Script       : 01_Object_Inventory.sql
-- Purpose      : Inventory schema objects before detailed validation tests
-- Scope        : Current application schema
-- Safety       : Read-only
-- Environment  : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- ============================================================================

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 500
SET LINESIZE 220
SET FEEDBACK ON
SET VERIFY OFF
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

PROMPT
PROMPT ================================================================================
PROMPT SCHEMA OBJECT INVENTORY SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN schema_name   FORMAT A20
COLUMN object_type   FORMAT A28
COLUMN object_count  FORMAT 999,999
COLUMN valid_count   FORMAT 999,999
COLUMN invalid_count FORMAT 999,999
COLUMN report_time   FORMAT A20

SELECT
    USER AS schema_name,
    object_type,
    COUNT(*) AS object_count,

    SUM(
        CASE
            WHEN status = 'VALID' THEN 1
            ELSE 0
        END
    ) AS valid_count,

    SUM(
        CASE
            WHEN status = 'INVALID' THEN 1
            ELSE 0
        END
    ) AS invalid_count,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM user_objects

WHERE object_type IN
      (
          'TABLE',
          'VIEW',
          'SEQUENCE',
          'PACKAGE',
          'PACKAGE BODY',
          'PROCEDURE',
          'FUNCTION',
          'TRIGGER',
          'TYPE',
          'TYPE BODY',
          'SYNONYM'
      )

GROUP BY
    object_type

ORDER BY
    object_type;

PROMPT
PROMPT ================================================================================
PROMPT EXPECTED APPLICATION OBJECT COUNTS
PROMPT ================================================================================
PROMPT

COLUMN object_category FORMAT A36
COLUMN object_count    FORMAT 999,999

SELECT
    'TABLES' AS object_category,
    COUNT(*) AS object_count
FROM user_tables

UNION ALL

SELECT
    'VIEWS',
    COUNT(*)
FROM user_views

UNION ALL

SELECT
    'APPLICATION SEQUENCES',
    COUNT(*)
FROM user_sequences
WHERE sequence_name NOT LIKE 'ISEQ$$#_%' ESCAPE '#'

UNION ALL

SELECT
    'ORACLE-MANAGED IDENTITY SEQUENCES',
    COUNT(*)
FROM user_sequences
WHERE sequence_name LIKE 'ISEQ$$#_%' ESCAPE '#'

UNION ALL

SELECT
    'ALL SEQUENCES',
    COUNT(*)
FROM user_sequences

UNION ALL

SELECT
    'PACKAGES',
    COUNT(*)
FROM user_objects
WHERE object_type = 'PACKAGE'

UNION ALL

SELECT
    'PACKAGE BODIES',
    COUNT(*)
FROM user_objects
WHERE object_type = 'PACKAGE BODY'

UNION ALL

SELECT
    'STANDALONE PROCEDURES',
    COUNT(*)
FROM user_objects
WHERE object_type = 'PROCEDURE'

UNION ALL

SELECT
    'STANDALONE FUNCTIONS',
    COUNT(*)
FROM user_objects
WHERE object_type = 'FUNCTION'

UNION ALL

SELECT
    'TRIGGERS',
    COUNT(*)
FROM user_triggers

UNION ALL

SELECT
    'TYPES',
    COUNT(*)
FROM user_objects
WHERE object_type = 'TYPE'

UNION ALL

SELECT
    'TYPE BODIES',
    COUNT(*)
FROM user_objects
WHERE object_type = 'TYPE BODY'

UNION ALL

SELECT
    'SYNONYMS',
    COUNT(*)
FROM user_synonyms

ORDER BY
    object_category;

PROMPT
PROMPT ================================================================================
PROMPT SEQUENCE INVENTORY
PROMPT ================================================================================
PROMPT

COLUMN sequence_owner FORMAT A20
COLUMN sequence_name  FORMAT A36
COLUMN sequence_class FORMAT A30
COLUMN min_value      FORMAT 99999999999999999999
COLUMN max_value      FORMAT 99999999999999999999
COLUMN increment_by   FORMAT 999,999
COLUMN cache_size     FORMAT 999,999
COLUMN cycle_flag     FORMAT A10
COLUMN order_flag     FORMAT A10
COLUMN last_number    FORMAT 99999999999999999999

SELECT
    USER AS sequence_owner,
    sequence_name,

    CASE
        WHEN sequence_name LIKE 'ISEQ$$#_%' ESCAPE '#'
            THEN 'ORACLE-MANAGED IDENTITY'
        ELSE 'APPLICATION SEQUENCE'
    END AS sequence_class,

    min_value,
    max_value,
    increment_by,
    cache_size,
    cycle_flag,
    order_flag,
    last_number

FROM user_sequences

ORDER BY
    CASE
        WHEN sequence_name LIKE 'ISEQ$$#_%' ESCAPE '#'
            THEN 2
        ELSE 1
    END,
    sequence_name;

PROMPT
PROMPT ================================================================================
PROMPT TABLE INVENTORY
PROMPT ================================================================================
PROMPT

COLUMN table_name    FORMAT A35
COLUMN num_rows      FORMAT 999,999,999
COLUMN blocks        FORMAT 999,999,999
COLUMN temporary     FORMAT A9
COLUMN partitioned   FORMAT A11
COLUMN last_analyzed FORMAT A20

SELECT
    table_name,
    num_rows,
    blocks,
    temporary,
    partitioned,

    TO_CHAR(
        last_analyzed,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS last_analyzed

FROM user_tables

ORDER BY
    table_name;

PROMPT
PROMPT ================================================================================
PROMPT PL/SQL OBJECT INVENTORY
PROMPT ================================================================================
PROMPT

COLUMN object_name   FORMAT A40
COLUMN object_type   FORMAT A20
COLUMN status        FORMAT A10
COLUMN last_ddl_time FORMAT A20

SELECT
    object_name,
    object_type,
    status,

    TO_CHAR(
        last_ddl_time,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS last_ddl_time

FROM user_objects

WHERE object_type IN
      (
          'PACKAGE',
          'PACKAGE BODY',
          'PROCEDURE',
          'FUNCTION',
          'TRIGGER',
          'TYPE',
          'TYPE BODY'
      )

ORDER BY
    object_type,
    object_name;

PROMPT
PROMPT ================================================================================
PROMPT INVENTORY INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT This report inventories the objects currently owned by the connected schema.
PROMPT
PROMPT Object counts are point-in-time values and may change after schema deployment.
PROMPT
PROMPT VALID status indicates that Oracle currently considers the object usable.
PROMPT
PROMPT INVALID objects are reviewed in the next schema validation script.
PROMPT
PROMPT Application sequences are reported separately from Oracle-managed identity
PROMPT sequences whose names begin with ISEQ$$_.
PROMPT
PROMPT Oracle-managed identity sequences support identity columns and should not
PROMPT be treated as manually designed application sequences.
PROMPT
PROMPT NUM_ROWS and BLOCKS reflect the latest available optimizer statistics.
PROMPT
PROMPT NULL table statistics indicate that optimizer statistics are unavailable.
PROMPT
PROMPT No schema object, application data, constraint, index, sequence, or statistic
PROMPT is modified by this script.
PROMPT
PROMPT End of schema object inventory report.