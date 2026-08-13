# PL/SQL Performance Assessment

## Purpose

This document records the PL/SQL performance assessment for the Oracle Banking Database project.

The assessment is based on evidence collected by the PL/SQL performance review scripts. Its purpose is to document the current runtime observations without making unsupported tuning claims or introducing unnecessary code, index, or configuration changes.

## Review Scope

The PL/SQL review covers the project's:

- 9 package bodies
- 7 triggers
- PL/SQL compilation and optimization metadata
- SQL activity currently available in `V$SQL`
- execution counts
- parse calls
- elapsed time
- CPU time
- buffer gets
- disk reads
- rows processed
- SQL loads and invalidations

The following scripts provide the technical evidence for this assessment:

1\. `01_PLSQL_Runtime_Inventory.sql`

2\. `02_PLSQL_SQL_Activity_Review.sql`

## Runtime Inventory Assessment

The runtime inventory review confirmed that the project PL/SQL objects are compiled and configured normally for the reviewed environment.

Key observations from the inventory review:

- 9 package specifications were present.
- 9 package bodies were present.
- 7 triggers were present.
- Reviewed package specifications and bodies were `VALID`.
- `PLSQL_OPTIMIZE_LEVEL` was `2` for the reviewed package objects.
- Debug compilation was not enabled.
- No compilation issue was identified by the inventory review.

These results do not prove runtime performance by themselves. They establish that no obvious compilation or PL/SQL compiler-configuration issue was identified before examining runtime SQL activity.

## Shared SQL Area Coverage

The SQL activity review identified:

| Metric | Result |
|---|---:|
| Project runtime objects | 16 |
| Runtime objects currently captured | 5 |
| Distinct SQL IDs | 20 |
| Child cursors | 21 |

The five package bodies represented in the current `V$SQL` snapshot were:

- `PKG_ERROR_LOG`
- `PKG_TRANSACTION_MANAGEMENT`
- `PKG_AUDIT`
- `PKG_ACCOUNT_MANAGEMENT`
- `PKG_CARD_MANAGEMENT`

The following package bodies were not represented in the current snapshot:

- `PKG_BENEFICIARY_MANAGEMENT`
- `PKG_CUSTOMER_MANAGEMENT`
- `PKG_EXCHANGE_RATE_MANAGEMENT`
- `PKG_LOG_MAINTENANCE`

The seven project triggers were also not represented in the current `V$SQL` snapshot.

`NOT CAPTURED` is not treated as a failure. `V$SQL` represents SQL currently retained in the shared SQL area and is not a permanent workload history. Therefore, absence from the report does not demonstrate that an object has never executed.

## Observed SQL Activity

### PKG_ERROR_LOG

The highest execution count in the captured workload belonged to the `ERROR_LOGS` insert executed by `PKG_ERROR_LOG`.

Observed metrics:

| Metric | Result |
|---|---:|
| Executions | 213 |
| Total elapsed time | 0.064 s |
| Elapsed time per execution | 0.302 ms |
| Buffer gets per execution | 10.00 |
| Disk reads per execution | 0.02 |

Within the captured workload, these measurements do not provide evidence of a significant runtime bottleneck.

### PKG_AUDIT

The `AUDIT_LOGS` insert executed by `PKG_AUDIT` showed:

| Metric | Result |
|---|---:|
| Executions | 109 |
| Total elapsed time | 0.027 s |
| Elapsed time per execution | 0.243 ms |
| Buffer gets per execution | 7.57 |
| Disk reads per execution | 0.05 |

The captured measurements do not indicate a performance problem requiring modification.

### PKG_TRANSACTION_MANAGEMENT

The account transaction-history query was the most notable captured query when considering elapsed time per execution.

Observed metrics:

| Metric | Result |
|---|---:|
| Executions | 3 |
| Total elapsed time | 0.016 s |
| Elapsed time per execution | 5.300 ms |
| Buffer gets per execution | 41.67 |
| Disk reads per execution | 1.00 |
| Rows processed per execution | 9.67 |

The execution count is too small to justify a tuning change based on this observation alone. The measured elapsed time is also low in absolute terms.

A transaction insert showed:

| Metric | Result |
|---|---:|
| Executions | 2 |
| Total elapsed time | 0.009 s |
| Elapsed time per execution | 4.602 ms |
| Buffer gets per execution | 160.50 |
| Disk reads per execution | 7.50 |

Although the per-execution logical and physical I/O values are higher than those of several other captured statements, only two executions were present. This is insufficient evidence for a code or index change.

## Loads and Invalidations

Several captured SQL statements showed more than one load.

No captured statement in the reviewed output showed an invalidation.

Therefore:

- no SQL invalidation problem was identified;
- load counts are retained as an observation;
- the available snapshot does not justify treating the observed load counts as a performance defect.

## Assessment Result

### Confirmed Findings

The collected evidence supports the following conclusions:

- The reviewed PL/SQL objects are valid.
- No reviewed package object showed a low PL/SQL optimization level.
- Debug compilation was not enabled for the reviewed package objects.
- No compilation errors were identified in the reviewed PL/SQL inventory.
- Five of sixteen runtime objects were represented in the current `V$SQL` snapshot.
- Captured audit and error-log SQL activity showed low elapsed time per execution.
- No captured SQL invalidations were observed.
- No measured statement provides sufficient evidence of a PL/SQL performance bottleneck.

### Changes Not Justified by Current Evidence

Based on the collected measurements, the following changes are **not justified at this stage**:

- rewriting package implementations solely for performance;
- changing trigger implementations solely for performance;
- adding indexes solely because of this PL/SQL review;
- removing indexes solely because of this PL/SQL review;
- changing PL/SQL compiler settings;
- changing database memory or instance parameters;
- introducing hints into package SQL;
- modifying tested package APIs.

The absence of a justified change is itself a valid performance-review result. Tuning should be evidence-driven rather than performed only to demonstrate that a modification was made.

## Limitations

This assessment has deliberate limitations.

`V$SQL` is a shared-pool snapshot. It does not provide complete historical workload coverage. Only 5 of the 16 reviewed runtime objects were represented at the time of collection.

The observed workload was also generated in a project/development environment rather than from a sustained production workload.

Consequently, this assessment does **not** claim that:

- every package has been performance-tested under production load;
- every trigger has been measured independently;
- every SQL statement executed by the application was captured;
- current execution times represent future production performance;
- no future tuning opportunity can exist.

The conclusion is narrower: **the evidence collected during this review does not currently justify a PL/SQL performance change.**

## Future Review Triggers

A new PL/SQL performance investigation would be justified if future evidence shows one or more of the following:

- sustained increases in elapsed time per execution;
- consistently high buffer gets for frequently executed SQL;
- significant physical I/O for frequently executed SQL;
- abnormal parse activity;
- repeated SQL invalidations;
- excessive child cursor growth;
- measurable blocking or concurrency waits;
- production workload behavior materially different from the current test workload.

Any future tuning action should be supported by runtime evidence and, where relevant, execution-plan analysis.

## Final Conclusion

The PL/SQL performance review found no evidence requiring immediate tuning.

The project therefore retains the existing package, trigger, index, and compiler configuration.

**Final assessment: No code or index change is justified by the collected runtime evidence.**

This conclusion preserves the tested application behavior while documenting that PL/SQL performance was reviewed using measurable runtime data rather than assumptions.
