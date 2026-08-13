/*
  Script  : 04_index_maintenance.sql
  Project : Oracle Banking Database - DBA Lab
  Purpose : Reports index availability, visibility, domain index status,
            partition status, and statistics maintenance candidates.
  Run As  : SYSDBA
  Usage   : @04_index_maintenance.sql

  Notes
  -----
  - This script is read-only.
  - It does not rebuild, modify, enable, disable, or alter indexes.
  - Index rebuild decisions must not be based only on BLEVEL,
    CLUSTERING_FACTOR, size, or age.
  - Oracle-generated LOB indexes are excluded from normal application
    statistics maintenance assessment.
*/

SET SQLFORMAT ANSICONSOLE
SET PAGESIZE 200
SET LINESIZE 380
SET FEEDBACK ON
SET VERIFY OFF
SET HEADING ON
SET TRIMSPOOL ON
SET TAB OFF
SET SQLBLANKLINES ON

PROMPT
PROMPT Unusable Application Indexes

SELECT
    i.owner,
    i.index_name,
    i.table_owner,
    i.table_name,
    i.index_type,
    i.partitioned,
    i.status,
    i.visibility,
    i.tablespace_name,
    TO_CHAR(i.last_analyzed, 'DD-MON-YYYY HH24:MI:SS') AS last_analyzed,
    'REVIEW INDEX AVAILABILITY AND REBUILD ONLY IF REQUIRED'
        AS maintenance_assessment
FROM
    dba_indexes i
    JOIN dba_users u
        ON u.username = i.owner
WHERE
    u.oracle_maintained = 'N'
    AND i.temporary = 'N'
    AND i.status = 'UNUSABLE'
ORDER BY
    i.owner,
    i.table_name,
    i.index_name;

PROMPT
PROMPT Unusable Application Index Partitions

SELECT
    p.index_owner AS owner,
    p.index_name,
    p.partition_name,
    p.status,
    p.tablespace_name,
    TO_CHAR(p.last_analyzed, 'DD-MON-YYYY HH24:MI:SS') AS last_analyzed,
    'REVIEW PARTITION AVAILABILITY AND REBUILD ONLY IF REQUIRED'
        AS maintenance_assessment
FROM
    dba_ind_partitions p
    JOIN dba_users u
        ON u.username = p.index_owner
WHERE
    u.oracle_maintained = 'N'
    AND p.status = 'UNUSABLE'
ORDER BY
    p.index_owner,
    p.index_name,
    p.partition_position;

PROMPT
PROMPT Unusable Application Index Subpartitions

SELECT
    sp.index_owner AS owner,
    sp.index_name,
    sp.partition_name,
    sp.subpartition_name,
    sp.status,
    sp.tablespace_name,
    TO_CHAR(sp.last_analyzed, 'DD-MON-YYYY HH24:MI:SS') AS last_analyzed,
    'REVIEW SUBPARTITION AVAILABILITY AND REBUILD ONLY IF REQUIRED'
        AS maintenance_assessment
FROM
    dba_ind_subpartitions sp
    JOIN dba_users u
        ON u.username = sp.index_owner
WHERE
    u.oracle_maintained = 'N'
    AND sp.status = 'UNUSABLE'
ORDER BY
    sp.index_owner,
    sp.index_name,
    sp.partition_name,
    sp.subpartition_position;

PROMPT
PROMPT Invisible Application Indexes

SELECT
    i.owner,
    i.index_name,
    i.table_owner,
    i.table_name,
    i.index_type,
    i.status,
    i.visibility,
    i.partitioned,
    TO_CHAR(i.last_analyzed, 'DD-MON-YYYY HH24:MI:SS') AS last_analyzed,
    'INFORMATIONAL - CONFIRM INVISIBILITY IS INTENTIONAL'
        AS maintenance_assessment
FROM
    dba_indexes i
    JOIN dba_users u
        ON u.username = i.owner
WHERE
    u.oracle_maintained = 'N'
    AND i.temporary = 'N'
    AND i.visibility = 'INVISIBLE'
ORDER BY
    i.owner,
    i.table_name,
    i.index_name;

PROMPT
PROMPT Domain Indexes Requiring Review

SELECT
    i.owner,
    i.index_name,
    i.table_owner,
    i.table_name,
    i.index_type,
    i.status,
    i.domidx_status,
    i.domidx_opstatus,
    'REVIEW DOMAIN INDEX IMPLEMENTATION AND ERROR STATE'
        AS maintenance_assessment
FROM
    dba_indexes i
    JOIN dba_users u
        ON u.username = i.owner
WHERE
    u.oracle_maintained = 'N'
    AND i.temporary = 'N'
    AND i.index_type LIKE 'DOMAIN%'
    AND (
           NVL(i.domidx_status, 'VALID') <> 'VALID'
        OR NVL(i.domidx_opstatus, 'VALID') <> 'VALID'
        OR i.status = 'UNUSABLE'
    )
