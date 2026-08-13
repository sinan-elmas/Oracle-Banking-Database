/*
  Script  : 06_segment_inventory.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports segment distribution and the largest database segments.
  Run As  : SYSDBA
  Usage   : @06_segment_inventory.sql

  Notes
  -----
  - This script is read-only.
  - Database-wide results include Oracle-maintained schemas.
  - BANKING_DB results are reported separately for application analysis.
  - Segment size alone does not indicate a performance problem.
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
PROMPT Segment Summary By Type

SELECT
    segment_type,
    COUNT(*) AS segment_count,
    ROUND(SUM(bytes) / 1024 / 1024, 2) AS total_size_mb
FROM
    dba_segments
GROUP BY
    segment_type
ORDER BY
    total_size_mb DESC,
    segment_type;

PROMPT
PROMPT Largest Segments

SELECT
    owner,
    segment_name,
    segment_type,
    tablespace_name,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM
    dba_segments
ORDER BY
    bytes DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT Segment Distribution By Tablespace

SELECT
    tablespace_name,
    COUNT(*) AS segment_count,
    ROUND(SUM(bytes) / 1024 / 1024, 2) AS total_size_mb
FROM
    dba_segments
GROUP BY
    tablespace_name
ORDER BY
    total_size_mb DESC,
    tablespace_name;

PROMPT
PROMPT BANKING_DB Segment Summary

SELECT
    segment_type,
    COUNT(*) AS segment_count,
    ROUND(SUM(bytes) / 1024 / 1024, 2) AS total_size_mb
FROM
    dba_segments
WHERE
    owner = 'BANKING_DB'
GROUP BY
    segment_type
ORDER BY
    total_size_mb DESC,
    segment_type;

PROMPT
PROMPT BANKING_DB Largest Segments

SELECT
    segment_name,
    segment_type,
    tablespace_name,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM
    dba_segments
WHERE
    owner = 'BANKING_DB'
ORDER BY
    bytes DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT Segment Inventory Completed
