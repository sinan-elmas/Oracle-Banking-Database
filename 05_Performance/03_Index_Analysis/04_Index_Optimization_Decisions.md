# Index Optimization Decisions

## Overview

This document consolidates the findings from the index optimization analysis performed for the Oracle Banking Database project.

The review combines evidence from:

- Index usage observations
- Index selectivity statistics
- Foreign-key leading-column coverage
- Execution plan behavior
- Current reporting workload characteristics

The purpose is to document whether any index should be added, redesigned, monitored further, or considered for removal.

No index was created, altered, disabled, monitored, rebuilt, or dropped during this review.

---
## Analysis Inputs

The final decisions are based on the following documents:

- `01_Index_Usage_Evidence.md`
- `02_Index_Selectivity_Analysis.md`
- `03_Index_Coverage_Analysis.md`
- Execution plan analyses for Reports 01–15

These analyses provide complementary evidence and should not be interpreted independently.

---
## Current Index Landscape

| Metric | Value |
|---|---:|
| Application / Constraint Indexes | 81 |
| Oracle-Managed LOB Indexes | 8 |
| Primary Key Constraints | 26 |
| Unique Constraints | 26 |
| Foreign Key Constraints | 28 |
| Function-Based Indexes | 1 |
| Bitmap Indexes | 0 |
| Foreign-Key Coverage | 100% |

The schema has complete foreign-key leading-column coverage and contains no identified missing foreign-key index.

---
## Usage Evidence Assessment

Eighteen indexes were observed in execution plans currently available in the shared pool.

The observed indexes include:

- Primary-key indexes
- Unique indexes
- Foreign-key indexes
- Customer relationship indexes
- Account relationship indexes
- Transaction relationship indexes

The most frequently observed indexes supported:

- Currency lookup
- Account lookup
- Customer-based account access
- Branch-based account access
- Transaction type and channel lookup
- Source-account transaction access

Indexes not observed in the shared pool cannot be classified as unused.

The shared pool represents only a temporary subset of workload history and may change after cursor aging, instance restart, or shared-pool flush.

---
## Selectivity Assessment

The schema contains a balanced mix of high-, medium-, and low-selectivity indexes.

### High-Selectivity Indexes

Primary-key and unique indexes generally provide near-perfect selectivity and support:

- Point lookups
- Constraint enforcement
- Unique business-key access
- Selective joins

These indexes are appropriate and should be retained.

### Medium-Selectivity Indexes

Customer, account, address, and beneficiary relationship indexes provide useful selectivity for joins and reporting access paths.

Examples include:

- `IDX_ACCOUNTS_CUSTOMER_ID`
- `IDX_ADDR_CUSTOMER_ID`
- `IDX_BENEF_CUSTOMER_ID`
- `IDX_BENEF_ACCOUNT_ID`
- `IDX_CC_CUSTOMER_ID`

These indexes support recurring customer-centric access patterns and should be retained.

### Low-Selectivity Indexes

Indexes on columns such as transaction channel, transaction type, currency, and account type naturally have low selectivity.

Examples include:

- `IDX_TR_CHANNEL_ID`
- `IDX_TR_TYPE_ID`
- `IDX_TR_CURRENCY_ID`
- `IDX_ACCOUNTS_TYPE_ID`
- `IDX_ACCOUNTS_CURRENCY_ID`

Low selectivity alone is not evidence that these indexes are unnecessary.

They may still support:

- Foreign-key joins
- Selective transactional queries
- Referential operations
- Index-only scans
- Future workload patterns

No low-selectivity index is recommended for removal solely because of its selectivity ratio.

---
## Foreign-Key Coverage Assessment

All 28 foreign-key constraints are covered by indexes whose leading columns match the foreign-key column list in the correct order.

This provides support for:

- Child-row lookup
- Join performance
- Parent-row update and delete operations
- Reduced locking risk
- Referential workload scalability

No additional foreign-key index is required.

---
## Execution Plan Evidence

Execution plan analysis for Reports 01–15 showed that Oracle selected indexes where they provided a measurable benefit.

Observed access paths included:

- `INDEX UNIQUE SCAN`
- `INDEX RANGE SCAN`
- `INDEX FAST FULL SCAN`

Oracle also selected full table scans where the reporting workload processed a large percentage of the underlying table.

This was especially appropriate for analytical queries involving:

- Most successful transactions
- Complete customer populations
- Complete account portfolios
- Monthly and branch-level aggregation
- `PIVOT`, `ROLLUP`, and `GROUPING SETS`

The observed full table scans do not indicate missing indexes.

---
## Additional Index Decision

| Candidate Area | Decision | Reason |
|---|---|---|
| Customer reporting | No new index | Existing customer relationship indexes were used effectively |
| Account reporting | No new index | Customer, branch, currency, and type indexes already exist |
| Transaction reporting | No new index | Reports process large portions of the table; full scans are appropriate |
| Exchange-rate lookup | No new index | Table is very small and current access is efficient |
| Branch reporting | No new index | Existing branch and account indexes provide adequate coverage |
| Foreign-key columns | No new index | Leading-column coverage is 100% |
| Dashboard queries | No new index | Current plans complete efficiently using hash joins and aggregation |

No additional index is justified by the collected runtime evidence.

---
## Index Removal Decision

No index is recommended for removal.

Reasons include:

- Shared-pool evidence is not a complete workload history.
- Several indexes support constraints.
- Several indexes provide foreign-key coverage.
- Low selectivity does not prove lack of value.
- Some indexes may support transactional SQL not included in the reporting workload.
- No representative long-term monitoring period has been completed.
- No index has been tested using invisibility or controlled workload comparison.

Removing an index without stronger evidence would introduce unnecessary operational risk.

---
## Index Redesign Decision

No index redesign is currently required.

The existing index structures are consistent with:

- Constraint requirements
- Foreign-key access paths
- Customer-centric reporting
- Account-centric reporting
- Transaction relationships
- Current optimizer behavior

Composite indexes should not be introduced without a demonstrated workload benefit because they may:

- Increase DML cost
- Increase storage usage
- Duplicate existing indexes
- Add maintenance overhead
- Provide no benefit for broad analytical scans

---
## Monitoring Recommendations

The following actions may be considered in a future production-like workload:

1\. Observe index usage over a representative business period.

2\. Review AWR and ASH data where licensed and available.

3\. Compare top SQL access paths over time.

4\. Test questionable indexes as invisible before removal.

5\. Measure DML overhead before adding composite indexes.

6\. Reassess indexes after significant data growth or workload change.

These are future validation steps, not current optimization requirements.

---
## Final Decisions

| Item | Decision |
|---|---|
| Add New Indexes | No |
| Remove Existing Indexes | No |
| Redesign Existing Indexes | No |
| Rebuild Indexes | No evidence required |
| Gather Additional Index Statistics | No current requirement |
| Foreign-Key Index Remediation | Not required |
| Continue Monitoring | Yes |
| Current Index Strategy | Accepted |

---
## Conclusion

The Oracle Banking Database schema has a complete and balanced indexing strategy for the current workload.

The existing indexes support constraints, joins, foreign-key access paths, selective lookups, and analytical reporting where appropriate.

Execution plan evidence confirms that Oracle uses indexes selectively and chooses full table scans when broad data access is more efficient.

No index addition, removal, or redesign is justified by the current evidence.

The final optimization decision is to retain the existing index structure and continue evidence-based monitoring as workload volume and usage patterns evolve.
