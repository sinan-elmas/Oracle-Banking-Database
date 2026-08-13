# Report 10 – Monthly Transaction Channel Pivot

## Overview

This document evaluates the execution plan of the **Monthly Transaction Channel Pivot** report using actual runtime statistics.

The report summarizes successful transactions by month and transaction channel, then pivots channel totals into separate report columns.

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
| SQL ID | `9jag63kxdf5u9` |
| Child Number | 0 |
| Plan Hash Value | `3805746988` |
| Executions | 1 |
| Returned Rows | 30 |
| Buffer Gets | 2,579 |
| Physical Reads | 0 |
| Elapsed Time | 0.059231 seconds |
| CPU Time | 0.054093 seconds |

## Execution Plan Highlights

- `TRANSACTIONS` was fully scanned after applying the `STATUS = 'SUCCESS'` filter.
- `TRANSACTION_CHANNELS` was accessed through an index join.
- A hash join combined successful transactions with the five channel rows.
- The first `HASH GROUP BY` reduced approximately 189,000 transactions to 150 month-and-channel groups.
- `HASH GROUP BY PIVOT` converted those 150 grouped rows into 30 monthly result rows.
- The final `SORT ORDER BY` processed only 30 rows.
- Execution completed without physical disk reads.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| Successful transactions | 189,000 | 189,000 |
| Transaction channels | 5 | 5 |
| Monthly channel groups | 189,000 | 150 |
| Pivot result | 188,000 | 30 |
| Final result | 188,000 | 30 |

The base-table and join estimates were accurate, but Oracle substantially overestimated the number of rows after grouping and pivoting.

The estimate difference did not cause an inappropriate join method, temporary-disk spill, or excessive runtime.

## Assessment

The full transaction scan is appropriate because the report aggregates nearly all successful transactions.

Hash aggregation and pivot processing are suitable for converting the complete transaction set into a small monthly result.

Although the post-aggregation cardinality estimates are high, the query completed in approximately 0.06 seconds with no physical reads. The collected evidence does not justify a SQL rewrite, new index, or statistics change.

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
