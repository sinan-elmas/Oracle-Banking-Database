# Report 06 – Monthly Transaction Trend Analysis

## Overview

This document evaluates the execution plan of the **Monthly Transaction Trend Analysis** report using actual runtime statistics.

The report analyzes monthly successful transaction volumes, customer activity, transaction amounts, and month-over-month growth trends by currency.

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
| SQL ID | `7s7knxkwrk014` |
| Child Number | 0 |
| Plan Hash Value | `3367338425` |
| Executions | 1 |
| Returned Rows | 240 |
| Buffer Gets | 2,934 |
| Physical Reads | 0 |
| Elapsed Time | 0.298635 seconds |
| CPU Time | 0.277636 seconds |

## Execution Plan Highlights

- Oracle materialized the `TRANSACTION_BASE` result using `TEMP TABLE TRANSFORMATION`.
- `TRANSACTIONS` and `ACCOUNTS` were fully scanned to build the reporting dataset.
- Successful transactions (`STATUS = 'SUCCESS'`) were filtered before aggregation.
- `CONNECT BY` efficiently generated the monthly calendar.
- `HASH UNIQUE` identified active currencies.
- `HASH GROUP BY` calculated monthly transaction summaries.
- `WINDOW SORT` supported the `LAG()` analytic function.
- `DENSE_RANK()` and the final ordering processed only 240 result rows.
- The entire execution completed without physical disk reads.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| `ACCOUNTS` scan | 21,000 | 21,000 |
| Successful transactions | 189,000 | 189,000 |
| Calendar months | 30 | 30 |
| Active currencies | 8 | 8 |
| Final result | 240 | 240 |

The optimizer accurately estimated the principal table accesses. Intermediate aggregation estimates differed from the actual values, but the differences did not affect the selected execution strategy or runtime performance.

## Assessment

The full scan on `TRANSACTIONS` is appropriate because the report aggregates nearly all successful transactions before monthly summarization.

The temporary table transformation avoids repeatedly scanning the transaction dataset during calendar generation, currency expansion, aggregation, and analytic processing.

The selected hash joins, hash aggregation, analytic functions, and temporary materialization are appropriate for the current reporting workload.

## Optimization Decision

| Item | Decision |
|---|---|
| SQL Rewrite Required | No |
| Additional Index Required | No |
| Optimizer Hint Required | No |
| Statistics Collection Required | No |

## Final Status

**Performance Review:** Passed

**Optimization Required:** No
