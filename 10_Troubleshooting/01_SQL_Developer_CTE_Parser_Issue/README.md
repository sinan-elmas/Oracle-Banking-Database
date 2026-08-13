# SQL Developer CTE Parser Issue

## Problem

A valid Oracle SQL query using a Common Table Expression (CTE) with a `WITH` clause produced a parser-related error in Oracle SQL Developer.

The issue was isolated to the SQL Developer client environment rather than the SQL statement itself.

## Environment

- Oracle SQL Developer 24.3.1.347
- Java 17.0.13
- Windows

## Resolution

The issue was resolved by adding the following JVM locale settings to the SQL Developer configuration:

```text
AddVMOption -Duser.language=en
AddVMOption -Duser.country=US
AddVMOption -Duser.region=US
```

SQL Developer was restarted after the configuration change.

## Verification

After the restart, the affected CTE query executed successfully.

No SQL rewrite or database-side change was required.

## Result

SQL Developer CTE parser issue: **Resolved**
