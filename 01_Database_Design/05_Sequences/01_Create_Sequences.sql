-- ============================================================================
-- Oracle Banking Database
-- Module       : 01_Database_Design / 05_Sequences
-- Script       : 01_Create_Sequences.sql
-- Purpose      : Create the two explicitly managed application sequences
-- Execution    : Run after table creation
-- Dependencies : 02_Tables
--
-- Design Notes
--   * Oracle-managed ISEQ$$_... identity sequences are intentionally excluded.
--   * Runtime LAST_NUMBER values from the populated development database are
--     not reproduced.
--   * Both application sequences start from 1 for a clean deployment.
--   * CACHE 100 matches the current BANKING_DB sequence configuration.
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
PROMPT CREATE APPLICATION SEQUENCES
PROMPT ================================================================================
PROMPT

CREATE SEQUENCE card_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 1
    MAXVALUE 9999999999999999999999999999
    CACHE 100
    NOCYCLE
    NOORDER;

CREATE SEQUENCE seq_customer_no
    START WITH 1
    INCREMENT BY 1
    MINVALUE 1
    MAXVALUE 9999999999999999999999999999
    CACHE 100
    NOCYCLE
    NOORDER;

PROMPT
PROMPT ================================================================================
PROMPT APPLICATION SEQUENCE CREATION CHECK
PROMPT ================================================================================
PROMPT

COLUMN sequence_name FORMAT A30
COLUMN min_value     FORMAT 9999999999999999999999999999
COLUMN max_value     FORMAT 9999999999999999999999999999
COLUMN increment_by  FORMAT 9999999999
COLUMN cache_size    FORMAT 9999999999
COLUMN cycle_flag    FORMAT A10
COLUMN order_flag    FORMAT A10
COLUMN last_number   FORMAT 9999999999999999999999999999

SELECT
    sequence_name,
    min_value,
    max_value,
    increment_by,
    cache_size,
    cycle_flag,
    order_flag,
    last_number
FROM user_sequences
WHERE sequence_name IN (
    'CARD_SEQ',
    'SEQ_CUSTOMER_NO'
)
ORDER BY sequence_name;

PROMPT
PROMPT Application-sequence creation completed.
PROMPT Oracle-managed identity sequences are created automatically with tables.
PROMPT