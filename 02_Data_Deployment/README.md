# Data Deployment

This module provides the controlled data deployment workflow for the **Oracle Banking Database** project.

Oracle Data Pump is used to export the reusable banking dataset from the source Oracle environment and import it into an existing, empty target schema.

This module handles **data deployment only**.

Database structures and PL/SQL application objects are maintained separately by the project.

---

## Purpose

The Data Deployment module is designed to:

- Preserve the reusable banking dataset in Oracle Data Pump dump files
- Explicitly control which project tables belong to the portable dataset
- Exclude environment-specific audit and diagnostic history
- Verify dump-file integrity with SHA-256 checksums
- Provide a controlled and repeatable import workflow
- Protect target environments with pre-import validation
- Synchronize application-managed sequences after data loading
- Validate imported data before a target dataset is accepted

---

## Directory Structure

```text
02_Data_Deployment/
├── 01_Data_Export/
│   ├── 01_Data_Export_Precheck.sql
│   ├── 02_Grant_Data_Pump_Directory.sql
│   ├── 03_Export_All_Table_Data.par
│   ├── 04_Export_All_Table_Data.ps1
│   ├── 05_Verify_Export_Files.ps1
│   ├── export_output/
│   │   ├── banking_data_01.dmp
│   │   ├── banking_data_02.dmp
│   │   ├── banking_data_export.log
│   │   └── checksums.sha256
│   └── README.md
├── 02_Data_Import/
│   ├── 01_Data_Import_Precheck.sql
│   ├── 02_Import_All_Table_Data.par
│   ├── 03_Import_All_Table_Data.ps1
│   ├── 04_Synchronize_Application_Sequences.sql
│   ├── 05_Data_Import_Postcheck.sql
│   └── README.md
└── README.md
```

The module is divided into two stages:

| Directory | Purpose |
|---|---|
| `01_Data_Export` | Creates and verifies the reusable banking dataset |
| `02_Data_Import` | Loads and validates the dataset in an existing empty target schema |

---

## Deployment Architecture

The overall workflow is:

```text
Source BANKING_DB
       │
       │ Oracle Data Pump Export
       │ expdp
       ▼
┌───────────────────────────────┐
│ banking_data_01.dmp           │
│ banking_data_02.dmp           │
│ banking_data_export.log       │
│ checksums.sha256              │
└───────────────────────────────┘
       │
       │ SHA-256 verification
       ▼
Portable Banking Dataset
       │
       │ Oracle Data Pump Import
       │ impdp
       ▼
Target BANKING_DB
       │
       ├── Application sequence synchronization
       │
       └── Post-import validation
```

The dump files contain table data rather than a complete database installation.

The target schema structure must therefore already exist before the dataset is imported.

---

## Dataset Scope

The Oracle Banking Database contains **26 project tables**.

The reusable Data Pump dataset contains data from **23 tables**.

### Included Tables

```text
ACCOUNTS
ACCOUNT_TYPES
BENEFICIARIES
BRANCHES
CARDS
CARD_TYPES
CITIES
COMPANIES
CONTACT_TYPES
CORPORATE_CUSTOMERS
COUNTRIES
CURRENCIES
CUSTOMERS
CUSTOMER_ADDRESSES
CUSTOMER_CONTACTS
DISTRICTS
EXCHANGE_RATES
INDIVIDUAL_CUSTOMERS
SECTORS
TRANSACTIONS
TRANSACTION_CHANNELS
TRANSACTION_STATUS_HISTORY
TRANSACTION_TYPES
```

`TRANSACTION_STATUS_HISTORY` remains part of the dataset even when the current export contains zero rows for that table.

### Excluded Operational Tables

The following three project tables are intentionally excluded:

```text
AUDIT_LOGS
DDL_AUDIT_LOGS
ERROR_LOGS
```

These tables contain source-environment operational history rather than reusable banking data.

Their table structures remain part of the project, but existing source rows are not transferred.

This allows each target environment to generate its own audit, DDL audit, and error history.

---

## Source Dataset Snapshot

The current verified export was created from:

```text
Schema : BANKING_DB
PDB    : ORCLPDB1
```

Major table volumes include:

| Table | Rows |
|---|---:|
| `TRANSACTIONS` | 200,000 |
| `CUSTOMER_CONTACTS` | 22,850 |
| `ACCOUNTS` | 21,000 |
| `BENEFICIARIES` | 15,644 |
| `CUSTOMER_ADDRESSES` | 14,293 |
| `CUSTOMERS` | 10,003 |
| `INDIVIDUAL_CUSTOMERS` | 9,002 |
| `CARDS` | 7,866 |
| `COMPANIES` | 1,001 |
| `CORPORATE_CUSTOMERS` | 1,001 |
| `DISTRICTS` | 973 |

Complete expected row counts are documented by the export and import modules.

These values belong to the current verified dump set and may change when a new dataset version is exported.

---

## 01 - Data Export

`01_Data_Export` creates and verifies the portable banking dataset.

The export workflow is:

```text
Source validation
       ↓
Data Pump directory validation
       ↓
Explicit 23-table export scope
       ↓
Oracle Data Pump Export
       ↓
Dump files copied to Windows
       ↓
SHA-256 checksum generation
       ↓
Checksum verification
```

### Export Precheck

`01_Data_Export_Precheck.sql` performs read-only validation before export.

It checks:

- Current database context
- Expected 26 project tables
- 23 included dataset tables
- 3 excluded operational tables
- Source row counts
- Data Pump directory availability
- Required directory privileges
- Final export inventory

This prevents an export from being treated as valid without confirming its source scope.

### Data Pump Directory Access

`02_Grant_Data_Pump_Directory.sql` grants the required:

```text
READ
WRITE
```

privileges on `DATA_PUMP_DIR`.

The script documents the verified source Docker/PDB environment and must be executed with an appropriately privileged administrative account.

### Data Pump Export

`03_Export_All_Table_Data.par` defines the Data Pump export.

Core settings include:

```text
DIRECTORY=DATA_PUMP_DIR
DUMPFILE=banking_data_%U.dmp
LOGFILE=banking_data_export.log
CONTENT=DATA_ONLY
FLASHBACK_TIME=systimestamp
PARALLEL=2
FILESIZE=1G
LOGTIME=ALL
METRICS=YES
```

The export scope is explicitly limited to the 23 reusable dataset tables.

`CONTENT=DATA_ONLY` is used because structural database objects are version controlled separately under `01_Database_Design`.

### Export Automation

`04_Export_All_Table_Data.ps1` automates the verified Windows and Docker export workflow.

The script:

1. Verifies Docker availability.
2. Verifies the configured container.
3. Copies the Data Pump parameter file into the container.
4. Removes previous export artifacts with the same project names.
5. Executes `expdp`.
6. Verifies that dump pieces and the export log were generated.
7. Copies the generated artifacts to Windows.

Database passwords are not stored in the PowerShell script.

### Export Verification

`05_Verify_Export_Files.ps1` verifies the generated dump set.

The documented export contains:

```text
banking_data_01.dmp
banking_data_02.dmp
banking_data_export.log
checksums.sha256
```

The verification process:

- Confirms that the expected artifacts exist
- Confirms that the current dump set contains two pieces
- Calculates SHA-256 hashes
- Writes the hashes to `checksums.sha256`
- Recalculates the hashes
- Confirms that both dump files match the recorded values

The current dump set passed SHA-256 verification.

---

## Verified Export Artifacts

The current verified export artifacts are:

| File | Purpose |
|---|---|
| `banking_data_01.dmp` | Data Pump dump piece |
| `banking_data_02.dmp` | Data Pump dump piece |
| `banking_data_export.log` | Data Pump execution log |
| `checksums.sha256` | SHA-256 integrity information |

The verified SHA-256 values are:

```text
a3e7fe9c971c8b2f91d1f3a1ca7cef76b39149f3fc157c7e80f5bb1199baf89e  banking_data_01.dmp
815db6236f2d7d5d0bb0721bd175ff35b283fcbca67070fc06b01df43520f720  banking_data_02.dmp
```

These values belong specifically to the current dump set.

A new export must be treated as a new dataset version and must generate new checksums.

---

## 02 - Data Import

`02_Data_Import` provides the controlled workflow for loading the verified dump set into a target `BANKING_DB` schema.

The target schema structure must already exist.

The import workflow is:

```text
Target schema validation
       ↓
Local dump checksum verification
       ↓
Dump files copied to Oracle container
       ↓
Container checksum verification
       ↓
Oracle Data Pump Import
       ↓
Import log validation
       ↓
Application sequence synchronization
       ↓
Post-import validation
```

---

## Import Precheck

`01_Data_Import_Precheck.sql` performs read-only target validation before Data Pump Import.

