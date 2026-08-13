# Integration and Regression

This directory validates complete workflows across multiple PL/SQL components.

## Test Suites

| Script | Workflow |
|---|---|
| `01_Customer_Account_Card_Integration_Test.sql` | Customer → Account → Card |
| `02_Transaction_And_Balance_Integration_Test.sql` | Deposit → Transfer → Withdrawal → Balance reconciliation |
| `03_Audit_And_Error_Logging_Integration_Test.sql` | Business operation → Audit/Error logging → Transaction control |

The suites verify cross-component behavior rather than isolated package procedures.

Business changes are rolled back where possible. Autonomous error-log rows are removed with targeted cleanup.

Run these tests only in a controlled test environment.
