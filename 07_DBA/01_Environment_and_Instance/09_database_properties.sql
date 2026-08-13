/*
  Script  : 09_database_properties.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports core database properties and NLS configuration.
  Run As  : SYSDBA
  Usage   : @09_database_properties.sql

  Notes
  -----
  - This script is read-only.
  - Property and NLS values reflect the current database configuration.
  - Session-level NLS settings may differ from database-level values.
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
PROMPT Core Database Properties

SELECT property_name,
       property_value
FROM database_properties
WHERE property_name IN (
    'DEFAULT_PERMANENT_TABLESPACE',
    'DEFAULT_TEMP_TABLESPACE',
    'DEFAULT_TBS_TYPE',
    'DEFAULT_EDITION',
    'NLS_CHARACTERSET',
    'NLS_NCHAR_CHARACTERSET',
    'DBTIMEZONE'
)
ORDER BY property_name;

PROMPT
PROMPT Database Initialization Properties

SELECT name,
       value
FROM v$parameter
WHERE name IN (
    'compatible',
    'db_block_size',
    'db_name',
    'db_unique_name',
    'open_cursors',
    'processes',
    'sessions'
)
ORDER BY name;

PROMPT
PROMPT NLS Database Parameters

SELECT parameter,
       value
FROM nls_database_parameters
ORDER BY parameter;

PROMPT
PROMPT NLS Instance Parameters

SELECT parameter,
       value
FROM nls_instance_parameters
ORDER BY parameter;

PROMPT
PROMPT NLS Session Parameters

SELECT parameter,
       value
FROM nls_session_parameters
ORDER BY parameter;

PROMPT
PROMPT Database Time Zone

SELECT dbtimezone AS db_timezone,
       sessiontimezone AS session_timezone
FROM dual;

PROMPT
PROMPT Database Properties Inventory Completed
