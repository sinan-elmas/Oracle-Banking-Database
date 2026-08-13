# Oracle Optimizer Behavior

## Overview

This document summarizes the Oracle Cost-Based Optimizer (CBO) behavior observed during the execution of the SQL reporting workload included in the Oracle Banking Database project.

The analysis is based on actual runtime execution statistics collected using `GATHER_PLAN_STATISTICS` and `DBMS_XPLAN.DISPLAY_CURSOR`.

The objective is to understand how Oracle selected execution plans and whether those decisions were appropriate for the reporting workload.

---
## Optimizer Characteristics

The Oracle Cost-Based Optimizer consistently selected execution plans that balanced CPU usage, logical I/O, and execution time.

Observed execution plans demonstrated stable behavior across all fifteen SQL reports.

No evidence suggested optimizer instability or incorrect plan selection.

---
## Access Path Selection

The optimizer selected different access paths depending on the expected workload.

Observed access methods included:

- TABLE ACCESS FULL
- INDEX RANGE SCAN
- INDEX UNIQUE SCAN
- INDEX FAST FULL SCAN
- TABLE ACCESS BY INDEX ROWID

Each access method was appropriate for the amount of data processed.

Full table scans were primarily selected for analytical reports reading a large percentage of transactional data.

Selective lookups used index access paths.

---
## Join Strategy

The dominant join method throughout the project was **Hash Join**.

Hash joins were primarily selected when:

- large tables were joined,
- aggregation followed the join,
- analytical reporting processed many rows.

Nested Loops appeared mainly in small lookup operations and metadata access.

Merge Join was used only where appropriate.

No inappropriate join strategy was observed.

---
## Aggregation Strategy

Oracle consistently selected efficient aggregation operators.

Observed operations included:

- HASH GROUP BY
- HASH GROUP BY ROLLUP
- HASH GROUP BY PIVOT
- SORT GROUP BY

Hash aggregation was the preferred strategy for large analytical reports because it minimized sorting overhead.

---
## Window Function Processing

Several reports relied on analytical SQL functions.

Observed optimizer operations included:

- WINDOW SORT
- WINDOW SORT PUSHED RANK

These operations supported:

- ROW_NUMBER()
- DENSE_RANK()
- CUME_DIST()

Window processing completed efficiently without excessive resource consumption.

---
## Temporary Table Transformation

Complex dashboard reports made extensive use of temporary table transformation.

Oracle materialized reusable intermediate result sets whenever this reduced repeated computation.

Observed execution plans showed that temporary table transformation improved execution efficiency without requiring manual SQL changes.

---
## Full Table Scan Decisions

Full Table Scan was frequently selected for large reporting queries.

This behavior was appropriate because many reports processed:

- complete customer populations,
- complete account portfolios,
- large portions of transaction history,
- analytical summaries.

Replacing these scans with index lookups would likely increase logical I/O and reduce performance.

---
## Cardinality Estimation

Estimated row counts were generally consistent with actual runtime results.

Minor estimation differences occurred in several reports but did not influence optimizer decisions.

No execution plan demonstrated a significant cardinality problem requiring corrective action.

---
## Optimizer Stability

The optimizer consistently generated stable execution plans.

Across all analyzed reports:

- no unstable execution plans were observed,
- no unexpected plan regressions occurred,
- no optimizer hints were required.

The Oracle Cost-Based Optimizer successfully adapted to the reporting workload using existing statistics and indexes.

---
## Overall Assessment

The execution plans demonstrate that Oracle's optimizer effectively supports the analytical SQL workload implemented in this project.

The observed behavior confirms appropriate selection of:

- access paths,
- join methods,
- aggregation strategies,
- window operations,
- temporary table transformations.

No optimizer intervention was required.

---
## Conclusion

The Oracle Cost-Based Optimizer produced efficient and stable execution plans throughout the SQL reporting workload.

Runtime statistics consistently support the optimizer's decisions, and no evidence justifies overriding those decisions through SQL rewrites or optimizer hints.

The current optimizer behavior is considered appropriate for the Oracle Banking Database reporting environment.
