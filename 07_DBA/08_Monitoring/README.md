# 08 - Monitoring

## Purpose

This module provides read-only operational monitoring reports for Oracle Database.

The scripts help Oracle Database Administrators assess database health, storage alerts, Fast Recovery Area usage, archive destination status, blocking sessions, long-running activity, resource limits, and recent alert log messages.

No script in this module modifies database configuration, sessions, jobs, or database objects.

---

## Target Environment

- Oracle Database 19c Enterprise Edition
- Oracle Linux 8.x
- SQLcl
- SQLFORMAT ANSICONSOLE
- SYSDBA privileges
- Single-instance database, with selected `GV$` views retained for portability

---

## Module Contents

| Script | Description |
|---------|-------------|
| `01_database_health_check.sql` | Provides a consolidated overview of database, instance, storage, backup, object, and Scheduler health indicators. |
| `02_tablespace_alerts.sql` | Reports permanent, temporary, and UNDO tablespace utilization with alert-oriented status indicators. |
| `03_fra_usage.sql` | Reports FRA capacity, current usage, reclaimable space, and recovery-area file type distribution. |
| `04_archive_destination_status.sql` | Reports ARCHIVELOG mode, archive destinations, archived redo generation, and destination errors. |
| `05_blocking_sessions.sql` | Reports blocking and blocked sessions, lock relationships, transactions, and related SQL information. |
| `06_long_running_sessions.sql` | Reports currently active sessions exceeding the execution-time threshold defined in the script. |
| `07_resource_limit_alerts.sql` | Reports current and peak use of configured Oracle resource limits with alert-oriented utilization status. |
| `08_alert_log_summary.sql` | Reports recent warning, error, and critical messages available through `V$DIAG_ALERT_EXT`. |

---

## Execution

Connect as SYSDBA using SQLcl.

```sql
sql / as sysdba
```

Execute any script individually.

```sql
@01_database_health_check.sql
```

Scripts can also be executed using their full path.

```sql
@/home/oracle/banking_dba_project/08_Monitoring/01_database_health_check.sql
```

---

## Monitoring Scope

The scripts report the current database state using Oracle data dictionary and dynamic performance views.

This module does not provide complete long-term history. Current session, lock, wait, capacity, and resource-limit information may change immediately after execution.

AWR, ASH, ADDM, and `DBA_HIST_*` dependencies are intentionally excluded from this module.

---

## Module Boundaries

This module is limited to operational monitoring and alert-oriented reporting.

- Detailed storage inventory and free-space analysis belong in `02_Storage_Management`.
- Backup inventory and backup history belong in `03_Backup`.
- Maintenance assessment belongs in `07_Maintenance`.
- SQL workload and wait-event analysis belong in `09_Performance`.
- Operating-system monitoring is outside the scope of these SQL scripts.

---

## Notes

- All scripts are read-only.
- No session is killed or disconnected.
- No Scheduler job is started, stopped, enabled, disabled, or modified.
- No tablespace, datafile, archive destination, Fast Recovery Area configuration, or initialization parameter is changed.
- `GV$` views may return one row per instance in RAC environments.
- Empty blocking-session results indicate that no matching blocking relationship exists at execution time.
- Alert log results are limited to records exposed through `V$DIAG_ALERT_EXT`.
- Output is optimized for SQLcl using `SET SQLFORMAT ANSICONSOLE`.
- Reports are intended for operational monitoring and documentation.

---

## Safety

These scripts are intended for operational monitoring.

Although they do not perform DDL, DML, session control, or configuration changes, execution in production environments should follow the organization's operational procedures.

Before execution in production environments, review required privileges, query cost, alert thresholds, monitoring frequency, and organization-specific operational procedures.

---