/*
  Script  : 02_instance_parameters.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports critical Oracle Database initialization parameters.
  Run As  : SYSDBA
  Usage   : @02_instance_parameters.sql

  Notes
  -----
  - This script is read-only.
  - Parameter values reflect the currently running instance.
  - SQLcl is recommended for ANSICONSOLE output.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 240
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF

PROMPT
PROMPT Critical Instance Parameters

SELECT
    name,
    display_value,
    isdefault,
    issys_modifiable,
    ispdb_modifiable
FROM
    v$parameter
WHERE
    name IN (
        'audit_trail',
        'cluster_database',
        'compatible',
        'control_files',
        'cursor_sharing',
        'db_block_size',
        'db_create_file_dest',
        'db_domain',
        'db_name',
        'db_recovery_file_dest',
        'db_recovery_file_dest_size',
        'diagnostic_dest',
        'enable_ddl_logging',
        'filesystemio_options',
        'instance_name',
        'job_queue_processes',
        'log_archive_dest_1',
        'log_archive_format',
        'memory_max_target',
        'memory_target',
        'open_cursors',
        'optimizer_mode',
        'pga_aggregate_limit',
        'pga_aggregate_target',
        'processes',
        'remote_login_passwordfile',
        'resource_limit',
        'service_names',
        'sessions',
        'sga_max_size',
        'sga_target',
        'spfile',
        'undo_management',
        'undo_retention',
        'undo_tablespace'
    )
ORDER BY
    name;

PROMPT
PROMPT Memory Management Mode

WITH memory_parameters AS (
    SELECT
        MAX(CASE WHEN name = 'memory_target' THEN TO_NUMBER(value) END) AS memory_target,
        MAX(CASE WHEN name = 'sga_target' THEN TO_NUMBER(value) END) AS sga_target,
        MAX(CASE WHEN name = 'pga_aggregate_target' THEN TO_NUMBER(value) END) AS pga_aggregate_target
    FROM
        v$parameter
    WHERE
        name IN ('memory_target', 'sga_target', 'pga_aggregate_target')
)
SELECT
    CASE
        WHEN memory_target > 0 THEN 'AMM'
        WHEN sga_target > 0 AND pga_aggregate_target > 0 THEN 'ASMM'
        ELSE 'MANUAL'
    END AS memory_management_mode,
    ROUND(memory_target / 1024 / 1024, 2) AS memory_target_mb,
    ROUND(sga_target / 1024 / 1024, 2) AS sga_target_mb,
    ROUND(pga_aggregate_target / 1024 / 1024, 2) AS pga_target_mb
FROM
    memory_parameters;

PROMPT
PROMPT Process And Session Capacity

SELECT
    resource_name,
    current_utilization,
    max_utilization,
    initial_allocation,
    limit_value,
    ROUND(
        CASE
            WHEN REGEXP_LIKE(TRIM(limit_value), '^[[:digit:]]+$')
                 AND TO_NUMBER(TRIM(limit_value)) > 0
            THEN max_utilization / TO_NUMBER(TRIM(limit_value)) * 100
        END,
        2
    ) AS max_utilization_pct
FROM
    v$resource_limit
WHERE
    resource_name IN ('processes', 'sessions', 'transactions')
ORDER BY
    resource_name;

PROMPT
PROMPT Relevant Nondefault Parameters

SELECT
    name,
    display_value,
    issys_modifiable,
    ismodified,
    isadjusted
FROM
    v$parameter
WHERE
    isdefault = 'FALSE'
AND name NOT IN (
        'db_cache_size',
        'java_pool_size',
        'large_pool_size',
        'shared_pool_size',
        'streams_pool_size'
    )
ORDER BY
    name;

PROMPT
PROMPT Instance Parameter Inventory Completed
