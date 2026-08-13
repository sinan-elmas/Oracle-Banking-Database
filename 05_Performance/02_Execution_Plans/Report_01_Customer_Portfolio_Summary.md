# Report 01 – Customer Portfolio Summary

## Overview

This document evaluates the execution plan of the **Customer Portfolio Summary** report using actual runtime statistics.

The report consolidates customer accounts, balances, cards, beneficiaries, and currency information. No SQL logic, index, statistics, or database object was modified during the analysis.

## Analysis Method

The report was executed with the `GATHER_PLAN_STATISTICS` hint. Actual execution statistics were retrieved using:

```sql
DBMS_XPLAN.DISPLAY_CURSOR
```

with:

```text
ALLSTATS LAST +PREDICATE +ALIAS
```

The complete collection and interpretation process is documented in `01_Execution_Plan_Methodology.md`.

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
| SQL ID | `3rhgvpm5xs9vn` |
| Child Number | 0 |
| Plan Hash Value | `753492744` |
| Executions | 1 |
| Returned Rows | 21,002 |
| Buffer Gets | 3,535 |
| Physical Reads | 666 |
| Elapsed Time | 0.180454 seconds |
| CPU Time | 0.142615 seconds |

## Execution Plan Highlights

- Hash joins were used to combine the aggregated account, card, beneficiary, currency, and customer result sets.
- `INDEX FAST FULL SCAN` was used for beneficiary and account index access.
- Oracle used an index join for the small `CURRENCIES` table.
- Full scans on `CUSTOMERS`, `ACCOUNTS`, and `CARDS` supported complete portfolio aggregation.
- The final `ORDER BY` processed approximately 21,000 result rows.
- No temporary-disk spill was observed in the collected plan.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| Final result | 21,000 | 21,002 |
| Account aggregation | 21,000 | 21,000 |
| Card aggregation input | 7,866 | 7,866 |
| Beneficiary join input | 15,644 | 15,644 |

Optimizer estimates closely matched the actual row counts.

## Assessment

The full scans are appropriate because the report summarizes complete portfolio populations rather than a selective subset.

The selected hash joins, index access paths, aggregation operations, and final sort are suitable for the current workload.

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
