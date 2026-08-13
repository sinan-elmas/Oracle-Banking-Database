# Report 15 – Customer 360 Portfolio Dashboard

## Overview

This document evaluates the execution plan of the **Customer 360 Portfolio Dashboard** report using actual runtime statistics.

The report builds a comprehensive customer-level analytical dashboard by combining customer profile information, account portfolios, transaction activity, cards, addresses, contacts, beneficiaries, exchange-rate conversion, and customer ranking metrics into a single result set.

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
| SQL ID | `5n8kq1x35k6bv` |
| Child Number | 0 |
| Plan Hash Value | `2794261486` |
| Executions | 1 |
| Returned Rows | 10,002 |
| Buffer Gets | 3,734 |
| Physical Reads | 0 |
| Elapsed Time | 0.416196 seconds |
| CPU Time | 0.398026 seconds |

## Execution Plan Highlights

- Oracle applied multiple **TEMP TABLE TRANSFORMATION** operations to materialize reusable intermediate result sets.
- Latest exchange rates were resolved using `ROW_NUMBER()` together with `WINDOW SORT PUSHED RANK`.
- Customer profile components (accounts, cards, contacts, addresses, beneficiaries, and transactions) were aggregated independently before being merged into the Customer 360 dataset.
- Hash joins were used throughout the execution plan for large analytical joins.
- Existing indexes supported efficient access to customer-related reference data.
- Multiple `WINDOW SORT` operations implemented customer ranking calculations.
- Temporary result sets stored in cursor-duration memory were reused throughout the execution plan.
- Execution completed entirely in memory with no physical disk reads.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| Final dashboard | 10,000 | 10,002 |
| Customer scan | 10,000 | 10,002 |
| Successful transactions | 189,000 | 189,000 |
| Accounts | 21,000 | 21,000 |
| Cards | 7,866 | 7,866 |
| Customer contacts | 22,850 | 22,850 |
| Customer addresses | 14,293 | 14,293 |
| Beneficiaries | 15,644 | 15,644 |

The optimizer produced accurate estimates for the primary tables and customer-level aggregations. Minor differences appeared during intermediate aggregation stages but did not affect the selected execution strategy or overall runtime.

## Assessment

This is one of the most sophisticated execution plans in the project.

Oracle combines multiple analytical components into a unified Customer 360 dashboard by materializing reusable datasets, applying hash aggregation, window functions, and ranking operations before producing the final ranked customer view.

Several `MERGE JOIN CARTESIAN` operations appear in the execution plan. These joins are expected because Oracle combines intermediate result sets that each return a single row or a very small number of rows during dashboard construction. They do not indicate an inefficient Cartesian join.

The report completed in approximately **0.42 seconds** with **zero physical reads**, demonstrating efficient optimizer decisions, effective memory utilization, and stable execution characteristics for a complex analytical workload.

## Optimization Decision

| Item | Decision |
|---|---|
| SQL Rewrite Required | No |
| Additional Index Required | No |
| Optimizer Hint Required | No |
| Statistics Collection Required | No |
| Temporary Table Transformation | Appropriate |
| Window Function Processing | Appropriate |
| Customer Ranking Strategy | Appropriate |
| Cartesian Merge Join | Expected for dashboard aggregation |

## Final Status

**Performance Review:** Passed

**Optimization Required:** No
