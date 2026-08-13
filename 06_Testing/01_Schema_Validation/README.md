# Schema Validation

This directory contains read-only checks for the structural health of the current application schema.

## Scripts

| Script | Purpose |
|---|---|
| `01_Object_Inventory.sql` | Inventories schema objects and validity |
| `02_Invalid_Object_Check.sql` | Reports invalid objects |
| `03_Constraint_Status_Check.sql` | Validates constraint status and validation state |
| `04_Index_Status_Check.sql` | Validates index status and visibility |
| `05_PLSQL_Object_Status_Check.sql` | Validates packages, package bodies, triggers, and compilation health |

## Expected State

- Required objects are present.
- Tested objects are `VALID`.
- Constraints are enabled and validated.
- Required indexes are usable.
- Tested triggers are enabled.
- No unexpected PL/SQL compilation errors remain.

The scripts query Oracle data dictionary views and do not modify application data or schema objects.