ORDER BY
    i.owner,
    i.table_name,
    i.index_name;

PROMPT
PROMPT Application Index Statistics Maintenance Candidates

SELECT
    s.owner,
    s.index_name,
    s.table_owner,
    s.table_name,
    s.object_type,
    s.partition_name,
    s.subpartition_name,
    s.stale_stats,
    s.stattype_locked,
    TO_CHAR(s.last_analyzed, 'DD-MON-YYYY HH24:MI:SS') AS last_analyzed,
    CASE
        WHEN s.stattype_locked IS NOT NULL
         AND s.last_analyzed IS NULL
        THEN 'LOCKED WITH MISSING STATISTICS'
        WHEN s.stattype_locked IS NOT NULL
         AND s.stale_stats = 'YES'
        THEN 'LOCKED WITH STALE STATISTICS'
        WHEN s.last_analyzed IS NULL
        THEN 'MISSING STATISTICS'
        WHEN s.stale_stats = 'YES'
        THEN 'STALE STATISTICS'
        ELSE 'LOCKED - INFORMATIONAL'
    END AS maintenance_assessment
FROM
    dba_ind_statistics s
    JOIN dba_users u
        ON u.username = s.owner
    JOIN dba_indexes i
        ON i.owner = s.owner
       AND i.index_name = s.index_name
WHERE
    u.oracle_maintained = 'N'
    AND i.temporary = 'N'
    AND i.generated = 'N'
    AND i.index_type <> 'LOB'
    AND i.index_name NOT LIKE 'SYS\_IL%' ESCAPE '\'
    AND (
           s.last_analyzed IS NULL
        OR s.stale_stats = 'YES'
        OR s.stattype_locked IS NOT NULL
    )
ORDER BY
    s.owner,
    s.table_name,
    s.index_name,
    s.object_type,
    s.partition_name,
    s.subpartition_name;

PROMPT
PROMPT Index Maintenance Summary By Owner

