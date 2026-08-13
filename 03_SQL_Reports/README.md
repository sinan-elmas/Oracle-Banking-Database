# SQL Reports

This directory contains **15 read-only analytical SQL reports** developed for the Oracle Banking Database project.

The reports cover customer portfolios, accounts, branches, transactions, channels, currencies, and executive KPIs while demonstrating advanced Oracle SQL reporting techniques.

## Target Environment

- Oracle AI Database 26ai Enterprise Edition
- Version `23.26.1.0.0`
- Schema `BANKING_DB`
- Oracle SQL Developer 24.3.1.347
- Windows 11 / Docker

## Reports

| Report | Description |
|---|---|
| `Report_01_Customer_Portfolio_Summary.sql` | Customer portfolio summary by currency |
| `Report_02_Account_Type_Portfolio_Analysis.sql` | Account type portfolio analysis by currency |
| `Report_03_High_Value_Customers_Analysis.sql` | High-value customers analysis |
| `Report_04_Branch_Performance_Dashboard.sql` | Branch performance dashboard |
| `Report_05_Dormant_Account_Detection.sql` | Dormant account detection |
| `Report_06_Monthly_Transaction_Trend_Analysis.sql` | Monthly transaction trend and growth analysis |
| `Report_07_Customer_Transaction_Activity_Ranking.sql` | Customer transaction activity ranking |
| `Report_08_Top_Transaction_Per_Customer.sql` | Highest-value transaction per customer |
| `Report_09_Customer_Account_And_IBAN_Consolidation.sql` | Customer account and IBAN consolidation |
| `Report_10_Monthly_Transaction_Channel_Pivot.sql` | Monthly transaction channel pivot |
| `Report_11_Branch_Transaction_Performance_Rollup.sql` | Branch transaction performance with `ROLLUP` |
| `Report_12_Transaction_Type_And_Channel_Grouping_Sets.sql` | Transaction type and channel analysis with `GROUPING SETS` |
| `Report_13_Executive_Banking_KPI_Dashboard.sql` | Executive banking KPI dashboard |
| `Report_14_Branch_Portfolio_And_Transaction_KPI_Dashboard.sql` | Branch portfolio and transaction KPI dashboard |
| `Report_15_Customer_360_Portfolio_Dashboard.sql` | Customer 360 portfolio dashboard |

## SQL Features

The report set demonstrates:

- Common Table Expressions (CTEs)
- Aggregate and conditional aggregation
- Analytic functions
- `ROW_NUMBER`
- `DENSE_RANK`
- `CUME_DIST`
- `LAG`
- `LISTAGG`
- `PIVOT`
- `ROLLUP`
- `GROUPING`
- `GROUPING SETS`
- `CASE`
- `NVL` and `NULLIF`
- `INNER JOIN`, `LEFT JOIN`, and `CROSS JOIN`
- Currency conversion and reporting-currency logic

## Dataset

The current documented dataset snapshot includes:

| Entity | Rows |
|---|---:|
| Customers | 10,003 |
| Accounts | 21,000 |
| Transactions | 200,000 |
| Cards | 7,866 |
| Beneficiaries | 15,644 |
| Customer Addresses | 14,293 |
| Customer Contacts | 22,850 |
| Branches | 50 |
| Currencies | 8 |

## Reporting Notes

- Reports are read-only and can be executed independently.
- Reports that require a common reporting currency use **TRY**.
- Foreign-currency valuations use exchange-rate data stored in the database.
- Raw balances or transaction amounts from different currencies are not combined unless the report explicitly converts them to a common reporting currency.
- Each report documents its reporting grain and important assumptions in the SQL header.

## Execution

Connect to the `BANKING_DB` schema in Oracle SQL Developer, open the required report, and execute it with **Run Script (F5)**.

## Validation

The report set is covered by the SQL report validation module under:

```text
06_Testing/03_SQL_Report_Validation/
```

Validation includes reporting-grain checks and aggregate reconciliation for all 15 reports.

## Safety

All scripts in this directory are query-only reporting scripts.

They do not create, alter, or delete database objects and do not modify application data.
