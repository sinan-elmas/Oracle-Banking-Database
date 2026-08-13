# SQL Tuning Methodology

## Purpose

The purpose of this methodology is to establish a consistent, evidence-based approach for evaluating SQL tuning opportunities within the Oracle Banking Database project.

Rather than applying optimization techniques indiscriminately, SQL statements are reviewed using actual runtime statistics, execution plans, and optimizer behavior before any tuning recommendation is made.

The objective is to improve performance only when measurable evidence supports a change.

---
## Tuning Philosophy

SQL tuning in this project follows the principle of **evidence before optimization**.

A SQL statement is not rewritten simply because an alternative implementation exists.

Optimization recommendations are made only when actual execution statistics indicate that the current implementation is inefficient.

This approach avoids unnecessary complexity and preserves SQL readability and maintainability.

---
## Analysis Workflow

Every SQL report follows the same evaluation process.

1\. Execute the SQL statement using `GATHER_PLAN_STATISTICS`.

2\. Collect runtime statistics from `V$SQL`.

3\. Retrieve the actual execution plan using `DBMS_XPLAN.DISPLAY_CURSOR`.

4\. Review optimizer decisions.

5\. Evaluate index usage.

6\. Review cardinality estimates.

7\. Determine whether SQL tuning is justified.

Only after completing these steps is a tuning recommendation considered.

---
## Evaluation Criteria

Each SQL statement is reviewed using the following criteria.

### Runtime Performance

The following metrics are evaluated:

- Buffer Gets
- Physical Reads
- CPU Time
- Elapsed Time
- Rows Processed
- Executions

These measurements represent actual runtime behavior rather than estimated cost.

---
### Execution Plan

The execution plan is reviewed for:

- Access paths
- Join methods
- Aggregation methods
- Window operations
- Temporary table transformations
- Predicate evaluation

The optimizer's decisions are evaluated in the context of the reporting workload rather than isolated plan operators.

---
### Cardinality

Estimated row counts are compared with actual row counts.

Minor estimation differences are considered acceptable.

Only significant estimation errors that negatively influence optimizer decisions are treated as potential tuning candidates.

---
### Index Usage

The selected access path is reviewed together with index selectivity.

The presence of a Full Table Scan does not automatically indicate a tuning opportunity.

Large analytical reports frequently benefit from scanning an entire table instead of performing many index lookups.

---
## SQL Rewrite Criteria

A SQL rewrite is considered only when one or more of the following conditions are observed:

- Repeated unnecessary table access
- Redundant joins
- Avoidable sorting
- Inefficient aggregation
- Poor predicate placement
- Measurable execution improvement

Alternative SQL syntax alone is not considered sufficient justification.

---
## Optimizer Hint Policy

Optimizer hints are intentionally avoided unless supported by measurable runtime evidence.

Hints may become invalid as:

- data volume changes,
- optimizer statistics change,
- Oracle versions evolve.

The Oracle Cost-Based Optimizer is therefore preferred whenever it produces an efficient execution plan.

---
## Full Table Scan Evaluation

A Full Table Scan is not automatically treated as a performance problem.

For analytical SQL reports, Oracle may correctly choose a Full Table Scan when:

- a large percentage of rows is processed,
- aggregation dominates execution cost,
- index access would require excessive random I/O,
- the optimizer estimates that sequential reads are more efficient.

Such decisions are accepted when supported by runtime statistics.

---
## Documentation Standard

Each tuning assessment follows a consistent structure:

- Objective
- Runtime observations
- Execution plan findings
- Optimizer behavior
- Tuning assessment
- Final recommendation

This format ensures consistent documentation across all SQL reports.

---
## Summary

SQL tuning decisions throughout this project are based on measured execution behavior rather than assumptions.

The methodology emphasizes actual runtime statistics, execution plan analysis, optimizer behavior, and workload characteristics before recommending any SQL rewrite or structural optimization.

This approach promotes maintainable SQL while avoiding unnecessary tuning that is not supported by measurable evidence.
