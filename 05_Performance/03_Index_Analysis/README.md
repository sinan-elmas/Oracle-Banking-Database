# Index Analysis

This directory evaluates the current indexing strategy using schema metadata, optimizer statistics, and cached execution-plan evidence.

## Contents

| File | Purpose |
|---|---|
| `01_Index_Usage_Evidence.sql` / `.md` | Shared-pool evidence of index usage |
| `02_Index_Selectivity_Analysis.sql` / `.md` | Selectivity, clustering factor, and index statistics |
| `03_Index_Coverage_Analysis.sql` / `.md` | Constraint and foreign-key leading-column index coverage |
| `04_Index_Optimization_Decisions.md` | Final index optimization decisions |

## Key Findings

The reviewed inventory contained:

| Metric | Value |
|---|---:|
| Application / Constraint Indexes | 81 |
| Oracle-Managed LOB Indexes | 8 |
| Total `USER_INDEXES` Rows | 89 |
| Function-Based Indexes | 1 |
| Bitmap Indexes | 0 |
| Foreign Keys | 28 |

The collected analysis reported leading-column index coverage for all 28 foreign keys.

Shared-pool observations are treated as evidence only: an index marked `NOT OBSERVED` is not automatically classified as unused.

## Decision

No additional index creation, rebuild, disable, or drop operation was justified by the collected evidence.

## Safety

The SQL scripts are read-only and do not modify indexes or optimizer statistics.
