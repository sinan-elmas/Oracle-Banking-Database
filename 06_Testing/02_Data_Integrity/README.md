# Data Integrity

This directory validates the quality and consistency of the banking dataset.

## Scripts

| Script | Purpose |
|---|---|
| `01_Row_Count_Validation.sql` | Compares core table counts with the documented minimum baseline |
| `02_Referential_Integrity_Checks.sql` | Detects orphaned foreign-key relationships |
| `03_Duplicate_And_Uniqueness_Checks.sql` | Detects duplicate values for schema-defined unique keys |
| `04_Business_Rule_Checks.sql` | Validates selected data-level business rules |
| `05_Cross_Table_Consistency_Checks.sql` | Validates consistency across related business tables |
| `Dataset_Baseline.md` | Documents the minimum core dataset baseline |

## Interpretation

The row-count baseline is a **minimum reference**, not an exact immutable snapshot. Counts above the baseline can be valid; counts below it require review.

All scripts in this directory are read-only with respect to application data and schema objects.
