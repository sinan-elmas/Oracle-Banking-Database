/*
  Script  : 01_environment_inventory.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Collects a read-only inventory of the Oracle database environment.
  Run As  : SYSDBA
  Usage   : @01_environment_inventory.sql

  Notes
  -----
  - This script does not modify database objects or configuration.
  - SQLcl is recommended for ANSICONSOLE output.
  - The BANKING_DB sections assume that the schema already exists.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 220
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TIMING OFF

PROMPT
PROMPT Database Information

SELECT
    name              AS database_name,
    dbid,
    created,
    open_mode,
    log_mode,
    database_role,
    platform_name,
    flashback_on
FROM v$database;

PROMPT
PROMPT Instance Information

SELECT
    instance_name,
    host_name,
    version,
    startup_time,
    status,
    database_status,
    archiver,
    parallel
FROM v$instance;

PROMPT
PROMPT Oracle Version

SELECT banner_full
FROM v$version
WHERE banner_full LIKE 'Oracle Database%';

PROMPT
PROMPT Database Architecture

SELECT
    name AS database_name,
    cdb
FROM v$database;

SELECT
    SYS_CONTEXT('USERENV', 'CON_NAME') AS container_name
FROM dual;

PROMPT
PROMPT Important File Locations

SELECT
    name,
    value
FROM v$parameter
WHERE name IN (
    'spfile',
    'control_files',
    'diagnostic_dest',
    'db_create_file_dest',
    'db_recovery_file_dest'
)
ORDER BY name;

PROMPT
PROMPT Memory Configuration

SELECT
    name,
    ROUND(value / 1024 / 1024, 2) AS value_mb
FROM v$parameter
WHERE name IN (
    'memory_target',
    'memory_max_target',
    'sga_target',
    'sga_max_size',
    'pga_aggregate_target',
    'pga_aggregate_limit'
)
ORDER BY name;

PROMPT
PROMPT SGA Components

SELECT
    component,
    ROUND(current_size / 1024 / 1024, 2) AS current_size_mb,
    ROUND(min_size / 1024 / 1024, 2)     AS min_size_mb,
    ROUND(max_size / 1024 / 1024, 2)     AS max_size_mb
FROM v$sga_dynamic_components
WHERE current_size > 0
ORDER BY current_size DESC;

PROMPT
PROMPT Database Services

SELECT
    name,
    network_name
FROM v$services
WHERE name NOT LIKE 'SYS$%'
ORDER BY name;

PROMPT
PROMPT Archive And Flashback Status

SELECT
    name AS database_name,
    log_mode,
    open_mode,
    flashback_on
FROM v$database;

PROMPT
PROMPT Latest Archived Redo Log

SELECT
    thread#,
    sequence#,
    first_time,
    next_time,
    completion_time,
    archived,
    status
FROM (
    SELECT
        thread#,
        sequence#,
        first_time,
        next_time,
        completion_time,
        archived,
        status
    FROM v$archived_log
    WHERE archived = 'YES'
    ORDER BY completion_time DESC, sequence# DESC
)
WHERE ROWNUM = 1;

PROMPT
PROMPT Fast Recovery Area

SELECT
    name,
    ROUND(space_limit / 1024 / 1024, 2)       AS space_limit_mb,
    ROUND(space_used / 1024 / 1024, 2)        AS space_used_mb,
    ROUND(space_reclaimable / 1024 / 1024, 2) AS reclaimable_mb,
    number_of_files
FROM v$recovery_file_dest;

PROMPT
PROMPT Tablespace Summary

SELECT
    tablespace_name,
    status,
    contents,
    extent_management,
    segment_space_management
FROM dba_tablespaces
ORDER BY tablespace_name;

PROMPT
PROMPT Datafile Summary

SELECT
    tablespace_name,
    file_name,
    ROUND(bytes / 1024 / 1024, 2)    AS size_mb,
    autoextensible,
    ROUND(maxbytes / 1024 / 1024, 2) AS max_size_mb
FROM dba_data_files
ORDER BY tablespace_name, file_name;

PROMPT
PROMPT Tempfile Summary

SELECT
    tablespace_name,
    file_name,
    ROUND(bytes / 1024 / 1024, 2)    AS size_mb,
    autoextensible,
    ROUND(maxbytes / 1024 / 1024, 2) AS max_size_mb
FROM dba_temp_files
ORDER BY tablespace_name, file_name;

PROMPT
PROMPT Redo Log Summary

SELECT
    group#,
    thread#,
    sequence#,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    members,
    archived,
    status
FROM v$log
ORDER BY group#;

PROMPT
PROMPT Control Files

SELECT
    name,
    status,
    is_recovery_dest_file
FROM v$controlfile
ORDER BY name;

PROMPT
PROMPT BANKING_DB Object Summary

SELECT
    object_type,
    status,
    COUNT(*) AS object_count
FROM dba_objects
WHERE owner = 'BANKING_DB'
GROUP BY object_type, status
ORDER BY object_type, status;

PROMPT
PROMPT BANKING_DB Invalid Objects

SELECT
    object_name,
    object_type,
    status
FROM dba_objects
WHERE owner = 'BANKING_DB'
  AND status = 'INVALID'
ORDER BY object_type, object_name;

PROMPT
PROMPT BANKING_DB Tablespace Distribution

SELECT
    tablespace_name,
    COUNT(*) AS table_count
FROM dba_tables
WHERE owner = 'BANKING_DB'
GROUP BY tablespace_name
ORDER BY tablespace_name;

SELECT
    tablespace_name,
    COUNT(*) AS index_count
FROM dba_indexes
WHERE owner = 'BANKING_DB'
GROUP BY tablespace_name
ORDER BY tablespace_name;

PROMPT
PROMPT Environment Inventory Completed