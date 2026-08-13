# 07 - Maintenance

## Purpose

This module provides read-only reports for reviewing common Oracle Database maintenance conditions.

The scripts help Oracle Database Administrators assess invalid objects, optimizer statistics, recycle bin usage, index maintenance candidates, and Scheduler job issues before any corrective action is taken.

No script in this module automatically modifies database objects, statistics, indexes, recycle bin contents, or Scheduler jobs.

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
| `01_invalid_objects.sql` | Reports invalid objects, compilation errors, and recompilation commands for review. |
| `02_optimizer_statistics.sql` | Reports missing, stale, and locked optimizer statistics for application and Oracle-maintained objects. |
| `03_recyclebin_status.sql` | Reports recycle bin objects, occupied space, and purge commands for review. |
| `04_index_maintenance.sql` | Reports unusable, invisible, domain, partitioned, and statistics-related index maintenance candidates. |
| `05_scheduler_jobs.sql` | Reports application Scheduler job configuration, failures, execution history, and disabled or problematic jobs. |

---

## Execution

Connect as SYSDBA using SQLcl.

```sql
sql / as sysdba
```

Execute any script individually.

```sql
@01_invalid_objects.sql
```

Scripts can also be executed using their full path.

```sql
@/home/oracle/banking_dba_project/07_Maintenance/01_invalid_objects.sql
```

---

## Module Boundaries

This module is limited to maintenance assessment and reporting.

- Generated recompilation commands are displayed for review and are not executed automatically.
- Suggested purge commands are displayed for review only.
- Optimizer statistics are not gathered, deleted, locked, or unlocked.
- Indexes are not rebuilt, altered, enabled, or disabled.
- Scheduler jobs are not started, stopped, modified, enabled, disabled, or dropped.
- Database-wide health monitoring belongs in `08_Monitoring`.
- SQL and instance performance analysis belong in `09_Performance`.

---

## Notes

- All scripts are read-only.
- Generated maintenance commands require manual review before execution.
- Invalid objects may result from dependency issues, missing privileges, compilation errors, or incomplete deployments.
- Missing or stale optimizer statistics do not always require immediate collection.
- Locked optimizer statistics may be intentional.
- Invisible or disabled objects are not automatically considered errors.
- PURGE operations are irreversible and prevent Flashback Drop recovery.
- Scheduler failures should be interpreted together with job configuration, run history, and business requirements.
- Output is optimized for SQLcl using `SET SQLFORMAT ANSICONSOLE`.
- Reports are intended for maintenance assessment and documentation.

---

## Safety

These scripts are intended for maintenance assessment.

Although they do not perform DDL, DML, statistics maintenance, index rebuilds, recycle bin purges, or Scheduler job changes, execution in production environments should follow the organization's operational procedures.

Before executing any generated command, review dependencies, application requirements, backup availability, operational impact, and organization-specific change procedures.

---