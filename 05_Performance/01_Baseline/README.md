# Performance Baseline

This directory contains the read-only baseline used before execution-plan, index, and SQL tuning analysis.

## Contents

| File | Purpose |
|---|---|
| `01_Table_Volume_Baseline.sql` | Table row estimates, blocks, segment size, and statistics age |
| `02_Index_Inventory_Baseline.sql` | Index inventory, columns, constraint relationships, size, and statistics |
| `03_Table_Statistics_Baseline.sql` | Missing, stale, and locked table statistics |
| `04_Constraint_and_FK_Index_Review.sql` | Primary/unique/foreign-key inventory and leading-column FK index coverage |

## Baseline Snapshot

The collected baseline documented:

| Metric | Result |
|---|---:|
| Application Tables | 26 |
| Application / Constraint Indexes | 81 |
| Oracle-Managed LOB Indexes | 8 |
| Total `USER_INDEXES` Rows | 89 |
| Primary Keys | 26 |
| Unique Constraints | 26 |
| Foreign Keys | 28 |

One table had missing statistics and two tables had stale statistics at the time of collection.

These are point-in-time observations and may change after data growth, statistics collection, or schema changes.

## Safety

All scripts are read-only and do not gather statistics or modify tables, indexes, constraints, or application data.
