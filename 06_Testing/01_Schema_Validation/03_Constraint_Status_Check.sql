-- ============================================================================
-- Oracle Banking Database
-- Module       : Testing / Schema Validation
-- Script       : 03_Constraint_Status_Check.sql
-- Purpose      : Validate constraint status, validation state, and health
-- Scope        : Current application schema
-- Safety       : Read-only
-- Environment  : Oracle AI Database 26ai Enterprise Edition
-- Version      : 23.26.1.0.0
-- Schema       : BANKING_DB
-- ============================================================================

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 500
SET LINESIZE 240
SET FEEDBACK ON
SET VERIFY OFF
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

PROMPT
PROMPT ================================================================================
PROMPT CONSTRAINT HEALTH SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN schema_name               FORMAT A20
COLUMN total_constraints         FORMAT 999,999
COLUMN enabled_constraints       FORMAT 999,999
COLUMN disabled_constraints      FORMAT 999,999
COLUMN validated_constraints     FORMAT 999,999
COLUMN not_validated_constraints FORMAT 999,999
COLUMN health_status             FORMAT A12
COLUMN report_time               FORMAT A20

WITH constraint_health AS
(
    SELECT
        COUNT(*) AS total_constraints,

        SUM(
            CASE
                WHEN status = 'ENABLED' THEN 1
                ELSE 0
            END
        ) AS enabled_constraints,

        SUM(
            CASE
                WHEN status = 'DISABLED' THEN 1
                ELSE 0
            END
        ) AS disabled_constraints,

        SUM(
            CASE
                WHEN validated = 'VALIDATED' THEN 1
                ELSE 0
            END
        ) AS validated_constraints,

        SUM(
            CASE
                WHEN validated <> 'VALIDATED' THEN 1
                ELSE 0
            END
        ) AS not_validated_constraints

    FROM user_constraints

    WHERE constraint_type IN
          (
              'P',
              'U',
              'R',
              'C'
          )
)
SELECT
    USER AS schema_name,
    total_constraints,
    enabled_constraints,
    disabled_constraints,
    validated_constraints,
    not_validated_constraints,

    CASE
        WHEN disabled_constraints = 0
         AND not_validated_constraints = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS health_status,

    TO_CHAR(
        SYSDATE,
        'DD-MON-YYYY HH24:MI:SS'
    ) AS report_time

FROM constraint_health;

PROMPT
PROMPT ================================================================================
PROMPT CONSTRAINT TYPE SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN constraint_type_name FORMAT A24
COLUMN constraint_count     FORMAT 999,999
COLUMN enabled_count        FORMAT 999,999
COLUMN disabled_count       FORMAT 999,999
COLUMN validated_count      FORMAT 999,999
COLUMN not_validated_count  FORMAT 999,999

SELECT
    CASE constraint_type
        WHEN 'P' THEN 'PRIMARY KEY'
        WHEN 'U' THEN 'UNIQUE'
        WHEN 'R' THEN 'FOREIGN KEY'
        WHEN 'C' THEN 'CHECK / NOT NULL'
        ELSE constraint_type
    END AS constraint_type_name,

    COUNT(*) AS constraint_count,

    SUM(
        CASE
            WHEN status = 'ENABLED' THEN 1
            ELSE 0
        END
    ) AS enabled_count,

    SUM(
        CASE
            WHEN status = 'DISABLED' THEN 1
            ELSE 0
        END
    ) AS disabled_count,

    SUM(
        CASE
            WHEN validated = 'VALIDATED' THEN 1
            ELSE 0
        END
    ) AS validated_count,

    SUM(
        CASE
            WHEN validated <> 'VALIDATED' THEN 1
            ELSE 0
        END
    ) AS not_validated_count

FROM user_constraints

WHERE constraint_type IN
      (
          'P',
          'U',
          'R',
          'C'
      )

GROUP BY
    constraint_type

ORDER BY
    CASE constraint_type
        WHEN 'P' THEN 1
        WHEN 'U' THEN 2
        WHEN 'R' THEN 3
        WHEN 'C' THEN 4
        ELSE 5
    END;

PROMPT
PROMPT ================================================================================
PROMPT NAMED APPLICATION CONSTRAINT DETAILS
PROMPT ================================================================================
PROMPT

