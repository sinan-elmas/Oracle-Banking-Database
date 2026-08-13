# Execution Plan Analysis Methodology

## Purpose

The purpose of this methodology is to provide a consistent and repeatable approach for evaluating the execution plans of SQL reports included in this project.

Rather than relying solely on estimated execution plans, every report is validated using actual runtime execution statistics collected from the Oracle optimizer. This approach provides an accurate representation of how each query behaves under real execution conditions.

---
## Analysis Workflow

Each SQL report follows the same analysis process.

1\. Execute the SQL statement using `GATHER_PLAN_STATISTICS`.

2\. Locate the executed cursor in `V$SQL`.

3\. Record execution metrics.

4\. Retrieve the actual execution plan using `DBMS_XPLAN.DISPLAY_CURSOR`.

5\. Evaluate optimizer decisions.

6\. Document observations and optimization decisions.

This standardized workflow ensures that every report is evaluated using identical criteria.

---
## Runtime Statistics Collection

Actual runtime statistics are collected instead of estimated execution plans.

The following Oracle features are used during the analysis:

- `GATHER_PLAN_STATISTICS`
- `V$SQL`
- `DBMS_XPLAN.DISPLAY_CURSOR`
- `ALLSTATS LAST`

The following runtime metrics are documented for every report:

- SQL ID
- Plan Hash Value
- Executions
- Rows Processed
- Buffer Gets
- Physical Reads
- Elapsed Time
- CPU Time

These metrics provide objective performance measurements based on actual execution.

---
## Execution Plan Evaluation

Each execution plan is reviewed using the same evaluation criteria.

### Access Paths

The selected access methods are reviewed, including:

- Full Table Scan
- Index Range Scan
- Index Unique Scan
- Index Fast Full Scan
- Table Access by ROWID

The chosen access path is evaluated according to the amount of data processed rather than assuming that index access is always preferable.

---
### Join Methods

The optimizer's join strategy is evaluated, including:

- Hash Join
- Nested Loops
- Merge Join
- Merge Join Cartesian

When Cartesian joins appear, they are examined to determine whether they are expected for dashboard-style aggregations or indicate a potential design issue.

---
### Aggregation Operations

Aggregation operators are reviewed, including:

- HASH GROUP BY
- SORT GROUP BY
- HASH GROUP BY PIVOT
- HASH GROUP BY ROLLUP

The selected aggregation strategy is evaluated together with memory utilization and execution efficiency.

---
### Window Operations

Analytical operations are also reviewed when applicable.

Examples include:

- WINDOW SORT
- WINDOW SORT PUSHED RANK
- ROW_NUMBER()
- DENSE_RANK()
- CUME_DIST()

These operations are evaluated to ensure that ranking calculations are performed efficiently.

---
## Cardinality Analysis

Estimated row counts are compared with actual row counts.

The following metrics are reviewed:

- Estimated Rows (E-Rows)
- Actual Rows (A-Rows)

Minor estimation differences are considered normal.

Significant differences are documented when they may influence optimizer decisions.

Cardinality differences alone do not justify SQL tuning unless they negatively affect execution efficiency.

---
## Optimization Decision Criteria

Each report concludes with an optimization assessment.

The following areas are evaluated:

- SQL rewrite
- Additional indexes
- Optimizer hints
- Statistics collection
- Temporary table transformation
- Window function processing
- Join strategy

Optimization recommendations are made only when supported by actual runtime evidence.

Potential improvements are intentionally rejected when the current execution plan is already efficient.

---
## Documentation Standard

Each execution plan report contains the same documentation structure.

- Overview
- Analysis Method
- Environment
- Cursor Summary
- Execution Plan Highlights
- Cardinality Review
- Assessment
- Optimization Decision
- Final Status

This standardized format simplifies report comparison and provides consistent documentation throughout the project.

---
## Summary

All execution plan analyses in this project are based on actual runtime execution statistics rather than estimated execution plans.

This methodology provides a consistent, evidence-based approach for evaluating Oracle SQL performance while avoiding unnecessary tuning recommendations that are not supported by measured execution behavior.
