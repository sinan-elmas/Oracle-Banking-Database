/*
  Script  : 02_datafile_inventory.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports permanent and UNDO datafile configuration and capacity.
  Run As  : SYSDBA
  Usage   : @02_datafile_inventory.sql

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
PROMPT Datafile Inventory

SELECT
    df.file_id,
    df.tablespace_name,
    ts.contents,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024, 2) AS size_mb,
    df.autoextensible,
    ROUND(df.increment_by * ts.block_size / 1024 / 1024, 2) AS next_extent_mb,
    CASE
        WHEN df.autoextensible = 'YES'
        THEN ROUND(df.maxbytes / 1024 / 1024, 2)
    END AS max_size_mb,
    df.status,
    df.online_status
FROM
    dba_data_files df
    JOIN dba_tablespaces ts
        ON ts.tablespace_name = df.tablespace_name
WHERE
    ts.contents IN ('PERMANENT', 'UNDO')
ORDER BY
    CASE ts.contents
        WHEN 'PERMANENT' THEN 1
        WHEN 'UNDO' THEN 2
        ELSE 3
    END,
    df.tablespace_name,
    df.file_id;

PROMPT
PROMPT Datafile Summary By Tablespace

SELECT
    df.tablespace_name,
    ts.contents,
    COUNT(*) AS datafile_count,
    ROUND(SUM(df.bytes) / 1024 / 1024, 2) AS allocated_mb,
    SUM(
        CASE
            WHEN df.autoextensible = 'YES' THEN 1
            ELSE 0
        END
    ) AS autoextend_files,
    ROUND(
        SUM(
            CASE
                WHEN df.autoextensible = 'YES' THEN df.maxbytes
                ELSE df.bytes
            END
        ) / 1024 / 1024,
        2
    ) AS max_allocated_mb
FROM
    dba_data_files df
    JOIN dba_tablespaces ts
        ON ts.tablespace_name = df.tablespace_name
WHERE
    ts.contents IN ('PERMANENT', 'UNDO')
GROUP BY
    df.tablespace_name,
    ts.contents
ORDER BY
    CASE ts.contents
        WHEN 'PERMANENT' THEN 1
        WHEN 'UNDO' THEN 2
        ELSE 3
    END,
    df.tablespace_name;

PROMPT
PROMPT Datafiles Outside Expected ORCL Lab Directory

SELECT
    file_id,
    tablespace_name,
    file_name
FROM
    dba_data_files
WHERE
    file_name NOT LIKE '/u01/app/oracle/oradata/ORCL/%'
ORDER BY
    tablespace_name,
    file_id;

PROMPT
PROMPT Datafile Inventory Completed
