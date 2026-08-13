# Report 11 – Branch Transaction Performance Rollup

## Overview

This document evaluates the execution plan of the **Branch Transaction Performance Rollup** report using actual runtime statistics.

The report summarizes successful transaction activity by currency, month, and branch, while also producing monthly and all-period totals through `ROLLUP`.

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
| SQL ID | `a3ufq0uj1k48q` |
| Child Number | 0 |
| Plan Hash Value | `939985782` |
| Executions | 1 |
| Returned Rows | 12,171 |
| Buffer Gets | 2,907 |
| Physical Reads | 0 |
| Elapsed Time | 0.119669 seconds |
| CPU Time | 0.099004 seconds |

## Execution Plan Highlights

- `TRANSACTIONS` was fully scanned after applying the `STATUS = 'SUCCESS'` filter.
- `ACCOUNTS` and `BRANCHES` were fully scanned because the report aggregates the complete branch transaction portfolio.
- Oracle used an index join for the small `CURRENCIES` table.
- Hash joins combined transactions, accounts, branches, and currencies.
- `HASH GROUP BY ROLLUP` produced branch, monthly, and all-period totals in a single aggregation stage.
- The final sort processed 12,171 result rows and remained in memory.
- Execution completed without physical disk reads.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| Successful transactions | 189,000 | 189,000 |
| `ACCOUNTS` scan | 21,000 | 21,000 |
| `BRANCHES` scan | 50 | 50 |
| Rollup result | 189,000 | 12,171 |
| Final result | 189,000 | 12,171 |

The optimizer accurately estimated the base-table and join cardinalities but substantially overestimated the number of rows produced by the `ROLLUP` aggregation.

The estimate difference did not lead to an inappropriate join method, memory spill, or excessive runtime.

## Assessment

The full scans are appropriate because the report processes nearly all successful transactions and aggregates the complete account and branch populations.

The selected hash joins and `HASH GROUP BY ROLLUP` operation are suitable for this analytical workload.

Although the post-aggregation cardinality estimate is high, the report completed in approximately 0.12 seconds with no physical reads. The collected evidence does not justify a SQL rewrite, additional index, or statistics change.

## Optimization Decision

| Item | Decision |
|---|---|
| SQL Rewrite Required | No |
| Additional Index Required | No |
| Optimizer Hint Required | No |
| Statistics Collection Required | No |
| Cardinality Monitoring Required | Yes |

## Final Status

**Performance Review:** Passed

**Optimization Required:** No

**Cardinality Observation:** Documented
