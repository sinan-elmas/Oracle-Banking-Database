# Performance

This module contains developer-focused performance analysis for the **Oracle Banking Database** project.

It evaluates SQL, indexes, optimizer behavior, and PL/SQL runtime evidence without changing application data or database objects.

## Target Environment

- Oracle AI Database 26ai Enterprise Edition
- Version `23.26.1.0.0`
- Schema `BANKING_DB`
- Oracle SQL Developer 24.3.1.347
- Windows 11 / Docker

## Directory Structure

```text
05_Performance/
├── 01_Baseline/
├── 02_Execution_Plans/
├── 03_Index_Analysis/
├── 04_SQL_Tuning_Assessment/
├── 05_PLSQL_Performance_Review/
└── README.md
```

## Modules

| Directory | Purpose |
|---|---|
| `01_Baseline` | Table, index, statistics, constraint, and foreign-key baseline |
| `02_Execution_Plans` | Actual execution-plan review for the 15 SQL reports |
| `03_Index_Analysis` | Index usage evidence, selectivity, coverage, and optimization decisions |
| `04_SQL_Tuning_Assessment` | Evidence-based SQL tuning and rewrite assessment |
| `05_PLSQL_Performance_Review` | PL/SQL inventory and shared-pool SQL activity review |

## Analysis Principles

- Runtime evidence is preferred over assumptions.
- Full table scans are not treated as problems automatically.
- An index is not considered unused only because it is absent from the current shared pool.
- Additional indexes, hints, SQL rewrites, or statistics changes are recommended only when evidence justifies them.
- Point-in-time shared-pool and optimizer statistics are documented with their limitations.
- Performance analysis remains separate from the instance-level DBA monitoring module under `07_DBA/09_Performance`.

## Safety

The performance scripts are diagnostic and report-oriented.

They do not create, drop, rebuild, disable, or modify application objects or data.
