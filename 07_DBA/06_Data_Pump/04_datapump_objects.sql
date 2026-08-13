/*
  Script  : 04_datapump_objects.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports Data Pump related database objects, roles, and metadata.
  Run As  : SYSDBA
  Usage   : @04_datapump_objects.sql

  Notes
  -----
  - This script is read-only.
  - Results include Data Pump roles, master tables, and related metadata.
  - Information reflects the current database state.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 340
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Data Pump Master Table Objects

SELECT
    owner,
    object_name,
    object_type,
    status,
    TO_CHAR(created, 'DD-MON-YYYY HH24:MI:SS') AS created_time,
    TO_CHAR(last_ddl_time, 'DD-MON-YYYY HH24:MI:SS') AS last_ddl_time
FROM
    dba_objects
WHERE
    object_type = 'TABLE'
    AND (
           object_name LIKE 'SYS\_EXPORT\_%' ESCAPE '\'
        OR object_name LIKE 'SYS\_IMPORT\_%' ESCAPE '\'
    )
ORDER BY
    created DESC,
    owner,
    object_name;

PROMPT
PROMPT Data Pump External Tables

SELECT
    owner,
    table_name,
    type_owner,
    type_name,
    default_directory_owner,
    default_directory_name,
    access_type,
    reject_limit
FROM
    dba_external_tables
WHERE
    UPPER(type_name) = 'ORACLE_DATAPUMP'
ORDER BY
    owner,
    table_name;

PROMPT
PROMPT Invalid Data Pump Related Objects

WITH datapump_objects AS (
    SELECT
        owner,
        object_name
    FROM
        dba_objects
    WHERE
        object_type = 'TABLE'
        AND (
               object_name LIKE 'SYS\_EXPORT\_%' ESCAPE '\'
            OR object_name LIKE 'SYS\_IMPORT\_%' ESCAPE '\'
        )
    UNION
    SELECT
        owner,
        table_name AS object_name
    FROM
        dba_external_tables
    WHERE
        UPPER(type_name) = 'ORACLE_DATAPUMP'
)
SELECT
    o.owner,
    o.object_name,
    o.object_type,
    o.status,
    TO_CHAR(o.last_ddl_time, 'DD-MON-YYYY HH24:MI:SS') AS last_ddl_time
FROM
    dba_objects o
    JOIN datapump_objects d
        ON d.owner = o.owner
       AND d.object_name = o.object_name
WHERE
    o.status <> 'VALID'
ORDER BY
    o.owner,
    o.object_name,
    o.object_type;

PROMPT
PROMPT Data Pump Object Summary

WITH master_table_summary AS (
    SELECT
        COUNT(*) AS master_table_count,
        SUM(
            CASE
                WHEN status <> 'VALID' THEN 1
                ELSE 0
            END
        ) AS invalid_master_table_count
    FROM
        dba_objects
    WHERE
        object_type = 'TABLE'
        AND (
               object_name LIKE 'SYS\_EXPORT\_%' ESCAPE '\'
            OR object_name LIKE 'SYS\_IMPORT\_%' ESCAPE '\'
        )
),
external_table_summary AS (
    SELECT
        COUNT(*) AS external_table_count
    FROM
        dba_external_tables
    WHERE
        UPPER(type_name) = 'ORACLE_DATAPUMP'
),
invalid_external_summary AS (
    SELECT
        COUNT(*) AS invalid_external_table_count
    FROM
        dba_objects o
    WHERE
        o.object_type = 'TABLE'
        AND o.status <> 'VALID'
        AND EXISTS (
            SELECT
                1
            FROM
                dba_external_tables e
            WHERE
                e.owner = o.owner
                AND e.table_name = o.object_name
                AND UPPER(e.type_name) = 'ORACLE_DATAPUMP'
        )
)
SELECT
    mts.master_table_count,
    NVL(mts.invalid_master_table_count, 0) AS invalid_master_table_count,
    ets.external_table_count,
    ies.invalid_external_table_count,
    CASE
        WHEN NVL(mts.invalid_master_table_count, 0) > 0
          OR ies.invalid_external_table_count > 0
        THEN 'REVIEW REQUIRED'
        WHEN mts.master_table_count = 0
         AND ets.external_table_count = 0
        THEN 'NO DATAPUMP OBJECTS'
        ELSE 'HEALTHY'
    END AS datapump_object_state
FROM
    master_table_summary mts
    CROSS JOIN external_table_summary ets
    CROSS JOIN invalid_external_summary ies;

PROMPT
PROMPT Data Pump Object Inventory Completed