COLUMN table_name           FORMAT A30
COLUMN constraint_name      FORMAT A38
COLUMN constraint_type_name FORMAT A22
COLUMN status               FORMAT A10
COLUMN validated            FORMAT A14
COLUMN deferrable           FORMAT A15
COLUMN deferred             FORMAT A10
COLUMN rely                 FORMAT A8
COLUMN delete_rule          FORMAT A12
COLUMN index_name           FORMAT A38

SELECT
    table_name,
    constraint_name,

    CASE constraint_type
        WHEN 'P' THEN 'PRIMARY KEY'
        WHEN 'U' THEN 'UNIQUE'
        WHEN 'R' THEN 'FOREIGN KEY'
        WHEN 'C' THEN 'CHECK'
        ELSE constraint_type
    END AS constraint_type_name,

    status,
    validated,
    deferrable,
    deferred,
    rely,
    delete_rule,
    index_name

FROM user_constraints

WHERE constraint_type IN
      (
          'P',
          'U',
          'R',
          'C'
      )
  AND constraint_name NOT LIKE 'SYS_%'

ORDER BY
    table_name,
    CASE constraint_type
        WHEN 'P' THEN 1
        WHEN 'U' THEN 2
        WHEN 'R' THEN 3
        WHEN 'C' THEN 4
        ELSE 5
    END,
    constraint_name;

PROMPT
PROMPT ================================================================================
PROMPT DISABLED OR NOT VALIDATED CONSTRAINTS
PROMPT ================================================================================
PROMPT

COLUMN table_name           FORMAT A30
COLUMN constraint_name      FORMAT A38
COLUMN constraint_type_name FORMAT A22
COLUMN status               FORMAT A10
COLUMN validated            FORMAT A14
COLUMN deferrable           FORMAT A15
COLUMN deferred             FORMAT A10

SELECT
    table_name,
    constraint_name,

    CASE constraint_type
        WHEN 'P' THEN 'PRIMARY KEY'
        WHEN 'U' THEN 'UNIQUE'
        WHEN 'R' THEN 'FOREIGN KEY'
        WHEN 'C' THEN 'CHECK / NOT NULL'
        ELSE constraint_type
    END AS constraint_type_name,

    status,
    validated,
    deferrable,
    deferred

FROM user_constraints

WHERE constraint_type IN
      (
          'P',
          'U',
          'R',
          'C'
      )
  AND
      (
          status <> 'ENABLED'
          OR validated <> 'VALIDATED'
      )

ORDER BY
    table_name,
    constraint_name;

PROMPT
PROMPT ================================================================================
PROMPT FOREIGN KEY REFERENCE SUMMARY
PROMPT ================================================================================
PROMPT

COLUMN child_table      FORMAT A30
COLUMN foreign_key_name FORMAT A38
COLUMN parent_table     FORMAT A30
COLUMN delete_rule      FORMAT A12
COLUMN status           FORMAT A10
COLUMN validated        FORMAT A14

SELECT
    fk.table_name AS child_table,
    fk.constraint_name AS foreign_key_name,
    pk.table_name AS parent_table,
    fk.delete_rule,
    fk.status,
    fk.validated

FROM user_constraints fk

JOIN user_constraints pk
  ON pk.constraint_name = fk.r_constraint_name

WHERE fk.constraint_type = 'R'

ORDER BY
    fk.table_name,
    fk.constraint_name;

PROMPT
PROMPT ================================================================================
PROMPT CONSTRAINT INTERPRETATION NOTES
PROMPT ================================================================================
PROMPT
PROMPT PASS means all primary key, unique, foreign key, and check constraints
PROMPT are enabled and validated.
PROMPT
PROMPT The health summary includes both application-named constraints and
PROMPT Oracle-generated SYS_ constraints.
PROMPT
PROMPT The named application constraint detail section excludes SYS_ constraints
PROMPT to avoid listing Oracle-generated NOT NULL and system constraint names.
PROMPT
PROMPT CHECK / NOT NULL in the summary includes explicit check constraints and
PROMPT Oracle-generated constraints used to enforce NOT NULL columns.
PROMPT
PROMPT DISABLED constraints are not actively enforced.
PROMPT
PROMPT NOT VALIDATED constraints may enforce new changes without proving that
PROMPT all existing rows satisfy the constraint.
PROMPT
PROMPT DEFERRABLE and DEFERRED describe when constraint enforcement occurs.
PROMPT
PROMPT DELETE_RULE applies only to foreign-key constraints.
PROMPT
PROMPT No constraint, table, index, or application data is modified by this script.
PROMPT
PROMPT End of constraint status validation report.