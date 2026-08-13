# Dataset Baseline

This file documents the **minimum core dataset baseline** used by `01_Row_Count_Validation.sql`.

| Table | Minimum Rows |
|---|---:|
| `CUSTOMERS` | 10,000 |
| `ACCOUNTS` | 21,000 |
| `CUSTOMER_ADDRESSES` | 14,293 |
| `CUSTOMER_CONTACTS` | 22,850 |
| `CARDS` | 7,866 |
| `TRANSACTIONS` | 200,000 |
| `BENEFICIARIES` | 15,644 |

The validation fails when a core table falls below its baseline. Controlled growth above the baseline is allowed.

This baseline should not be confused with a later exported dataset snapshot, whose row counts may be higher.
