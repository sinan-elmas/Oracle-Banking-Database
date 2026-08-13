# Index Usage Evidence

## Overview

This document summarizes index usage evidence collected from the SQL execution plans currently stored in the Oracle shared pool.

The objective is to identify which indexes have recently appeared in cached execution plans. This report does not determine whether an index is permanently used or unused.

No indexes were created, modified, monitored, or removed during this analysis.

---
## Analysis Method

Index usage evidence was collected by examining cached execution plans stored in `V$SQL_PLAN`.

The analysis compared:

- Indexes defined in the current schema
- Indexes referenced by cached execution plans

Only execution plans currently available in the shared pool were evaluated.

---
## Environment

| Component | Value |
|---|---|
| Database | Oracle AI Database 26ai |
| Database Version | 23.26.1.0.0 |
| Schema | `BANKING_DB` |

---
## Summary

| Metric | Value |
|---|---:|
| Total Indexes | 81 |
| Observed in Shared Pool | 18 |
| Not Observed | 63 |
| Observation Rate | 22.22% |

---
## Key Observations

The following indexes appeared most frequently in cached execution plans:

| Index | Distinct SQL Statements |
|---|---:|
| SYS_C008924 | 16 |
| SYS_C008876 | 8 |
| SYS_C008925 | 7 |
| SYS_C008903 | 6 |
| UQ_TRANSACTION_CHANNELS_NAME | 6 |
| IDX_ACCOUNTS_CUSTOMER_ID | 5 |
| IDX_ACCOUNTS_CURRENCY_ID | 4 |
| SYS_C008945 | 4 |

Both primary-key and non-constraint indexes were observed in execution plans, indicating that the optimizer selected the existing indexing strategy where appropriate.

---
## Access Path Observations

Observed index access methods include:

- INDEX UNIQUE SCAN
- INDEX RANGE SCAN
- INDEX FAST FULL SCAN

`INDEX FAST FULL SCAN` was the most frequently selected access method for analytical SQL reports, while `INDEX RANGE SCAN` and `INDEX UNIQUE SCAN` appeared in selective lookup operations.

---
## Interpretation

This report provides evidence of index usage only for SQL statements currently represented in the shared pool.

Indexes listed as **Not Observed** cannot be classified as unused because:

- execution plans may have aged out of memory,
- the instance may have been restarted,
- the observed workload represents only a portion of application activity.

Consequently, this report should not be used as the sole basis for removing indexes.

---
## Optimization Decision

| Item | Decision |
|---|---|
| Index Inventory Valid | Yes |
| Frequently Used Indexes Identified | Yes |
| Unused Indexes Proven | No |
| Index Removal Recommended | No |
| Additional Monitoring Required | Yes |

---
## Conclusion

The collected execution plans confirm that Oracle actively utilizes several primary-key, unique, and non-constraint indexes for the analytical workload.

The current shared pool provides useful evidence of index usage; however, a longer observation period would be required before making any decisions regarding unused indexes or index removal.
