# Report 14 – Branch Portfolio and Transaction KPI Dashboard

## Overview

This document evaluates the execution plan of the **Branch Portfolio and Transaction KPI Dashboard** report using actual runtime statistics.

The report produces a branch-level executive dashboard by combining portfolio metrics, transaction statistics, currency conversion, activity rankings, and performance indicators into a single analytical result set.

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
| SQL ID | `afjxznp6wcsb6` |
| Child Number | 0 |
| Plan Hash Value | `2804694871` |
| Executions | 1 |
| Returned Rows | 50 |
| Buffer Gets | 5,989 |
| Physical Reads | 0 |
| Elapsed Time | 0.261161 seconds |
| CPU Time | 0.249102 seconds |

## Execution Plan Highlights

- Oracle used multiple **TEMP TABLE TRANSFORMATION** operations to materialize reusable intermediate result sets.
- Latest exchange rates were selected using `ROW_NUMBER()` with `WINDOW SORT PUSHED RANK`.
- `TRANSACTIONS` was fully scanned after filtering `STATUS = 'SUCCESS'`.
- Existing indexes were used efficiently through several index joins on reference tables.
- Hash joins combined transactions, accounts, branches, currencies, and exchange-rate information.
- Multiple `WINDOW SORT` operations implemented branch ranking calculations.
- `HASH GROUP BY` aggregated portfolio and transaction metrics before ranking.
- The final dashboard returned one summarized row for each branch.
- Execution completed entirely in memory without physical disk reads.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| Final dashboard | 50 | 50 |
| Latest exchange rates | 7 | 7 |
| Successful transactions | 189,000 | 189,000 |
| Branch aggregation | 625 | 250 |
| Branch KPI result | 50 | 50 |
| Final ranked result | 50 | 50 |

The optimizer produced accurate estimates for the base tables and final dashboard output. Minor cardinality differences appeared during intermediate aggregation stages but did not affect execution strategy or runtime efficiency.

## Assessment

This execution plan is expected for a complex branch-level analytical dashboard.

Oracle materialized reusable datasets through **TEMP TABLE TRANSFORMATION**, minimizing repeated processing across multiple KPI calculations. Hash joins, hash aggregation, window functions, and ranking operations were efficiently combined into a single execution plan.

Several `MERGE JOIN CARTESIAN` operations appear in the execution plan. These joins are expected because Oracle combines intermediate result sets that each return a single row or a very small number of rows before producing the final dashboard output. They do not indicate an inefficient Cartesian join.

The report completed in approximately **0.26 seconds** with **zero physical reads**, demonstrating efficient optimizer decisions and effective memory utilization.

## Optimization Decision

| Item | Decision |
|---|---|
| SQL Rewrite Required | No |
| Additional Index Required | No |
| Optimizer Hint Required | No |
| Statistics Collection Required | No |
| Temporary Table Transformation | Appropriate |
| Window Function Processing | Appropriate |
| Cartesian Merge Join | Expected for dashboard aggregation |

## Final Status

**Performance Review:** Passed

**Optimization Required:** No
