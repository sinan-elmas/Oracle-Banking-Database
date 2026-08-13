# 05 - Recovery

## Purpose

This module provides read-only reports for evaluating Oracle Database restore and recovery readiness, media recovery status, block corruption records, and recovery-related metadata.

The scripts help Oracle Database Administrators assess whether the required backup and recovery information is available before performing restore or recovery operations.

No script in this module performs restore, recovery, validation, or repair operations.

---

## Target Environment

- Oracle Database 19c Enterprise Edition
- Oracle Linux 8.x
- SQLcl
- SQLFORMAT ANSICONSOLE
- SYSDBA privileges
- RMAN control file repository

---

## Module Contents

| Script | Description |
|---------|-------------|
| `01_restore_readiness.sql` | Reports database configuration, backup availability, control file and SPFILE backup records, and information required before restore operations. |
| `02_restore_validation.sql` | Reports backup status and RMAN repository information relevant to restore validation. |
| `03_media_recovery_status.sql` | Reports datafile, datafile header, and media recovery status, including files that may require recovery. |
| `04_block_corruption_report.sql` | Reports database, backup, and image copy block corruption records currently known to Oracle. |
| `05_recovery_history.sql` | Reports database incarnation history, RESETLOGS information, and recovery-related history available from the target database. |

---

## Execution

Connect as SYSDBA using SQLcl.

```sql
sql / as sysdba
```

Execute any script individually.

```sql
@01_restore_readiness.sql
```

Scripts can also be executed using their full path.

```sql
@/home/oracle/banking_dba_project/05_Recovery/01_restore_readiness.sql
```

---

## Repository Scope

The scripts query recovery metadata stored in the target database control file.

They do not require an external Recovery Catalog and do not use `RC_*` catalog views.

The amount of historical information available depends on the records retained in the control file repository.

---

## Module Boundaries

This module is limited to restore and recovery assessment.

- Backup readiness and backup inventory reporting belong in `03_Backup`.
- Executable RMAN backup and validation operations belong in `04_RMAN`.
- Actual restore and recovery procedures must be executed separately in a controlled environment.
- FRA and archive destination monitoring belong in `08_Monitoring`.

---

## Notes

- All scripts are read-only.
- No restore, recover, validate, catalog, crosscheck, or repair command is executed.
- All information is collected from the RMAN repository, Oracle data dictionary, and dynamic performance views.
- Output is optimized for SQLcl using `SET SQLFORMAT ANSICONSOLE`.
- Reports are intended for restore and recovery assessment.
- Results reflect the current database and RMAN repository state at execution time.
- An available repository record does not guarantee that the associated physical backup piece is accessible.
- Empty corruption views indicate that Oracle currently has no recorded corruption entries; they do not replace periodic validation.

---

## Safety

These scripts are intended for restore and recovery assessment.

Although they do not perform DDL, DML, RMAN restore, recovery, or repair operations, execution in production environments should follow the organization's operational procedures.

Before executing any actual recovery procedure, verify backup availability, recovery objectives, database state, required archived redo logs, and organization-specific operational procedures.

---