It checks:

- Current database context
- Expected 26 project tables
- 23 included tables
- 3 excluded operational tables
- Existing row counts
- Constraint availability
- Identity-column inventory
- Application sequences
- Data Pump directory availability
- Required directory privileges

The critical readiness condition is:

```text
INCLUDED_TABLE_ROWS_BEFORE_IMPORT = 0
RESULT                            = PASS
```

The import must not continue when any of the 23 included target tables already contains rows.

---

## Data Pump Import

`02_Import_All_Table_Data.par` defines the import operation.

Core settings include:

```text
DIRECTORY=DATA_PUMP_DIR
DUMPFILE=banking_data_%U.dmp
LOGFILE=banking_data_import.log
CONTENT=DATA_ONLY
TABLE_EXISTS_ACTION=APPEND
PARALLEL=2
LOGTIME=ALL
METRICS=YES
```

Only table data is loaded.

The target database structures must already exist.

### TABLE_EXISTS_ACTION

The import uses:

```text
TABLE_EXISTS_ACTION=APPEND
```

This is safe for the documented workflow only because the import precheck requires all 23 included target tables to be empty before import.

The precheck and Data Pump parameter file must therefore always be considered together.

---

## Dump Integrity Verification

`03_Import_All_Table_Data.ps1` validates the current dump set before Data Pump Import.

The script verifies:

1. Both expected local dump files exist.
2. `checksums.sha256` exists.
3. Each local dump file matches its recorded SHA-256 value.
4. Both dump files are copied into the Oracle container.
5. Each copied dump file is hashed again inside the container.
6. Each container hash matches the same expected checksum.

If any checksum comparison fails, the workflow stops before Data Pump Import is accepted.

This provides an integrity boundary between export and import.

---

## Import Automation

The PowerShell workflow also:

- Verifies Docker availability
- Confirms that the configured Oracle container is running
- Copies the import parameter file into the container
- Removes an old import log with the same project name
- Requires explicit `IMPORT` confirmation
- Starts `impdp`
- Confirms that the import log was created
- Copies the import log back to Windows
- Searches the log for `ORA-xxxxx` errors
- Confirms that the Data Pump successful-completion message is present

The database password is requested interactively and is not stored in the script.

---

## Application Sequence Synchronization

A `DATA_ONLY` import restores table values but does not automatically reposition the explicitly managed application sequences.

The following sequences therefore require post-import synchronization:

```text
CARD_SEQ
SEQ_CUSTOMER_NO
```

`04_Synchronize_Application_Sequences.sql` performs this operation.

### CARD_SEQ

The required position is derived from:

```text
MAX(CARDS.CARD_ID) + 1
```

### SEQ_CUSTOMER_NO

The required position is derived from the greatest numeric suffix already present in:

```text
CUSTOMERS.CUSTOMER_NO
```

plus one.

The synchronization script:

- Validates imported customer-number format
- Determines required sequence positions from the imported data
- Reads the current sequence state
- Moves a sequence forward only when required
- Does not intentionally move a sequence backward
- Restores `INCREMENT BY 1`
- Performs post-synchronization validation

Sequence runtime values are consumed as part of this operation.

---

## Post-Import Validation

`05_Data_Import_Postcheck.sql` validates the deployed dataset after:

```text
Data Pump Import
        ↓
Application Sequence Synchronization
```

The postcheck includes:

- Imported table row counts
- Total imported row count
- Excluded operational table status
- Customer subtype consistency
- Selected orphaned relationship checks
- Selected business-rule checks
- Customer-number format
- Individual customer name normalization
- Constraint health
- Application sequence safety
- Oracle-managed identity sequence safety
- Invalid schema objects

Any failure must be reviewed before the target dataset is accepted.

---

## Customer Subtype Validation

The customer model uses:

```text
CUSTOMERS
├── INDIVIDUAL_CUSTOMERS
└── CORPORATE_CUSTOMERS
```

Post-import checks validate:

- Total subtype rows against total customer rows
- Individual customer mappings
- Corporate customer mappings
- Customers incorrectly present in both subtype tables

The expected invalid or conflicting row count is:

```text
0
```

---

## Relationship Validation

The postcheck includes explicit orphan checks for critical relationships such as:

- Accounts without customers
- Accounts without branches
- Cards without accounts
- Beneficiaries without customers
- Beneficiaries without referenced accounts
- Transactions without source accounts
- Invalid transaction target-account references
- Transaction status-history rows without transactions

