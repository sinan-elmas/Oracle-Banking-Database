# Report 12 – Transaction Type and Channel Grouping Sets

## Overview

This document evaluates the execution plan of the **Transaction Type and Channel Grouping Sets** report using actual runtime statistics.

The report summarizes successful transactions by currency, transaction type, and transaction channel using `GROUPING SETS` to generate multiple aggregation levels within a single query.

No SQL logic, index, statistics, or database object was modified during the analysis.

## Analysis Method

The query was executed with `GATHER_PLAN_STATISTICS`, and the actual execution plan was retrieved using `DBMS_XPLAN.DISPLAY_CURSOR`.

The standard methodology is documented in `01_Execution_Plan_Methodology.md`.

## Environment

| Component | Value |
|---|---|
| Database | Oracle AI Database 26ai |
| Database Version | 23.26.1.0.0 |
| Schema | `BANKING_DB` |
| Environment | Docker on Windows |
| Client | Oracle SQL Developer 24.3.1.347 |

## Cursor Summary

| Metric | Value |
|---|---:|
| SQL ID | `0xk0z1busrn2c` |
| Child Number | 0 |
| Plan Hash Value | `1008600255` |
| Executions | 1 |
| Returned Rows | 186 |
| Buffer Gets | 2,963 |
| Physical Reads | 1 |
| Elapsed Time | 0.604848 seconds |
| CPU Time | 0.567723 seconds |

## Execution Plan Highlights

- Oracle applied `TEMP TABLE TRANSFORMATION` and materialized the intermediate result set in cursor-duration memory.
- `TRANSACTIONS` was fully scanned after filtering `STATUS = 'SUCCESS'`.
- `ACCOUNTS`, `TRANSACTION_TYPES`, `TRANSACTION_CHANNELS`, and `CURRENCIES` were accessed through efficient hash joins and index joins.
- The materialized dataset was reused for multiple aggregation passes instead of repeating the base-table joins.
- Two `SORT GROUP BY ROLLUP` operations implemented the `GROUPING SETS` expansion.
- A final `UNION ALL` combined the aggregation branches before the final sort.
- The report completed with only one physical read.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| Successful transactions | 189,000 | 189,000 |
| Materialized temporary rows | 189,000 | 189,000 |
| First grouping phase | 120 | 146 |
| Second grouping phase | 29 | 40 |
| Final result | 149 | 186 |

The optimizer accurately estimated the base-table operations and the temporary result set. Minor differences appeared during the grouping stages, but they did not affect execution efficiency.

## Assessment

The optimizer selected an efficient strategy for a complex analytical query.

Materializing the intermediate dataset avoided repeated joins across multiple grouping levels. Hash joins, temporary table transformation, and grouped aggregation are appropriate choices for this workload.

The report completed in approximately **0.60 seconds** with only **one physical read**, indicating efficient memory utilization throughout execution.

## Optimization Decision

| Item | Decision |
|---|---|
| SQL Rewrite Required | No |
| Additional Index Required | No |
| Optimizer Hint Required | No |
| Statistics Collection Required | No |
| Temporary Table Transformation | Appropriate |
| GROUPING SETS Implementation | Appropriate |

## Final Status

**Performance Review:** Passed

**Optimization Required:** No
