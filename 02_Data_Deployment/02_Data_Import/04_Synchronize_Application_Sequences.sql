-- ============================================================================
-- Oracle Banking Database
-- Module       : 02_Data_Deployment / 02_Data_Import
-- Script       : 04_Synchronize_Application_Sequences.sql
-- Purpose      : Synchronize the two explicitly managed application sequences
--                after the DATA_ONLY import
-- Execution    : Run as BANKING_DB after Data Pump import
-- Safety       : Alters only CARD_SEQ and SEQ_CUSTOMER_NO
--
-- Verified application usage:
--   CARD_SEQ
--     PKG_CARD_MANAGEMENT uses CARD_SEQ.NEXTVAL as CARDS.CARD_ID and builds
--     CARD_NUMBER as '4000' || LPAD(CARD_ID, 12, '0').
--
--   SEQ_CUSTOMER_NO
--     PKG_CUSTOMER_MANAGEMENT builds CUSTOMER_NO as
--     'CUST' || LPAD(SEQ_CUSTOMER_NO.NEXTVAL, 6, '0').
--
-- Synchronization targets:
--   CARD_SEQ        -> MAX(CARDS.CARD_ID) + 1
--   SEQ_CUSTOMER_NO -> MAX(numeric suffix of CUSTOMERS.CUSTOMER_NO) + 1
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 200
SET LINESIZE 220
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET SQLBLANKLINES ON

WHENEVER SQLERROR EXIT SQL.SQLCODE

COLUMN sequence_name      FORMAT A30
COLUMN last_number        FORMAT 9999999999999999999999999999
COLUMN target_next_value  FORMAT 9999999999999999999999999999
COLUMN result             FORMAT A10
COLUMN check_name         FORMAT A42
COLUMN actual_value       FORMAT 999999999

PROMPT
PROMPT ================================================================================
PROMPT APPLICATION SEQUENCE SYNCHRONIZATION
PROMPT ================================================================================
PROMPT

PROMPT --- A. IMPORTED DATA FORMAT PRECHECK ---
PROMPT

SELECT
    'INVALID_CUSTOMER_NO_FORMAT' AS check_name,
    COUNT(*) AS actual_value,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM customers
WHERE customer_no IS NULL
   OR NOT REGEXP_LIKE(customer_no, '^CUST[0-9]{6}$');

PROMPT
PROMPT --- B. REQUIRED NEXT VALUES ---
PROMPT

SELECT
    'CARD_SEQ' AS sequence_name,
    NVL(MAX(card_id), 0) + 1 AS target_next_value
FROM cards

UNION ALL

SELECT
    'SEQ_CUSTOMER_NO',
    NVL(
        MAX(
            CASE
                WHEN REGEXP_LIKE(customer_no, '^CUST[0-9]{6}$')
                THEN TO_NUMBER(SUBSTR(customer_no, 5))
            END
        ),
        0
    ) + 1
FROM customers;

PROMPT
PROMPT --- C. SYNCHRONIZE CARD_SEQ ---
PROMPT

DECLARE
    l_invalid_count NUMBER;
    l_target        NUMBER;
    l_current       NUMBER;
    l_increment     NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO l_invalid_count
    FROM customers
    WHERE customer_no IS NULL
       OR NOT REGEXP_LIKE(customer_no, '^CUST[0-9]{6}$');

    IF l_invalid_count > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Sequence synchronization stopped: invalid CUSTOMER_NO format count = '
            || l_invalid_count
        );
    END IF;

    SELECT NVL(MAX(card_id), 0) + 1
    INTO l_target
    FROM cards;

    SELECT card_seq.NEXTVAL
    INTO l_current
    FROM dual;

    DBMS_OUTPUT.PUT_LINE('CARD_SEQ current consumed value : ' || l_current);
    DBMS_OUTPUT.PUT_LINE('CARD_SEQ required next value    : ' || l_target);

    IF l_current < l_target THEN
        l_increment := l_target - l_current;

        EXECUTE IMMEDIATE
            'ALTER SEQUENCE card_seq INCREMENT BY ' || l_increment;

        SELECT card_seq.NEXTVAL
        INTO l_current
        FROM dual;

        EXECUTE IMMEDIATE
            'ALTER SEQUENCE card_seq INCREMENT BY 1';

        DBMS_OUTPUT.PUT_LINE('CARD_SEQ synchronized to       : ' || l_current);
    ELSE
        DBMS_OUTPUT.PUT_LINE(
            'CARD_SEQ already safe; no forward adjustment required.'
        );
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        BEGIN
            EXECUTE IMMEDIATE
                'ALTER SEQUENCE card_seq INCREMENT BY 1';
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        RAISE;
END;
/

