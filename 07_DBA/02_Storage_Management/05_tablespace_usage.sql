/*
  Script  : 05_tablespace_usage.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports allocated and configured capacity for database tablespaces.
  Run As  : SYSDBA
  Usage   : @05_tablespace_usage.sql

  Notes
  -----
  - This script is read-only.
  - Usage percentages are calculated against current allocation and configured maximum capacity.
  - UNDO reusable space must also be evaluated with 04_undo_management.sql.
  - Temporary usage represents the current state at execution time.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 260
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF

PROMPT
PROMPT Tablespace Usage Summary

WITH permanent_files AS (
    SELECT
        df.tablespace_name,
        SUM(df.bytes) AS allocated_bytes,
        SUM(
            CASE
                WHEN df.autoextensible = 'YES' THEN df.maxbytes
                ELSE df.bytes
            END
        ) AS max_bytes
    FROM
        dba_data_files df
    GROUP BY
        df.tablespace_name
),
permanent_free AS (
    SELECT
        fs.tablespace_name,
        SUM(fs.bytes) AS free_bytes
    FROM
        dba_free_space fs
    GROUP BY
        fs.tablespace_name
),
permanent_usage AS (
    SELECT
        ts.tablespace_name,
        ts.contents,
        ts.status,
        pf.allocated_bytes,
        pf.allocated_bytes - NVL(pfr.free_bytes, 0) AS used_bytes,
        NVL(pfr.free_bytes, 0) AS free_bytes,
        pf.max_bytes
    FROM
        dba_tablespaces ts
        JOIN permanent_files pf
            ON pf.tablespace_name = ts.tablespace_name
        LEFT JOIN permanent_free pfr
            ON pfr.tablespace_name = ts.tablespace_name
    WHERE
        ts.contents IN ('PERMANENT', 'UNDO')
),
temp_files AS (
    SELECT
        tf.tablespace_name,
        SUM(tf.bytes) AS allocated_bytes,
        SUM(
            CASE
                WHEN tf.autoextensible = 'YES' THEN tf.maxbytes
                ELSE tf.bytes
            END
        ) AS max_bytes
    FROM
        dba_temp_files tf
    GROUP BY
        tf.tablespace_name
),
temp_usage AS (
    SELECT
        tsh.tablespace_name,
        SUM(tsh.bytes_used) AS used_bytes,
        SUM(tsh.bytes_free) AS free_bytes
    FROM
        v$temp_space_header tsh
    GROUP BY
        tsh.tablespace_name
),
temporary_usage AS (
    SELECT
        ts.tablespace_name,
        ts.contents,
        ts.status,
        tf.allocated_bytes,
        NVL(tu.used_bytes, 0) AS used_bytes,
        NVL(tu.free_bytes, tf.allocated_bytes) AS free_bytes,
        tf.max_bytes
    FROM
        dba_tablespaces ts
        JOIN temp_files tf
            ON tf.tablespace_name = ts.tablespace_name
        LEFT JOIN temp_usage tu
            ON tu.tablespace_name = ts.tablespace_name
    WHERE
        ts.contents = 'TEMPORARY'
),
all_usage AS (
    SELECT * FROM permanent_usage
    UNION ALL
    SELECT * FROM temporary_usage
)
SELECT
    tablespace_name,
    contents,
    status,
    ROUND(allocated_bytes / 1024 / 1024, 2) AS allocated_mb,
    ROUND(used_bytes / 1024 / 1024, 2) AS used_mb,
    ROUND(free_bytes / 1024 / 1024, 2) AS free_mb,
    ROUND(used_bytes / NULLIF(allocated_bytes, 0) * 100, 2) AS used_pct_allocated,
    ROUND(max_bytes / 1024 / 1024, 2) AS configured_max_mb,
    ROUND(used_bytes / NULLIF(max_bytes, 0) * 100, 2) AS used_pct_configured_max,
    CASE
        WHEN used_bytes / NULLIF(allocated_bytes, 0) * 100 >= 90 THEN 'CRITICAL'
        WHEN used_bytes / NULLIF(allocated_bytes, 0) * 100 >= 80 THEN 'WARNING'
        ELSE 'NORMAL'
    END AS allocated_usage_status
FROM
    all_usage
ORDER BY
    CASE contents
        WHEN 'PERMANENT' THEN 1
        WHEN 'UNDO' THEN 2
        WHEN 'TEMPORARY' THEN 3
        ELSE 4
    END,
    tablespace_name;

PROMPT
PROMPT Tablespace Capacity Summary By Type

WITH permanent_capacity AS (
    SELECT
        ts.contents,
        SUM(df.bytes) AS allocated_bytes,
        SUM(
            CASE
                WHEN df.autoextensible = 'YES' THEN df.maxbytes
                ELSE df.bytes
            END
        ) AS max_bytes
    FROM
        dba_tablespaces ts
        JOIN dba_data_files df
            ON df.tablespace_name = ts.tablespace_name
    WHERE
        ts.contents IN ('PERMANENT', 'UNDO')
    GROUP BY
        ts.contents
),
temporary_capacity AS (
    SELECT
        'TEMPORARY' AS contents,
        SUM(tf.bytes) AS allocated_bytes,
        SUM(
            CASE
                WHEN tf.autoextensible = 'YES' THEN tf.maxbytes
                ELSE tf.bytes
            END
        ) AS max_bytes
    FROM
        dba_temp_files tf
),
capacity_summary AS (
    SELECT * FROM permanent_capacity
    UNION ALL
    SELECT * FROM temporary_capacity
)
SELECT
    contents,
    ROUND(allocated_bytes / 1024 / 1024, 2) AS allocated_mb,
    ROUND(max_bytes / 1024 / 1024, 2) AS configured_max_mb
FROM
    capacity_summary
ORDER BY
    CASE contents
        WHEN 'PERMANENT' THEN 1
        WHEN 'UNDO' THEN 2
        WHEN 'TEMPORARY' THEN 3
        ELSE 4
    END;

PROMPT
PROMPT Tablespace Usage Inventory Completed
