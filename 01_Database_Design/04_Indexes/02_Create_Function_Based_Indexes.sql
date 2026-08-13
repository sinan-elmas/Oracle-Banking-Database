-- ============================================================================
-- Oracle Banking Database
-- Module       : 01_Database_Design / 04_Indexes
-- Script       : 02_Create_Function_Based_Indexes.sql
-- Purpose      : Create the function-based unique index that enforces one
--                primary contact per customer and contact type
-- Execution    : Run after 01_Create_Supporting_Indexes.sql
-- Dependencies : 02_Tables
--                03_Constraints
--
-- Design Notes
--   * The function-based expression returns IS_PRIMARY only when its value
--     is 'Y'; otherwise the expression evaluates to NULL.
--   * CUSTOMER_ID and CONTACT_TYPE_ID form the business key.
--   * Oracle permits multiple NULL values in a unique index, so non-primary
--     contact rows do not conflict with one another.
--
-- Safety
--   DDL script. Run only during a clean deployment or controlled rebuild.
-- ============================================================================

SET DEFINE OFF
SET VERIFY OFF
SET FEEDBACK ON
SET SQLBLANKLINES ON

WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT
PROMPT ================================================================================
PROMPT CREATE FUNCTION-BASED INDEXES
PROMPT ================================================================================
PROMPT

CREATE UNIQUE INDEX uq_customer_primary_contact
    ON customer_contacts
    (
        customer_id,
        contact_type_id,
        CASE
            WHEN is_primary = 'Y'
            THEN is_primary
        END
    );

PROMPT
PROMPT ================================================================================
PROMPT FUNCTION-BASED INDEX CREATION CHECK
PROMPT ================================================================================
PROMPT

COLUMN index_name        FORMAT A40
COLUMN table_name        FORMAT A30
COLUMN index_type        FORMAT A24
COLUMN uniqueness        FORMAT A10
COLUMN status            FORMAT A10
COLUMN visibility        FORMAT A10
COLUMN column_position   FORMAT 999
COLUMN column_name       FORMAT A40
COLUMN column_expression FORMAT A100 WORD_WRAPPED

SELECT
    index_name,
    table_name,
    index_type,
    uniqueness,
    status,
    visibility
FROM user_indexes
WHERE index_name = 'UQ_CUSTOMER_PRIMARY_CONTACT';

SELECT
    index_name,
    table_name,
    column_position,
    column_name
FROM user_ind_columns
WHERE index_name = 'UQ_CUSTOMER_PRIMARY_CONTACT'
ORDER BY column_position;

SELECT
    index_name,
    table_name,
    column_position,
    column_expression
FROM user_ind_expressions
WHERE index_name = 'UQ_CUSTOMER_PRIMARY_CONTACT'
ORDER BY column_position;

PROMPT
PROMPT Function-based index creation completed.
PROMPT