WITH index_base AS (
    SELECT
        i.owner,
        i.index_name,
        i.status,
        i.visibility,
        i.index_type,
        i.domidx_status,
        i.domidx_opstatus
    FROM
        dba_indexes i
        JOIN dba_users u
            ON u.username = i.owner
    WHERE
        u.oracle_maintained = 'N'
        AND i.temporary = 'N'
),
partition_state AS (
    SELECT
        p.index_owner AS owner,
        COUNT(*) AS unusable_partition_count
    FROM
        dba_ind_partitions p
        JOIN dba_users u
            ON u.username = p.index_owner
    WHERE
        u.oracle_maintained = 'N'
        AND p.status = 'UNUSABLE'
    GROUP BY
        p.index_owner
),
subpartition_state AS (
    SELECT
        sp.index_owner AS owner,
        COUNT(*) AS unusable_subpartition_count
    FROM
        dba_ind_subpartitions sp
        JOIN dba_users u
            ON u.username = sp.index_owner
    WHERE
        u.oracle_maintained = 'N'
        AND sp.status = 'UNUSABLE'
    GROUP BY
        sp.index_owner
),
statistics_state AS (
    SELECT
        s.owner,
        NVL(
            SUM(
                CASE
                    WHEN s.last_analyzed IS NULL THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS missing_statistics_count,
        NVL(
            SUM(
                CASE
                    WHEN s.stale_stats = 'YES' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS stale_statistics_count,
        NVL(
            SUM(
                CASE
                    WHEN s.stattype_locked IS NOT NULL THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS locked_statistics_count
    FROM
        dba_ind_statistics s
        JOIN dba_users u
            ON u.username = s.owner
        JOIN dba_indexes i
            ON i.owner = s.owner
           AND i.index_name = s.index_name
    WHERE
        u.oracle_maintained = 'N'
        AND i.temporary = 'N'
        AND i.generated = 'N'
        AND i.index_type <> 'LOB'
        AND i.index_name NOT LIKE 'SYS\_IL%' ESCAPE '\'
    GROUP BY
        s.owner
)
SELECT
    b.owner,
    COUNT(*) AS index_count,
    NVL(
        SUM(
            CASE
                WHEN b.status = 'UNUSABLE' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS unusable_index_count,
    NVL(p.unusable_partition_count, 0) AS unusable_partition_count,
    NVL(sp.unusable_subpartition_count, 0) AS unusable_subpartition_count,
    NVL(
        SUM(
            CASE
                WHEN b.visibility = 'INVISIBLE' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS invisible_index_count,
    NVL(
        SUM(
            CASE
                WHEN b.index_type LIKE 'DOMAIN%'
                 AND (
                        NVL(b.domidx_status, 'VALID') <> 'VALID'
                     OR NVL(b.domidx_opstatus, 'VALID') <> 'VALID'
                     OR b.status = 'UNUSABLE'
                 )
                THEN 1
                ELSE 0
            END
        ),
        0
    ) AS domain_index_review_count,
    NVL(st.missing_statistics_count, 0) AS missing_statistics_count,
    NVL(st.stale_statistics_count, 0) AS stale_statistics_count,
    NVL(st.locked_statistics_count, 0) AS locked_statistics_count
FROM
    index_base b
    LEFT JOIN partition_state p
        ON p.owner = b.owner
    LEFT JOIN subpartition_state sp
        ON sp.owner = b.owner
    LEFT JOIN statistics_state st
        ON st.owner = b.owner
GROUP BY
    b.owner,
    p.unusable_partition_count,
    sp.unusable_subpartition_count,
    st.missing_statistics_count,
    st.stale_statistics_count,
    st.locked_statistics_count
ORDER BY
    b.owner;

PROMPT
PROMPT Index Maintenance Status Summary

WITH unusable_indexes AS (
    SELECT
        COUNT(*) AS issue_count
    FROM
        dba_indexes i
        JOIN dba_users u
            ON u.username = i.owner
    WHERE
        u.oracle_maintained = 'N'
        AND i.temporary = 'N'
        AND i.status = 'UNUSABLE'
),
unusable_partitions AS (
    SELECT
        COUNT(*) AS issue_count
    FROM
        dba_ind_partitions p
        JOIN dba_users u
            ON u.username = p.index_owner
    WHERE
        u.oracle_maintained = 'N'
        AND p.status = 'UNUSABLE'
),
unusable_subpartitions AS (
    SELECT
        COUNT(*) AS issue_count
    FROM
        dba_ind_subpartitions sp
        JOIN dba_users u
            ON u.username = sp.index_owner
    WHERE
        u.oracle_maintained = 'N'
        AND sp.status = 'UNUSABLE'
),
invisible_indexes AS (
    SELECT
        COUNT(*) AS informational_count
    FROM
        dba_indexes i
        JOIN dba_users u
            ON u.username = i.owner
    WHERE
        u.oracle_maintained = 'N'
        AND i.temporary = 'N'
        AND i.visibility = 'INVISIBLE'
),
domain_index_issues AS (
    SELECT
        COUNT(*) AS issue_count
    FROM
        dba_indexes i
        JOIN dba_users u
            ON u.username = i.owner
    WHERE
        u.oracle_maintained = 'N'
        AND i.temporary = 'N'
        AND i.index_type LIKE 'DOMAIN%'
        AND (
               NVL(i.domidx_status, 'VALID') <> 'VALID'
            OR NVL(i.domidx_opstatus, 'VALID') <> 'VALID'
            OR i.status = 'UNUSABLE'
        )
),
statistics_issues AS (
    SELECT
        NVL(
            SUM(
                CASE
                    WHEN s.last_analyzed IS NULL THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS missing_statistics_count,
        NVL(
            SUM(
                CASE
                    WHEN s.stale_stats = 'YES' THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS stale_statistics_count,
        NVL(
            SUM(
                CASE
                    WHEN s.stattype_locked IS NOT NULL
                     AND (
                            s.last_analyzed IS NULL
                         OR s.stale_stats = 'YES'
                     )
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS locked_attention_count
    FROM
        dba_ind_statistics s
        JOIN dba_users u
            ON u.username = s.owner
        JOIN dba_indexes i
            ON i.owner = s.owner
           AND i.index_name = s.index_name
    WHERE
        u.oracle_maintained = 'N'
        AND i.temporary = 'N'
        AND i.generated = 'N'
        AND i.index_type <> 'LOB'
        AND i.index_name NOT LIKE 'SYS\_IL%' ESCAPE '\'
)
SELECT
    ui.issue_count AS unusable_index_count,
    up.issue_count AS unusable_partition_count,
    usp.issue_count AS unusable_subpartition_count,
    ii.informational_count AS invisible_index_count,
    di.issue_count AS domain_index_review_count,
    si.missing_statistics_count,
    si.stale_statistics_count,
    si.locked_attention_count,
    CASE
        WHEN ui.issue_count > 0
          OR up.issue_count > 0
          OR usp.issue_count > 0
          OR di.issue_count > 0
        THEN 'IMMEDIATE REVIEW REQUIRED'
        WHEN si.missing_statistics_count > 0
          OR si.stale_statistics_count > 0
          OR si.locked_attention_count > 0
        THEN 'STATISTICS MAINTENANCE REQUIRED'
        WHEN ii.informational_count > 0
        THEN 'INVISIBLE INDEXES RECORDED'
        ELSE 'HEALTHY'
    END AS index_maintenance_state
FROM
    unusable_indexes ui
    CROSS JOIN unusable_partitions up
    CROSS JOIN unusable_subpartitions usp
    CROSS JOIN invisible_indexes ii
    CROSS JOIN domain_index_issues di
    CROSS JOIN statistics_issues si;

PROMPT
PROMPT Index Maintenance Inventory Completed
