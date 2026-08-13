/*
  Script  : 03_tempfile_inventory.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports temporary tablespace and tempfile configuration.
  Run As  : SYSDBA
  Usage   : @03_tempfile_inventory.sql

  Notes
  -----
  - This script is read-only.
  - Autoextend capacity is reported separately from current allocation.
  - The nonstandard-path check is specific to the ORCL lab environment.
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
PROMPT Temporary Tablespace Configuration

SELECT
    tablespace_name,
    status,
    contents,
    extent_management,
    allocation_type,
    ROUND(block_size / 1024, 2) AS block_size_kb,
    bigfile
FROM
    dba_tablespaces
WHERE
    contents = 'TEMPORARY'
ORDER BY
    tablespace_name;

PROMPT
PROMPT Tempfile Inventory

SELECT
    tf.file_id,
    tf.tablespace_name,
    tf.file_name,
    ROUND(tf.bytes / 1024 / 1024, 2) AS size_mb,
    tf.autoextensible,
    ROUND(tf.increment_by * ts.block_size / 1024 / 1024, 2) AS next_extent_mb,
    CASE
        WHEN tf.autoextensible = 'YES'
        THEN ROUND(tf.maxbytes / 1024 / 1024, 2)
    END AS max_size_mb,
    tf.status
FROM
    dba_temp_files tf
    JOIN dba_tablespaces ts
        ON ts.tablespace_name = tf.tablespace_name
ORDER BY
    tf.tablespace_name,
    tf.file_id;

PROMPT
PROMPT Tempfile Summary By Tablespace

SELECT
    tf.tablespace_name,
    COUNT(*) AS tempfile_count,
    ROUND(SUM(tf.bytes) / 1024 / 1024, 2) AS allocated_mb,
    SUM(
        CASE
            WHEN tf.autoextensible = 'YES' THEN 1
            ELSE 0
        END
    ) AS autoextend_files,
    ROUND(
        SUM(
            CASE
                WHEN tf.autoextensible = 'YES' THEN tf.maxbytes
                ELSE tf.bytes
            END
        ) / 1024 / 1024,
        2
    ) AS max_allocated_mb
FROM
    dba_temp_files tf
GROUP BY
    tf.tablespace_name
ORDER BY
    tf.tablespace_name;

PROMPT
PROMPT Default Temporary Tablespace

SELECT
    property_name,
    property_value
FROM
    database_properties
WHERE
    property_name = 'DEFAULT_TEMP_TABLESPACE';

PROMPT
PROMPT Tempfiles Outside Expected ORCL Lab Directory

SELECT
    file_id,
    tablespace_name,
    file_name
FROM
    dba_temp_files
WHERE
    file_name NOT LIKE '/u01/app/oracle/oradata/ORCL/%'
ORDER BY
    tablespace_name,
    file_id;

PROMPT
PROMPT Tempfile Inventory Completed
