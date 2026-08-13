# Testing

This module contains the validation and regression framework for the **Oracle Banking Database** project.

## Target Environment

- Oracle AI Database 26ai Enterprise Edition
- Version `23.26.1.0.0`
- Schema `BANKING_DB`

## Structure

```text
06_Testing/
├── 01_Schema_Validation/
├── 02_Data_Integrity/
├── 03_SQL_Report_Validation/
├── 04_PLSQL_Tests/
├── 05_Integration_And_Regression/
├── 06_Test_Results/
└── README.md
```

| Module | Purpose |
|---|---|
| `01_Schema_Validation` | Object, constraint, index, and PL/SQL health checks |
| `02_Data_Integrity` | Row-count, referential, uniqueness, business-rule, and cross-table checks |
| `03_SQL_Report_Validation` | Reporting-grain and aggregate reconciliation for all 15 SQL reports |
| `04_PLSQL_Tests` | Package and trigger regression tests |
| `05_Integration_And_Regression` | End-to-end banking workflow tests |
| `06_Test_Results` | Recorded test outcomes and final PL/SQL object-health summary |

## Test Strategy

```text
Schema Validation
       ↓
Data Integrity
       ↓
SQL Report Validation
       ↓
PL/SQL Package and Trigger Tests
       ↓
Integration and Regression Tests
       ↓
Final Object Health
```

Read-only validation scripts do not modify application data. Regression and integration tests use savepoints, rollback, or targeted cleanup where data changes are required.

Autonomous audit/error records may require targeted cleanup. Sequence and identity values can advance during testing; gaps are expected Oracle behavior.

## Recorded Status

The retained project results document:

```text
Package test suites     : 9 PASS
Trigger test suites     : 4 PASS
Integration test suites : 3 PASS
Failed suites           : 0

Package specifications  : 9 / 9 VALID
Package bodies          : 9 / 9 VALID
Triggers                : 7 / 7 VALID and ENABLED
Compilation errors      : 0

Final object health     : PASS
Overall status          : PASS
```

Detailed results are documented under `06_Test_Results`.
