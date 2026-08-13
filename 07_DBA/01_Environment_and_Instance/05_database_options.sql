/*
  Script  : 05_database_options.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports Oracle Database options, features, and installed capabilities.
  Run As  : SYSDBA
  Usage   : @05_database_options.sql

  Notes
  -----
  - This script is read-only.
  - An enabled option does not by itself confirm licensing entitlement.
  - Feature availability may vary by edition and patch level.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 220
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF

PROMPT
PROMPT Key Database Options

SELECT
    parameter,
    value
FROM
    v$option
WHERE
    parameter IN (
        'Active Data Guard',
        'Advanced Analytics',
        'Advanced Compression',
        'Automatic Storage Management',
        'Backup Encryption',
        'Block Change Tracking',
        'Block Media Recovery',
        'Data Guard',
        'Data Redaction',
        'Database resource manager',
        'Fine-grained Auditing',
        'Flashback Database',
        'Flashback Data Archive',
        'In-Memory Column Store',
        'Oracle Data Guard',
        'Oracle Database Vault',
        'Oracle Label Security',
        'Parallel execution',
        'Partitioning',
        'Real Application Clusters',
        'Real Application Testing',
        'SQL Plan Management',
        'SecureFiles Encryption',
        'Transparent Data Encryption',
        'Unified Auditing'
    )
ORDER BY
    parameter;

PROMPT
PROMPT Installed Components

SELECT comp_name,
       version,
       status
FROM dba_registry
ORDER BY comp_name;

PROMPT
PROMPT Registry SQL Patch History

SELECT patch_id,
       patch_type,
       action,
       status,
       TO_CHAR(action_time,'DD-MON-YYYY HH24:MI:SS') action_time,
       description
FROM dba_registry_sqlpatch
ORDER BY action_time DESC;

PROMPT
PROMPT Currently Used Database Features

SELECT
    name,
    detected_usages,
    currently_used,
    TO_CHAR(last_usage_date, 'DD-MON-YYYY') AS last_usage_date
FROM
    dba_feature_usage_statistics
WHERE
    currently_used = 'TRUE'
ORDER BY
    name;

PROMPT
PROMPT Database Time Zone

SELECT dbtimezone AS db_timezone,
       sessiontimezone AS session_timezone
FROM dual;

PROMPT
PROMPT Database Options Inventory Completed
