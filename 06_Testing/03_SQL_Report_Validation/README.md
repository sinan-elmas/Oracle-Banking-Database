# SQL Report Validation

This directory validates the logical correctness of the **15 SQL reports** in `03_SQL_Reports`.

## Validation Scope

`01_Report_Result_Validation.sql` checks:

- Reporting grain
- Aggregate reconciliation
- Customer and branch totals
- PIVOT reconciliation
- ROLLUP reconciliation
- GROUPING SETS reconciliation
- Executive KPI consistency
- Customer 360 reconciliation

The validation uses independent queries against the underlying tables where practical.

Execution plans and optimizer behavior are outside this module and are reviewed under `05_Performance`.

The validation script is read-only.
