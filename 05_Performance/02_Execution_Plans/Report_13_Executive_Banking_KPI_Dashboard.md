# Report 13 – Executive Banking KPI Dashboard

## Overview

This document evaluates the execution plan of the **Executive Banking KPI Dashboard** report using actual runtime statistics.

The report produces a single-row executive dashboard containing customer, account, transaction, branch, channel, and transaction-type KPIs, including currency conversion to the reporting currency.

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
| SQL ID | `1079gkdh6yf02` |
| Child Number | 0 |
| Plan Hash Value | `678762920` |
| Executions | 1 |
| Returned Rows | 1 |
| Buffer Gets | 10,930 |
| Physical Reads | 0 |
| Elapsed Time | 0.263960 seconds |
| CPU Time | 0.245631 seconds |

## Execution Plan Highlights

- Oracle applied multiple **TEMP TABLE TRANSFORMATION** operations to materialize reusable intermediate result sets.
- Latest exchange rates were selected using `ROW_NUMBER()` with `WINDOW SORT PUSHED RANK`.
- Customer, account, transaction, branch, channel, and transaction-type summaries were calculated independently and combined through `MERGE JOIN CARTESIAN`, which is appropriate because every summary returns a single row.
- `TRANSACTIONS` was fully scanned where complete analytical aggregation was required.
- Oracle used hash joins together with existing indexes for reference tables.
- Multiple `ROW_NUMBER()` calculations efficiently identified the most active branch, channel, and transaction type.
- The execution completed entirely in memory without physical I/O.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| Final dashboard | 1 | 1 |
| Latest exchange rates | 7 | 7 |
| Customer summary | 1 | 1 |
| Account summary | 21,000 | 21,000 |
| Transaction summary | 189,000 | 189,000 |
| Top branch | 1 | 1 |
| Top channel | 1 | 1 |
| Top transaction type | 1 | 1 |

The optimizer produced accurate cardinality estimates for all major aggregation stages. Temporary result sets were materialized once and reused efficiently across multiple dashboard calculations.

## Assessment

Although the execution plan appears large, it is expected for an executive dashboard that combines several independent analytical summaries into a single result.

The repeated `MERGE JOIN CARTESIAN` operations are intentional because every participating subquery produces a single aggregated row. This does **not** indicate a Cartesian join problem.

Temporary table transformation minimizes repeated processing of common result sets, while hash joins and window functions efficiently support ranking and aggregation.

The dashboard completed in approximately **0.26 seconds** with **zero physical reads**, indicating efficient optimizer decisions and effective memory usage.

## Optimization Decision

| Item | Decision |
|---|---|
| SQL Rewrite Required | No |
| Additional Index Required | No |
| Optimizer Hint Required | No |
| Statistics Collection Required | No |
| Temporary Table Transformation | Appropriate |
| Cartesian Merge Join | Expected for single-row dashboard |

## Final Status

**Performance Review:** Passed

**Optimization Required:** No
