# Report 04 – Branch Performance Dashboard

## Overview

This document evaluates the execution plan of the **Branch Performance Dashboard** using actual runtime statistics.

The report calculates branch-level customer, account, portfolio, and transaction metrics in a common base currency. It also ranks and classifies branches according to portfolio performance.

No SQL logic, index, statistics, or database object was modified during the analysis.

## Analysis Method

The report was executed with `GATHER_PLAN_STATISTICS`, and actual runtime statistics were retrieved using `DBMS_XPLAN.DISPLAY_CURSOR`.

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
| SQL ID | `95qf2y488ta4u` |
| Child Number | 0 |
| Plan Hash Value | `3090029318` |
| Executions | 1 |
| Returned Rows | 50 |
| Buffer Gets | 3,559 |
| Physical Reads | 2,567 |
| Elapsed Time | 0.175160 seconds |
| CPU Time | 0.154127 seconds |

## Execution Plan Highlights

- Oracle materialized reused base-currency, exchange-rate, and branch-performance results through `TEMP TABLE TRANSFORMATION`.
- The selected base currency was retrieved through a unique index scan.
- `WINDOW SORT PUSHED RANK` selected the latest exchange rates.
- `ACCOUNTS` was fully scanned for account and transaction portfolio calculations.
- `TRANSACTIONS` was fully scanned because all branch transaction activity was aggregated.
- Hash joins and hash aggregation were used for broad data-set processing.
- Final ranking, distribution, and sorting processed only 50 branch rows.
- The collected plan showed no temporary-disk spill.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| `BRANCHES` scan | 50 | 50 |
| `ACCOUNTS` scans | 21,000 | 21,000 |
| `TRANSACTIONS` scan | 200,000 | 200,000 |
| Exchange-rate processing | 7 | 7 |
| Final result | 50 | 50 |

One internal grouping stage estimated 21,000 rows and returned 10,000 rows. The difference did not affect join selection, memory usage, or overall runtime.

## Assessment

The full scans are appropriate because the dashboard calculates metrics across the complete account and transaction portfolios.

The Cartesian joins shown in the plan originate from intentional cross joins with one-row parameter results and do not cause uncontrolled row multiplication.

The optimizer selected suitable access paths, join methods, aggregation operations, and analytic processing.

## Optimization Decision

| Item | Decision |
|---|---|
| SQL Rewrite Required | No |
| Additional Index Required | No |
| Optimizer Hint Required | No |
| Statistics Collection Required | No |
| Temporary Transformation Change Required | No |

## Final Status

**Performance Review:** Passed
**Optimization Required:** No
