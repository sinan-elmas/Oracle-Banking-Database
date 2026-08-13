# Execution Plan Analysis

This directory contains actual execution-plan reviews for all **15 SQL reports** in `03_SQL_Reports`.

Runtime statistics were collected with `GATHER_PLAN_STATISTICS` and reviewed through `DBMS_XPLAN.DISPLAY_CURSOR`.

## Methodology

See `01_Execution_Plan_Methodology.md` for the common collection and interpretation method.

## Reports

| Report | Analysis | Status |
|---|---|---|
| 01 | Customer Portfolio Summary | Passed |
| 02 | Account Type Portfolio Analysis | Passed |
| 03 | High-Value Customers Analysis | Passed |
| 04 | Branch Performance Dashboard | Passed |
| 05 | Dormant Account Detection | Passed |
| 06 | Monthly Transaction Trend Analysis | Passed |
| 07 | Customer Transaction Activity Ranking | Passed |
| 08 | Top Transaction per Customer | Passed |
| 09 | Customer Account and IBAN Consolidation | Passed |
| 10 | Monthly Transaction Channel Pivot | Passed |
| 11 | Branch Transaction Performance Rollup | Passed |
| 12 | Transaction Type and Channel Grouping Sets | Passed |
| 13 | Executive Banking KPI Dashboard | Passed |
| 14 | Branch Portfolio and Transaction KPI Dashboard | Passed |
| 15 | Customer 360 Portfolio Dashboard | Passed |

## Result

The collected plans did not justify:

- Additional indexes
- Optimizer hints
- SQL rewrites
- Additional statistics collection solely for these reports

Minor cardinality differences were documented where observed, but they did not justify a tuning change in the captured workload.

Each report-specific Markdown file contains the captured SQL ID, plan hash value, runtime metrics, plan observations, and optimization decision.

## Safety

The analysis did not modify SQL logic, indexes, optimizer settings, application data, or database objects.
