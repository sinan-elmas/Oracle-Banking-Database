# 01 - Environment and Instance

## Purpose

This module provides a read-only overview of the Oracle Database environment and instance configuration.

The scripts in this directory help Oracle Database Administrators assess the current database environment before performing administration, troubleshooting, maintenance, backup, recovery, or performance analysis.

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
| 01_environment_inventory.sql | Reports overall database environment, instance information, memory configuration, storage summary, services, and BANKING_DB object statistics. |
| 02_instance_parameters.sql | Reports important initialization parameters and current instance configuration. |
| 03_memory_configuration.sql | Reports SGA, PGA, memory advisors, and memory-related configuration. |
| 04_processes_sessions.sql | Reports process limits, session activity, waits, and blocking sessions. |
| 05_database_options.sql | Reports installed Oracle Database options and feature availability. |
| 06_registry_components.sql | Reports Oracle registry components and SQL patch inventory. |
| 07_redo_log_configuration.sql | Reports redo log groups, members, log switches, and archive configuration. |
| 08_controlfile_information.sql | Reports control file configuration and record section usage. |
| 09_database_properties.sql | Reports database properties, NLS configuration, time zone, and compatibility information. |

---

## Execution

Connect as SYSDBA using SQLcl.

```sql
sql / as sysdba
```

Execute any script individually.

```sql
@01_environment_inventory.sql
```

---

## Notes

- All scripts are read-only.
- No database objects are modified.
- All information is collected from Oracle data dictionary and dynamic performance views.
- Output is optimized for SQLcl using `SET SQLFORMAT ANSICONSOLE`.
- Reports are intended for environment assessment and documentation.
- Results represent the current state of the database at execution time.

---

## Safety

These scripts are intended for environment inspection and health assessment.

Although they do not perform any DDL or DML operations, execution in production environments should follow the organization's operational procedures.

---