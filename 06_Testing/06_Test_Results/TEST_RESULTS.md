# Test Results

This document preserves the **recorded results** from the completed Oracle Banking Database test suites. Numeric assertion totals are included only where they were retained in the project records.

## Package Tests

| Package | Result | Passed | Failed |
|---|---|---:|---:|
| `PKG_ERROR_LOG` | PASS | 27 | 0 |
| `PKG_AUDIT` | PASS | 41 | 0 |
| `PKG_CUSTOMER_MANAGEMENT` | PASS | 32 | 0 |
| `PKG_ACCOUNT_MANAGEMENT` | PASS | — | 0 |
| `PKG_BENEFICIARY_MANAGEMENT` | PASS | 43 | 0 |
| `PKG_CARD_MANAGEMENT` | PASS | — | 0 |
| `PKG_EXCHANGE_RATE_MANAGEMENT` | PASS | 53 | 0 |
| `PKG_TRANSACTION_MANAGEMENT` | PASS | 47 | 0 |
| `PKG_LOG_MAINTENANCE` | PASS | 28 | 0 |

**Package suites:** 9 PASS, 0 FAIL.

The retained summary records a final `PASS` but not a numeric assertion total for `PKG_ACCOUNT_MANAGEMENT` and `PKG_CARD_MANAGEMENT`; no count is inferred.

## Trigger Tests

| Test Suite | Covered Trigger(s) | Passed | Failed | Result |
|---|---|---:|---:|---|
| No-Delete Triggers | `TRG_CUSTOMERS_NO_DELETE`, `TRG_ACCOUNTS_NO_DELETE`, `TRG_TRANSACTIONS_NO_DELETE` | 11 | 0 | PASS |
| Update-Audit Triggers | `TRG_BRANCHES_AUDIT`, `TRG_EXCHANGE_RATES_AUDIT` | 10 | 0 | PASS |
| Transaction Status History | `TRG_TRANSACTION_STATUS_HISTORY` | 14 | 0 | PASS |
| Schema DDL Audit | `TRG_SCHEMA_DDL_AUDIT` | 15 | 0 | PASS |

**Trigger suites:** 4 PASS, 0 FAIL.  
**Recorded trigger assertions:** 50 PASS, 0 FAIL.

## Integration Tests

| Test Suite | Passed | Failed | Result |
|---|---:|---:|---|
| Customer - Account - Card | 18 | 0 | PASS |
| Transaction and Balance | 18 | 0 | PASS |
| Audit and Error Logging | 12 | 0 | PASS |

**Integration suites:** 3 PASS, 0 FAIL.  
**Recorded integration assertions:** 48 PASS, 0 FAIL.

## Final PL/SQL Object Health

The retained execution of `01_Test_Execution_Summary.sql` reported:

```text
PASSED=9
FAILED=0
TOTAL=9
OVERALL_STATUS=PASS
```

Recorded object-health results:

| Check | Result |
|---|---|
| Package specifications | 9 / 9 present and `VALID` |
| Package bodies | 9 / 9 present and `VALID` |
| Triggers | 7 / 7 present, `VALID`, and `ENABLED` |
| Compilation errors | 0 |
| Specification/body pairs | 9 / 9 |

The detail queries returned no invalid tested objects, disabled tested triggers, or compilation errors.

## Overall Result

```text
Package test suites     : 9 PASS
Trigger test suites     : 4 PASS
Integration test suites : 3 PASS
Failed suites           : 0

Final object health     : PASS
Overall status          : PASS
```

These results describe the retained test executions and should not be treated as a substitute for rerunning the suites after future code changes.