The expected result for each orphan condition is:

```text
0
```

---

## Business-Rule Validation

Selected imported-data conditions include:

```text
Negative account balances
Nonpositive transaction amounts
Same source and target account
Invalid customer-number formats
Invalid individual customer name casing
```

The expected count for each invalid condition is:

```text
0
```

---

## Constraint Validation

The expected constraint state is:

```text
STATUS    = ENABLED
VALIDATED = VALIDATED
```

Disabled or unvalidated constraints require investigation before the imported dataset is accepted.

---

## Sequence Validation

Application-managed sequences are validated against the imported data.

Oracle-managed identity sequences are validated separately.

For identity columns, the associated Oracle-managed sequence must remain positioned safely beyond the greatest imported identity value.

Oracle-generated `ISEQ$$_...` names are not manually recreated.

---

## Invalid Object Validation

The postcheck reports schema objects whose status is not:

```text
VALID
```

Unexpected invalid objects must be reviewed before the target environment is accepted.

---

## Deployment Safety

The workflow follows the following safety principles.

### Explicit Data Scope

Only the intended 23 reusable banking tables are exported and imported.

### No Source Log Migration

Source audit and diagnostic history is excluded from the portable banking dataset.

### Empty Target Requirement

Import is allowed only after confirming that all 23 included target tables are empty.

### File Integrity Verification

Dump pieces are protected with SHA-256 verification before and after transfer into the Oracle container.

### Interactive Authentication

Database passwords are not stored in PowerShell automation scripts.

### Controlled Sequence Handling

Application-managed sequences are synchronized after data loading instead of assuming their runtime state is automatically safe.

### Post-Deployment Validation

Successful execution of `impdp` alone is not considered sufficient evidence of a valid target deployment.

Database-level post-import validation must also succeed.

---

## Execution Summary

### Export

```text
01_Data_Export_Precheck.sql
        ↓
02_Grant_Data_Pump_Directory.sql
        ↓
03_Export_All_Table_Data.par
        ↓
04_Export_All_Table_Data.ps1
        ↓
05_Verify_Export_Files.ps1
```

The `.par` file is consumed by the PowerShell/Data Pump workflow.

### Import

```text
01_Data_Import_Precheck.sql
        ↓
02_Import_All_Table_Data.par
        ↓
03_Import_All_Table_Data.ps1
        ↓
04_Synchronize_Application_Sequences.sql
        ↓
05_Data_Import_Postcheck.sql
```

The `.par` file is consumed by the import automation.

---

## Acceptance Criteria

A target deployment should be accepted only after the relevant stages have completed successfully:

```text
Import precheck
        ↓
Dump checksum verification
        ↓
Data Pump import
        ↓
Import log validation
        ↓
Application sequence synchronization
        ↓
Imported row-count validation
        ↓
Relationship and business-rule validation
        ↓
Constraint validation
        ↓
Application sequence validation
        ↓
Identity sequence validation
        ↓
Invalid object validation
```

A Data Pump successful-completion message by itself is not sufficient to establish complete deployment validity.

---

## Environment Scope

The current PowerShell automation documents the verified **Windows + Docker** data deployment environment.

Environment-specific defaults include values such as:

```text
Docker Container : oracle_ee_23ai
Database Service : ORCLPDB1
```

The physical `DATA_PUMP_DIR` path used in that Docker environment is also environment-specific.

These values should not be treated as generic Oracle installation paths.

A different Oracle environment may require different:

- Host execution methods
- Container names
- Database services
- Oracle directory objects
- Physical Data Pump paths
- File-transfer procedures

The logical dataset scope remains defined by the Data Pump parameter files and validation scripts.

---

## Validation Status

The export workflow was executed against the project source database.

The resulting dump set was created successfully and both dump pieces passed SHA-256 verification.

The import module provides the corresponding controlled target-deployment workflow.

This documentation does **not** claim a completed clean-target import unless a specific target execution and its validation evidence are retained separately.

A target deployment should be considered accepted only after its own import and post-import validation complete successfully.

---

## Project Integration

The Data Deployment module depends on structural schema definitions maintained under:

```text
01_Database_Design/
```

PL/SQL application objects are maintained separately under:

```text
04_PLSQL/
```

The Data Deployment module is responsible specifically for the **controlled movement, integrity verification, and deployment of the banking dataset** between Oracle environments.