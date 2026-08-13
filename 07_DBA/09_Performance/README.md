# 09 - Performance

## Purpose

This module provides read-only Oracle Database performance reports based on current dynamic performance views.

The scripts help Oracle Database Administrators assess SQL cache behavior, identify resource-intensive SQL statements, analyze active session waits, examine cumulative system wait events, and investigate latch or mutex contention indicators.

No script in this module modifies SQL plans, statistics, initialization parameters, sessions, or database objects.

---

## Target Environment

- Oracle Database 19c Enterprise Edition
- Oracle Linux 8.x
- SQLcl
- SQLFORMAT ANSICONSOLE
- SYSDBA privileges
- Single-instance database

---

## Module Contents

| Script | Description |
|---------|-------------|
| `01_sql_cache_overview.sql` | Reports shared SQL area, shared pool, library cache, parsing, reload, invalidation, and cursor version indicators. |
| `02_top_sql_by_cpu.sql` | Reports SQL statements with the highest cumulative and per-execution CPU consumption. |
| `03_top_sql_by_elapsed_time.sql` | Reports SQL statements with the highest cumulative and per-execution elapsed time. |
| `04_top_sql_by_buffer_gets.sql` | Reports SQL statements with the highest cumulative and per-execution logical I/O. |
| `05_top_sql_by_disk_reads.sql` | Reports SQL statements with the highest cumulative and per-execution physical read activity. |
| `06_active_session_waits.sql` | Reports active foreground sessions, non-idle waits, recent in-memory wait history, SQL context, and blocking information. |
| `07_system_wait_events.sql` | Reports cumulative foreground wait events and wait-class activity at the instance level. |
| `08_latch_and_mutex_contention.sql` | Reports cumulative latch and mutex contention indicators and recent mutex sleep history. |

---

## Execution

Connect as SYSDBA using SQLcl.

```sql
sql / as sysdba
```

Execute any script individually.

```sql
@02_top_sql_by_cpu.sql
```

Scripts can also be executed using their full path.

```sql
@/home/oracle/banking_dba_project/09_Performance/02_top_sql_by_cpu.sql
```

---

## Metric Scope

The reports use current Oracle dynamic performance views such as `V$SQL`, `V$SQLAREA`, `V$SESSION`, `V$SYSTEM_EVENT`, and `V$LATCH`.

Most reported values are cumulative rather than fixed-period measurements.

`V$SQL` and `V$SQLAREA` metrics remain available while cursors stay in the shared SQL area. Values may disappear or reset because of:

- Instance restart
- Cursor aging
- Cursor invalidation
- Shared pool flushing
- Child cursor replacement

System wait, latch, and mutex values are generally cumulative since instance startup unless the related structure is a limited in-memory history.

---

## Workload Scope

The primary SQL and session reports focus on foreground application workload.

Oracle-maintained foreground activity is not silently discarded. Where relevant, it is reported separately so that Scheduler, AutoTask, `DBMS_STATS`, or other internal workloads can still be investigated.

Background processes and idle waits are excluded from primary application workload reports unless their inclusion is explicitly relevant.

The reports include context such as:

- `SQL_ID`
- `PLAN_HASH_VALUE`
- Parsing schema
- Module and action
- Execution count
- Total metric
- Metric per execution
- Rows processed
- Last active time
- Limited SQL text

Current session program information represents the current execution context only and must not be interpreted as historical attribution.

---

## Diagnostics Pack Scope

This module does not query:

- `DBA_HIST_*`
- `V$ACTIVE_SESSION_HISTORY`
- AWR
- ASH
- ADDM
- SQL Tuning Advisor

It also does not call:

- `DBMS_WORKLOAD_REPOSITORY`
- `DBMS_ADVISOR`
- `DBMS_SQLTUNE`

The default module therefore avoids direct dependencies on Oracle Diagnostics Pack and Tuning Pack features.

This does not constitute a licensing determination. Oracle licensing requirements must be evaluated according to the organization's contracts, database configuration, and actual feature usage.

---

## Interpretation Notes

- High cumulative resource consumption may result from frequent execution rather than one inefficient execution.
- Total and per-execution metrics should be reviewed together.
- High elapsed time does not necessarily indicate CPU pressure; wait time may contribute significantly.
- High buffer gets indicate logical I/O, not physical disk reads.
- High disk reads may reflect workload volume, cache state, access path, or storage behavior.
- Nonzero waits, latch misses, or mutex sleeps do not independently prove a current bottleneck.
- Performance conclusions should be based on repeated observations, workload context, instance uptime, execution plans, and application behavior.
- The first period after instance startup may represent cache warm-up and should be interpreted cautiously.

---

## Module Boundaries

This module is limited to read-only SQL and instance performance reporting.

- Query rewrites and application-specific tuning belong in the project's main performance section.
- Storage capacity reporting belongs in `02_Storage_Management`.
- Current operational monitoring belongs in `08_Monitoring`.
- Statistics maintenance belongs in `07_Maintenance`.
- AWR, ASH, ADDM, and licensed advisor workflows are intentionally outside the scope of this module.

---

## Notes

- All scripts are read-only.
- SQL text is intentionally limited to preserve readable terminal output.
- No execution plan, SQL profile, SQL patch, SQL baseline, statistic, parameter, session, or database object is modified.
- Output is optimized for SQLcl using `SET SQLFORMAT ANSICONSOLE`.
- Reports are intended for performance assessment and documentation.
- Results reflect the current shared-memory and instance state.
- Empty results do not prove the absence of historical performance issues.

---

## Safety

These scripts are intended for performance assessment.

Although they do not perform DDL, DML, session control, statistics collection, cache flushing, or tuning changes, execution in production environments should follow the organization's operational procedures.

Dynamic performance view queries can still consume database resources. Before frequent or automated execution in production environments, review query cost, reporting frequency, required privileges, and organization-specific operational procedures.

---