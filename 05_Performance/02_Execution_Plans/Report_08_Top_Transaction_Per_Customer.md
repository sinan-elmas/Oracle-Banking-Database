# Report 08 – Top Transaction per Customer

## Overview

This document evaluates the execution plan of the **Top Transaction per Customer** report using actual runtime statistics.

The report identifies the highest-value successful transaction for each customer after converting transaction amounts to the base currency.

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
| SQL ID | `fmc1qqu9kwmay` |
| Child Number | 0 |
| Plan Hash Value | `469960119` |
| Executions | 1 |
| Returned Rows | 9,915 |
| Buffer Gets | 3,302 |
| Physical Reads | 22 |
| Elapsed Time | 0.382295 seconds |
| CPU Time | 0.355567 seconds |

## Execution Plan Highlights

- `TRANSACTIONS` was fully scanned after applying the `STATUS = 'SUCCESS'` filter.
- `ACCOUNTS` and `CUSTOMERS` were fully scanned because the report evaluates transactions across the complete customer population.
- The transaction-type filter used an `INLIST ITERATOR` and unique index access on `UQ_TRANSACTION_TYPES_NAME`.
- `TRANSACTION_CHANNELS` was accessed through an index join.
- `EXCHANGE_RATES` was processed with `WINDOW SORT PUSHED RANK` to select the latest applicable rate.
- `WINDOW SORT PUSHED RANK` also implemented the customer-level `ROW_NUMBER()` logic and retained one transaction per customer.
- Hash joins were used for the main data-set combinations.
- The final sort processed 9,915 customer rows and remained in memory.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| Successful transactions | 189,000 | 189,000 |
| `ACCOUNTS` scan | 21,000 | 21,000 |
| `CUSTOMERS` scan | 10,000 | 10,002 |
| Ranked transaction input | 7,917 | 161,000 |
| Final result | 7,917 | 9,915 |

The primary table estimates were accurate, but the optimizer significantly underestimated the number of rows entering the ranking stage.

Despite this difference:

- Hash joins remained appropriate.
- The ranking operation completed in memory.
- No temporary-disk spill was observed.
- Runtime remained below half a second.
- The final plan did not show an inefficient access path.

## Assessment

The full scan on `TRANSACTIONS` is appropriate because the report evaluates most successful transactions before selecting the top transaction for each customer.

The transaction-type and channel reference tables were accessed efficiently through indexes.

The main observation is the cardinality underestimation at the ranking stage. It should be documented and monitored, but the collected runtime evidence does not currently justify a SQL rewrite, new index, or statistics change.

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
