# PL/SQL Tests

This directory contains regression tests for the project's **9 packages and 7 triggers**.

## Package Tests

```text
01_PKG_ERROR_LOG_Test.sql
02_PKG_AUDIT_Test.sql
03_PKG_CUSTOMER_MANAGEMENT_Test.sql
04_PKG_ACCOUNT_MANAGEMENT_Test.sql
05_PKG_BENEFICIARY_MANAGEMENT_Test.sql
06_PKG_CARD_MANAGEMENT_Test.sql
07_PKG_EXCHANGE_RATE_MANAGEMENT_Test.sql
08_PKG_TRANSACTION_MANAGEMENT_Test.sql
09_PKG_LOG_MAINTENANCE_Test.sql
```

## Trigger Tests

```text
01_NO_DELETE_TRIGGERS_Test.sql
02_UPDATE_AUDIT_TRIGGERS_Test.sql
03_TRANSACTION_STATUS_HISTORY_TRIGGER_Test.sql
04_SCHEMA_DDL_AUDIT_TRIGGER_Test.sql
```

## Safety

Tests that modify business data use savepoints and rollback where possible.

Autonomous error or DDL-audit records are removed with targeted cleanup because caller rollback cannot remove independently committed rows.

`04_SCHEMA_DDL_AUDIT_TRIGGER_Test.sql` intentionally executes DDL against a temporary test object; Oracle DDL performs implicit transaction control, so this test should be run in a dedicated test session with no unrelated pending transaction.

Sequence and identity gaps caused by test execution are expected and are not treated as data residue.

Each suite prints a final pass/fail summary.
