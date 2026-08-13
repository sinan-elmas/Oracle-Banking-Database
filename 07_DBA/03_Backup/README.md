# 03 - Backup

## Purpose

This module provides read-only reports for evaluating Oracle Database backup readiness, RMAN backup inventory, backup job history, and validation status.

The scripts help Oracle Database Administrators assess backup readiness, review available RMAN backup records, analyze previous backup operations, and identify backup- and block-related corruption before performing backup, restore, or recovery activities.

No script in this module starts, modifies, deletes, crosschecks, or catalogs RMAN backups.

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
| `01_backup_readiness.sql` | Reports ARCHIVELOG mode, FORCE LOGGING, FRA configuration, block change tracking, control file information, and RMAN configuration relevant to backup readiness. |
| `02_backup_inventory.sql` | Reports available RMAN backup sets, backup pieces, datafile backups, SPFILE backups, and related repository information. |
| `03_backup_history.sql` | Reports RMAN backup job history, execution status, duration, input type, processed data, and compression information. |
| `04_backup_validation.sql` | Reports backup corruption, copy corruption, database block corruption, backup status, and validation-related RMAN repository records. |

---

## Execution

Connect as SYSDBA using SQLcl.

```sql
sql / as sysdba
```

Execute any script individually.

```sql
@01_backup_readiness.sql
```

Scripts can also be executed using their full path.

```sql
@/home/oracle/banking_dba_project/03_Backup/01_backup_readiness.sql
```

---

## Repository Scope

The scripts query RMAN metadata stored in the target database control file.

They do not require an external Recovery Catalog and do not use `RC_*` catalog views.

The amount of historical information available depends on the records retained in the control file repository.

---

## Module Boundaries

This module is limited to backup reporting and assessment.

- Executable RMAN backup and maintenance operations belong in `04_RMAN`.
- Restore and recovery analysis belong in `05_Recovery`.
- FRA and archive destination monitoring belong in `08_Monitoring`.

---

## Notes

- All scripts are read-only.
- No backup, restore, recovery, crosscheck, catalog, or delete command is executed.
- All information is collected from the RMAN repository and Oracle data dictionary views.
- Output is optimized for SQLcl using `SET SQLFORMAT ANSICONSOLE`.
- Reports are intended for backup assessment and documentation.
- Results reflect the RMAN repository and database state at execution time.
- A backup record in the repository does not by itself guarantee that its physical backup piece is accessible.
- RMAN validation operations must be executed separately through the scripts in the RMAN module.

---

## Safety

These scripts are intended for backup assessment and repository analysis.

Although they do not perform DDL, DML, or RMAN maintenance operations, execution in production environments should follow the organization's operational procedures.

---