# 02 - Storage Management

## Purpose

This module provides a read-only overview of Oracle Database storage configuration and space utilization.

The scripts in this directory help Oracle Database Administrators assess the current storage layout, datafile configuration, temporary storage, UNDO usage, segment distribution, and available free space before performing capacity planning, storage maintenance, or troubleshooting.

No script in this module modifies the database.

---

## Target Environment

- Oracle Database 19c Enterprise Edition
- Oracle Linux 8.x
- SQLcl
- SQLFORMAT ANSICONSOLE
- SYSDBA privileges

---

## Module Contents

| Script | Description |
|---------|-------------|
| 01_tablespace_overview.sql | Reports permanent, temporary, and UNDO tablespace configuration. |
| 02_datafile_inventory.sql | Reports permanent and UNDO datafiles, autoextend settings, and storage allocation. |
| 03_tempfile_inventory.sql | Reports temporary tablespaces, tempfiles, and autoextend configuration. |
| 04_undo_management.sql | Reports UNDO configuration, retention settings, extent usage, and active transactions. |
| 05_tablespace_usage.sql | Reports allocated space, configured capacity, and tablespace utilization. |
| 06_segment_inventory.sql | Reports segment distribution and the largest database segments. |
| 07_free_space_analysis.sql | Reports free-space capacity and free-extent distribution across tablespaces. |

---

## Execution

Connect as SYSDBA using SQLcl.

```sql
sql / as sysdba
```

Execute any script individually.

```sql
@05_tablespace_usage.sql
```

---

## Notes

- All scripts are read-only.
- No database objects are modified.
- All information is collected from Oracle data dictionary and dynamic performance views.
- Output is optimized for SQLcl using `SET SQLFORMAT ANSICONSOLE`.
- Reports are intended for storage assessment and capacity planning.
- Storage utilization reflects the current database state at execution time.
- Locally managed tablespaces automatically manage extent allocation; free extents alone should not be interpreted as fragmentation.

---

## Safety

These scripts are intended for storage assessment and capacity analysis.

Although they do not perform any DDL or DML operations, execution in production environments should follow the organization's operational procedures.

---