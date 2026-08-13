# Report 09 – Customer Account and IBAN Consolidation

## Overview

This document evaluates the execution plan of the **Customer Account and IBAN Consolidation** report using actual runtime statistics.

The report consolidates account numbers, IBAN values, currencies, and account counts for each customer.

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
| SQL ID | `0s464jvb2u7hb` |
| Child Number | 0 |
| Plan Hash Value | `2440908184` |
| Executions | 1 |
| Returned Rows | 10,002 |
| Buffer Gets | 474 |
| Physical Reads | 2 |
| Elapsed Time | 0.063045 seconds |
| CPU Time | 0.058902 seconds |

## Execution Plan Highlights

- `CUSTOMERS` and `ACCOUNTS` were fully scanned because the report consolidates the complete customer portfolio.
- Oracle used an index join for the small `CURRENCIES` table.
- Hash outer joins preserved customers without matching accounts or currency records.
- `SORT GROUP BY` supported the account counts and `LISTAGG` operations.
- The final `SORT ORDER BY` processed 10,002 customer rows.
- All sort operations remained in memory.
- Oracle generated an adaptive plan, but no inefficient alternative branch was observed.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| `CUSTOMERS` scan | 10,000 | 10,002 |
| `ACCOUNTS` scan | 21,000 | 21,000 |
| Joined rows | 21,000 | 21,002 |
| Grouped result | 10,000 | 10,002 |
| Final result | 10,000 | 10,002 |

Optimizer estimates closely matched the actual row counts throughout the main execution path.

## Assessment

The full scans are appropriate because the query reads and consolidates the complete account and customer populations.

The selected hash joins, index join, sort-based grouping, and final ordering are suitable for the current workload.

The `LISTAGG` operations required a larger in-memory group sort, but no temporary-disk spill or excessive I/O was observed.

## Optimization Decision

| Item | Decision |
|---|---|
| SQL Rewrite Required | No |
| Additional Index Required | No |
| Optimizer Hint Required | No |
| Statistics Collection Required | No |
| Adaptive Plan Review Required | No |

## Final Status

**Performance Review:** Passed

**Optimization Required:** No
