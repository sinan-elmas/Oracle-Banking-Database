/*
  Script  : 07_free_space_analysis.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports free-space capacity and free-extent distribution.
  Run As  : SYSDBA
  Usage   : @07_free_space_analysis.sql

  Notes
  -----
  - This script is read-only.
  - Free extent count alone does not prove tablespace fragmentation.
  - Locally managed tablespaces automatically manage extent allocation.
  - Tablespaces without free extents may require capacity review but are not automatically considered unhealthy.
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
PROMPT Tablespace Free Space Summary

SELECT
    df.tablespace_name,
    ROUND(SUM(df.bytes)/1024/1024,2) allocated_mb,
    ROUND(NVL(fs.free_mb,0),2) free_mb,
    ROUND(SUM(df.bytes)/1024/1024-NVL(fs.free_mb,0),2) used_mb,
    ROUND(NVL(fs.largest_free_mb,0),2) largest_free_extent_mb,
    NVL(fs.free_extents,0) free_extent_count
FROM dba_data_files df
LEFT JOIN (
    SELECT tablespace_name,
           SUM(bytes)/1024/1024 free_mb,
           MAX(bytes)/1024/1024 largest_free_mb,
           COUNT(*) free_extents
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
ON df.tablespace_name=fs.tablespace_name
GROUP BY df.tablespace_name,fs.free_mb,fs.largest_free_mb,fs.free_extents
ORDER BY free_mb ASC, tablespace_name;

PROMPT
PROMPT Free Extent Distribution

SELECT
    tablespace_name,
    COUNT(*) free_extent_count,
    ROUND(MAX(bytes)/1024/1024,2) largest_extent_mb,
    ROUND(AVG(bytes)/1024/1024,2) average_extent_mb,
    ROUND(SUM(bytes)/1024/1024,2) total_free_mb
FROM dba_free_space
GROUP BY tablespace_name
ORDER BY free_extent_count DESC,tablespace_name;

PROMPT
PROMPT Tablespaces With No Unallocated Free Extents

SELECT
    tablespace_name
FROM dba_tablespaces
WHERE contents IN ('PERMANENT','UNDO')
MINUS
SELECT DISTINCT
    tablespace_name
FROM dba_free_space;

PROMPT
PROMPT Free Space Analysis Completed