PROMPT
PROMPT --- D. SYNCHRONIZE SEQ_CUSTOMER_NO ---
PROMPT

DECLARE
    l_target        NUMBER;
    l_current       NUMBER;
    l_increment     NUMBER;
BEGIN
    SELECT NVL(MAX(TO_NUMBER(SUBSTR(customer_no, 5))), 0) + 1
    INTO l_target
    FROM customers
    WHERE REGEXP_LIKE(customer_no, '^CUST[0-9]{6}$');

    SELECT seq_customer_no.NEXTVAL
    INTO l_current
    FROM dual;

    DBMS_OUTPUT.PUT_LINE(
        'SEQ_CUSTOMER_NO current consumed value : ' || l_current
    );
    DBMS_OUTPUT.PUT_LINE(
        'SEQ_CUSTOMER_NO required next value    : ' || l_target
    );

    IF l_current < l_target THEN
        l_increment := l_target - l_current;

        EXECUTE IMMEDIATE
            'ALTER SEQUENCE seq_customer_no INCREMENT BY ' || l_increment;

        SELECT seq_customer_no.NEXTVAL
        INTO l_current
        FROM dual;

        EXECUTE IMMEDIATE
            'ALTER SEQUENCE seq_customer_no INCREMENT BY 1';

        DBMS_OUTPUT.PUT_LINE(
            'SEQ_CUSTOMER_NO synchronized to       : ' || l_current
        );
    ELSE
        DBMS_OUTPUT.PUT_LINE(
            'SEQ_CUSTOMER_NO already safe; no forward adjustment required.'
        );
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        BEGIN
            EXECUTE IMMEDIATE
                'ALTER SEQUENCE seq_customer_no INCREMENT BY 1';
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        RAISE;
END;
/

PROMPT
PROMPT --- E. POST-SYNCHRONIZATION STATUS ---
PROMPT

SELECT
    sequence_name,
    increment_by,
    cache_size,
    cycle_flag,
    order_flag,
    last_number
FROM user_sequences
WHERE sequence_name IN
(
    'CARD_SEQ',
    'SEQ_CUSTOMER_NO'
)
ORDER BY sequence_name;

PROMPT
PROMPT --- F. SAFETY VALIDATION ---
PROMPT

WITH required_values AS
(
    SELECT
        'CARD_SEQ' AS sequence_name,
        NVL(MAX(card_id), 0) + 1 AS target_next_value
    FROM cards

    UNION ALL

    SELECT
        'SEQ_CUSTOMER_NO',
        NVL(
            MAX(
                CASE
                    WHEN REGEXP_LIKE(customer_no, '^CUST[0-9]{6}$')
                    THEN TO_NUMBER(SUBSTR(customer_no, 5))
                END
            ),
            0
        ) + 1
    FROM customers
)
SELECT
    s.sequence_name,
    s.last_number,
    r.target_next_value,
    CASE
        WHEN s.last_number >= r.target_next_value THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM user_sequences s
JOIN required_values r
  ON r.sequence_name = s.sequence_name
WHERE s.sequence_name IN
(
    'CARD_SEQ',
    'SEQ_CUSTOMER_NO'
)
ORDER BY s.sequence_name;

PROMPT
PROMPT ================================================================================
PROMPT SEQUENCE SYNCHRONIZATION COMPLETED
PROMPT ================================================================================
PROMPT Both final validation rows must return PASS.
PROMPT
