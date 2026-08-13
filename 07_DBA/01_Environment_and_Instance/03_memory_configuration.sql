/*
  Script  : 03_memory_configuration.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports Oracle Database memory configuration and usage.
  Run As  : SYSDBA
  Usage   : @03_memory_configuration.sql

  Notes
  -----
  - This script is read-only.
  - Memory values are reported in megabytes where applicable.
  - Advisor output depends on the current workload and instance history.
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
PROMPT Memory Management Summary

SELECT
    CASE
        WHEN MAX(CASE WHEN name = 'memory_target' THEN TO_NUMBER(value) END) > 0
            THEN 'AMM'
        WHEN MAX(CASE WHEN name = 'sga_target' THEN TO_NUMBER(value) END) > 0
            THEN 'ASMM'
        ELSE 'MANUAL'
    END AS memory_management_mode,
    ROUND(MAX(CASE WHEN name = 'memory_target'
                   THEN TO_NUMBER(value) END) / 1024 / 1024, 2) AS memory_target_mb,
    ROUND(MAX(CASE WHEN name = 'memory_max_target'
                   THEN TO_NUMBER(value) END) / 1024 / 1024, 2) AS memory_max_target_mb,
    ROUND(MAX(CASE WHEN name = 'sga_target'
                   THEN TO_NUMBER(value) END) / 1024 / 1024, 2) AS sga_target_mb,
    ROUND(MAX(CASE WHEN name = 'sga_max_size'
                   THEN TO_NUMBER(value) END) / 1024 / 1024, 2) AS sga_max_size_mb,
    ROUND(MAX(CASE WHEN name = 'pga_aggregate_target'
                   THEN TO_NUMBER(value) END) / 1024 / 1024, 2) AS pga_target_mb,
    ROUND(MAX(CASE WHEN name = 'pga_aggregate_limit'
                   THEN TO_NUMBER(value) END) / 1024 / 1024, 2) AS pga_limit_mb
FROM
    v$parameter
WHERE
    name IN (
        'memory_target',
        'memory_max_target',
        'sga_target',
        'sga_max_size',
        'pga_aggregate_target',
        'pga_aggregate_limit'
    );

PROMPT
PROMPT SGA Component Allocation

SELECT
    component,
    ROUND(current_size / 1024 / 1024, 2) AS current_size_mb,
    ROUND(min_size / 1024 / 1024, 2) AS min_size_mb,
    ROUND(max_size / 1024 / 1024, 2) AS max_size_mb,
    ROUND(user_specified_size / 1024 / 1024, 2) AS user_specified_mb,
    oper_count,
    last_oper_type,
    last_oper_mode,
    last_oper_time
FROM
    v$sga_dynamic_components
WHERE
    current_size > 0
ORDER BY
    current_size DESC,
    component;

PROMPT
PROMPT SGA Memory Breakdown

SELECT
    pool,
    name,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM
    v$sgastat
WHERE
    bytes >= 1024 * 1024
ORDER BY
    bytes DESC
FETCH FIRST 25 ROWS ONLY;

PROMPT
PROMPT PGA Usage Statistics

SELECT
    name,
    CASE
        WHEN unit = 'bytes' THEN TO_CHAR(ROUND(value / 1024 / 1024, 2))
        ELSE TO_CHAR(value)
    END AS value,
    CASE
        WHEN unit = 'bytes' THEN 'MB'
        ELSE unit
    END AS unit
FROM (
    SELECT
        name,
        value,
        CASE
            WHEN name IN (
                'aggregate PGA target parameter',
                'aggregate PGA auto target',
                'total PGA inuse',
                'total PGA allocated',
                'maximum PGA allocated',
                'total freeable PGA memory',
                'process count'
            )
            THEN CASE
                     WHEN name = 'process count' THEN 'count'
                     ELSE 'bytes'
                 END
            ELSE 'count'
        END AS unit
    FROM
        v$pgastat
    WHERE
        name IN (
            'aggregate PGA target parameter',
            'aggregate PGA auto target',
            'total PGA inuse',
            'total PGA allocated',
            'maximum PGA allocated',
            'total freeable PGA memory',
            'over allocation count',
            'process count'
        )
)
ORDER BY
    CASE name
        WHEN 'aggregate PGA target parameter' THEN 1
        WHEN 'aggregate PGA auto target' THEN 2
        WHEN 'total PGA inuse' THEN 3
        WHEN 'total PGA allocated' THEN 4
        WHEN 'maximum PGA allocated' THEN 5
        WHEN 'total freeable PGA memory' THEN 6
        WHEN 'over allocation count' THEN 7
        WHEN 'process count' THEN 8
        ELSE 9
    END;

PROMPT
PROMPT SGA Target Advisor

SELECT
    ROUND(sga_size, 2) AS sga_size_mb,
    ROUND(sga_size_factor, 2) AS sga_size_factor,
    ROUND(estd_db_time, 2) AS estimated_db_time,
    ROUND(estd_db_time_factor, 4) AS estimated_db_time_factor,
    estd_physical_reads
FROM
    v$sga_target_advice
ORDER BY
    sga_size;

PROMPT
PROMPT PGA Target Advisor

SELECT
    ROUND(pga_target_for_estimate / 1024 / 1024, 2) AS pga_target_mb,
    ROUND(pga_target_factor, 2) AS pga_target_factor,
    ROUND(estd_pga_cache_hit_percentage, 2) AS estimated_cache_hit_pct,
    estd_overalloc_count,
    ROUND(estd_extra_bytes_rw / 1024 / 1024, 2) AS estimated_extra_rw_mb
FROM
    v$pga_target_advice
ORDER BY
    pga_target_for_estimate;

PROMPT
PROMPT Recent Memory Resize Operations

SELECT
    component,
    oper_type,
    oper_mode,
    parameter,
    ROUND(initial_size / 1024 / 1024, 2) AS initial_size_mb,
    ROUND(target_size / 1024 / 1024, 2) AS target_size_mb,
    ROUND(final_size / 1024 / 1024, 2) AS final_size_mb,
    status,
    start_time,
    end_time
FROM (
    SELECT
        component,
        oper_type,
        oper_mode,
        parameter,
        initial_size,
        target_size,
        final_size,
        status,
        start_time,
        end_time
    FROM
        v$memory_resize_ops
    WHERE
        final_size > 0
    ORDER BY
        start_time DESC
)
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT Memory Configuration Inventory Completed
