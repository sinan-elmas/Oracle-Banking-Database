# Report 05 – Dormant Account Detection

## Overview

This document evaluates the execution plan of the **Dormant Account Detection** report using actual runtime statistics.

The report determines the latest successful transaction date for each account and classifies active accounts according to inactivity duration.

No SQL logic, index, statistics, or database object was modified during the analysis.

## Analysis Method

The query was executed with `GATHER_PLAN_STATISTICS`, and the actual execution plan was retrieved through `DBMS_XPLAN.DISPLAY_CURSOR`.

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
| SQL ID | `fupp7wrzj883y` |
| Child Number | 0 |
| Plan Hash Value | `1668319238` |
| Executions | 1 |
| Returned Rows | 21,000 |
| Buffer Gets | 3,199 |
| Physical Reads | 4 |
| Elapsed Time | 0.089244 seconds |
| CPU Time | 0.081842 seconds |

## Execution Plan Highlights

- `TRANSACTIONS` was fully scanned with the `STATUS = 'SUCCESS'` filter.
- `HASH GROUP BY` calculated the latest successful transaction date for each source account.
- The transaction summary produced 20,659 account-level rows from approximately 189,000 successful transactions.
- `ACCOUNTS` and `CUSTOMERS` were fully scanned because the report evaluates the complete active account population.
- Oracle used an index join for the small `CURRENCIES` table.
- Hash joins combined account, customer, currency, and transaction-summary data.
- The final sort processed 21,000 result rows and remained in memory.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| Successful transaction rows | 189,000 | 189,000 |
| Transaction summary | 20,822 | 20,659 |
| `ACCOUNTS` scan | 21,000 | 21,000 |
| `CUSTOMERS` scan | 10,000 | 10,002 |
| Final result | 21,000 | 21,000 |

Optimizer estimates were accurate throughout the main execution path. The small difference in the transaction-summary estimate did not affect join selection or runtime behavior.

## Assessment

The full scan on `TRANSACTIONS` is appropriate because the report must evaluate successful activity across the complete transaction history.

Although an index exists on `SOURCE_ACCOUNT_ID`, the query also filters by `STATUS` and aggregates most successful transaction rows. The collected plan does not provide evidence that an index-driven alternative would reduce the workload.

The selected full scans, hash aggregation, hash joins, index join, and final sort are suitable for the current data volume.

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
