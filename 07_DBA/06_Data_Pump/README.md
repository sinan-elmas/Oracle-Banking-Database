# 06 - Data Pump

## Purpose

This module provides read-only reports for reviewing Oracle Data Pump configuration, active jobs, related database objects, directory access, and operational health.

The scripts help Oracle Database Administrators assess whether the Data Pump environment is correctly configured and identify active, incomplete, or potentially problematic Data Pump jobs.

No script in this module starts, stops, attaches to, or modifies a Data Pump job.

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
| `01_directory_objects.sql` | Reports Oracle DIRECTORY objects and related READ or WRITE privileges. |
| `02_active_jobs.sql` | Reports active Data Pump jobs and associated Data Pump sessions. |
| `03_job_history.sql` | Reports Data Pump job information that remains available in database metadata. |
| `04_datapump_objects.sql` | Reports Data Pump master tables, external tables, and related database objects. |
| `05_datapump_health_check.sql` | Provides a consolidated read-only assessment of Data Pump configuration and operational status. |

---

## Execution

Connect as SYSDBA using SQLcl.

```sql
sql / as sysdba
```

Execute any script individually.

```sql
@01_directory_objects.sql
```

Scripts can also be executed using their full path.

```sql
@/home/oracle/banking_dba_project/06_Data_Pump/01_directory_objects.sql
```

---

## Data Pump History Limitations

Oracle Database does not maintain a complete permanent history of all Data Pump export and import jobs in a single data dictionary view.

Available information depends on:

- Active or retained Data Pump master tables.
- Current `DBA_DATAPUMP_JOBS` metadata.
- Existing external tables or related objects.
- Export and import log files stored outside the database.

The reports in this module describe currently available database metadata and should not be considered a complete historical record.

---

## Module Boundaries

This module is limited to Data Pump reporting and assessment.

- Actual `expdp` and `impdp` commands are executed outside SQLcl.
- Data Pump migration procedures and command examples belong in separate documentation.
- Operating-system directory permissions must be verified at the Oracle Linux level.
- Database DIRECTORY privileges do not guarantee physical filesystem access.

---

## Notes

- All scripts are read-only.
- No Data Pump job is started, stopped, attached, or modified.
- Oracle DIRECTORY objects represent database-level path mappings.
- Filesystem paths and permissions must also be validated at the operating-system level.
- Output is optimized for SQLcl using `SET SQLFORMAT ANSICONSOLE`.
- Reports are intended for Data Pump environment assessment and documentation.
- Results reflect the current database state at execution time.

---

## Safety

These scripts are intended for Data Pump environment assessment.

Although they do not perform DDL, DML, export, import, attach, stop, or kill operations, execution in production environments should follow the organization's operational procedures.

Before running Data Pump operations in production environments, verify directory permissions, available filesystem capacity, schema scope, tablespace mappings, version compatibility, and organization-specific operational procedures.

---