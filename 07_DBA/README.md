# Oracle Database Administration (DBA)

This directory contains the Oracle Database Administration component of the **Oracle Banking Database** project.

The module documents practical DBA work performed in the Oracle Linux laboratory environment. SQL modules are designed for assessment and reporting; the RMAN module contains executable backup and maintenance operations.

## Target Environment

- Oracle Linux 8.10
- Oracle Database 19c Enterprise Edition
- SQLcl
- `SET SQLFORMAT ANSICONSOLE`
- RMAN
- SYSDBA
- ARCHIVELOG mode

## Modules

| Module | Purpose |
|---|---|
| `01_Environment_and_Instance` | Database, instance, parameter, memory, redo, control file, and environment inventory |
| `02_Storage_Management` | Tablespaces, datafiles, tempfiles, UNDO, segments, and free-space analysis |
| `03_Backup` | Backup readiness, RMAN repository inventory, history, and validation reporting |
| `04_RMAN` | Executable RMAN backup, validation, crosscheck, and cleanup jobs |
| `05_Recovery` | Restore readiness, recovery status, corruption reporting, and recovery history |
| `06_Data_Pump` | Data Pump directories, jobs, history, objects, and health assessment |
| `07_Maintenance` | Invalid objects, statistics, recycle bin, indexes, and Scheduler assessment |
| `08_Monitoring` | Database health, storage alerts, FRA, archive destinations, sessions, resources, and alert log |
| `09_Performance` | SQL cache, top SQL, session waits, system waits, and latch/mutex contention |

## Execution Model

SQL scripts are executed with SQLcl as SYSDBA:

```text
sql / as sysdba
SET SQLFORMAT ANSICONSOLE
```

Each SQL module contains its own README with scope and execution notes.

RMAN jobs are executed through:

```text
04_RMAN/run_rman_job.sh
```

The RMAN scripts use operating-system authentication and write backup pieces to the laboratory backup location configured in the command files.

## Safety

- SQL scripts outside the RMAN module are read-only assessment/reporting scripts.
- Some maintenance scripts generate administrative commands for review but do not execute them.
- RMAN backup scripts create physical backup pieces.
- `08_crosscheck_and_cleanup.rman` changes RMAN repository state and can permanently delete obsolete backup files according to the configured retention policy.
- Review environment-specific paths, privileges, retention policy, and operational impact before executing administrative jobs outside the laboratory environment.

## Scope

This module represents the Oracle Database 19c DBA laboratory environment. It is intentionally separate from the Oracle AI Database 26ai application-development environment used by other parts of the project.
