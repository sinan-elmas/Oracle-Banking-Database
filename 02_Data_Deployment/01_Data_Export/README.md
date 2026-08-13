# Data Export

This directory contains the verified Oracle Data Pump export workflow used to create the reusable data deployment set for the **Oracle Banking Database** project.

The export contains business and reference data only. Database structures are maintained separately under `01_Database_Design`.

The workflow was executed in the project's Windows and Docker-based source database environment.

---

## Export Scope

The Oracle Banking Database schema contains **26 project tables**.

The reusable Data Pump dataset includes data from **23 tables**.

Existing rows from the following three operational logging tables are intentionally excluded:

```text
AUDIT_LOGS
DDL_AUDIT_LOGS
ERROR_LOGS
```

Their table structures remain part of the database design and are created in the target schema, but source-environment audit and diagnostic history is not transported.

---

## Included Tables

The following 23 tables are included in the Data Pump export:

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

`TRANSACTION_STATUS_HISTORY` is intentionally included because it belongs to the reusable banking dataset.

At the time of this export, the table contained zero rows. Its inclusion nevertheless keeps the deployment scope consistent with the implemented banking data model.

---

## Excluded Operational Data

The following tables are excluded from the data export:

```text
AUDIT_LOGS
DDL_AUDIT_LOGS
ERROR_LOGS
```

### Reason for Exclusion

`AUDIT_LOGS` contains application and data-operation audit history.

`DDL_AUDIT_LOGS` contains database object and DDL activity history.

`ERROR_LOGS` contains diagnostic and application error history.

These records represent activity that occurred in the source development environment. Copying them into a newly deployed environment would transfer operational history that did not occur in the target database.

The table structures are therefore deployed normally, while their source rows are excluded from the reusable dataset.

---

## Verified Export Row Counts

The verified export contained the following row counts:

| Table | Rows |
|---|---:|
| `ACCOUNTS` | 21,000 |
| `ACCOUNT_TYPES` | 5 |
| `BENEFICIARIES` | 15,644 |
| `BRANCHES` | 50 |
| `CARDS` | 7,866 |
| `CARD_TYPES` | 5 |
| `CITIES` | 81 |
| `COMPANIES` | 1,001 |
| `CONTACT_TYPES` | 5 |
| `CORPORATE_CUSTOMERS` | 1,001 |
| `COUNTRIES` | 8 |
| `CURRENCIES` | 8 |
| `CUSTOMERS` | 10,003 |
| `CUSTOMER_ADDRESSES` | 14,293 |
| `CUSTOMER_CONTACTS` | 22,850 |
| `DISTRICTS` | 973 |
| `EXCHANGE_RATES` | 7 |
| `INDIVIDUAL_CUSTOMERS` | 9,002 |
| `SECTORS` | 14 |
| `TRANSACTIONS` | 200,000 |
| `TRANSACTION_CHANNELS` | 5 |
| `TRANSACTION_STATUS_HISTORY` | 0 |
| `TRANSACTION_TYPES` | 6 |

The Data Pump export log confirmed processing of all **23 `TABLE_DATA` objects** in the configured export scope.

---

## Directory Contents

```text
01_Data_Export/
├── 01_Data_Export_Precheck.sql
├── 02_Grant_Data_Pump_Directory.sql
├── 03_Export_All_Table_Data.par
├── 04_Export_All_Table_Data.ps1
├── 05_Verify_Export_Files.ps1
├── export_output/
│   ├── banking_data_01.dmp
│   ├── banking_data_02.dmp
│   ├── banking_data_export.log
│   └── checksums.sha256
└── README.md
```

---

## 01 - Export Precheck

`01_Data_Export_Precheck.sql` performs read-only validation before the Data Pump export.

The script checks:

- Current database user
- Current container
- Database name
- Presence of the 26 project tables
- 23 included data tables
- 3 intentionally excluded operational log tables
- Table statistics
- Estimated table segment sizes
- Actual row counts
- Available Oracle directory objects
- Directory privileges
- Final export inventory

The precheck does not modify schema objects or table data.

---

## 02 - Data Pump Directory Access

`02_Grant_Data_Pump_Directory.sql` grants the `BANKING_DB` schema:

```text
READ
WRITE
```

on the existing Oracle directory object:

```text
DATA_PUMP_DIR
```

The script was prepared for the verified source environment:

```text
Container      : ORCLPDB1
Directory Name : DATA_PUMP_DIR
```

The corresponding physical directory in that environment was:

```text
/opt/oracle/admin/ORCLCDB/dpdump/5568D25A59CF0DCCE063030011AC2144
```

This physical path is environment-specific and documents the source Docker database used for the verified export.

The grant script requires an appropriately privileged administrative account and must be executed in the correct PDB.

---

## 03 - Data Pump Export Configuration

`03_Export_All_Table_Data.par` contains the Data Pump export configuration.

The core parameters are:

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

The parameter file also contains the explicit list of all 23 included tables.

### DATA_ONLY

```text
CONTENT=DATA_ONLY
```

is used because database structures are maintained separately by the repository.

Tables, constraints, indexes, sequences, and other structural objects are therefore not taken from this export as the authoritative schema definition.

### Consistent Export Snapshot

```text
FLASHBACK_TIME=systimestamp
```

requests a transaction-consistent Data Pump export based on the export start-time snapshot.

### Dump File Template

```text
banking_data_%U.dmp
```

allows Data Pump to generate multiple dump pieces when required by the export operation.

---

## 04 - Export Automation

`04_Export_All_Table_Data.ps1` automates the verified Windows and Docker export workflow.

Default environment values in the script include:

```text
Docker Container : oracle_ee_23ai
Database Service : ORCLPDB1
Schema User      : BANKING_DB
```

The script performs the following operations:

1. Verifies that the Docker CLI is available.
2. Verifies that the Data Pump parameter file exists.
3. Confirms that the configured Docker container is running.
4. Copies the parameter file into the Oracle container.
5. Removes previous project export files with the same names.
6. Runs Oracle Data Pump Export.
7. Verifies that dump pieces and the export log were generated.
8. Copies the generated files from the container to Windows.
9. Displays the resulting Windows export inventory.

The physical Data Pump path configured in this script belongs to the verified Docker source environment and should not be assumed to apply to another Oracle installation.

### Password Handling

The database password is not stored in the PowerShell script.

Data Pump requests the `BANKING_DB` password interactively when `expdp` starts.

---

## 05 - Export File Verification

`05_Verify_Export_Files.ps1` verifies the generated export artifacts.

For the documented export set, the expected files are:

```text
banking_data_01.dmp
banking_data_02.dmp
banking_data_export.log
```

The script:

1. Confirms that all expected files exist.
2. Displays file sizes.
3. Confirms that exactly two dump pieces exist for this export set.
4. Calculates SHA-256 hashes for both dump files.
5. Writes the hashes to `checksums.sha256`.
6. Recalculates the hashes.
7. Compares the recalculated values with the generated checksum file.
8. Reports the final verification status.

The verified result was:

```text
Expected dump pieces : 2
Verified dump pieces : 2
Checksum algorithm   : SHA-256
Overall status       : PASS
```

---

## Generated Export Set

The verified export produced:

```text
banking_data_01.dmp
banking_data_02.dmp
banking_data_export.log
checksums.sha256
```

The two dump files represent the reusable Data Pump dataset.

The export log records the Data Pump execution, while `checksums.sha256` provides integrity verification for the exact dump set.

---

## SHA-256 Checksums

The verified dump files have the following SHA-256 values:

```text
a3e7fe9c971c8b2f91d1f3a1ca7cef76b39149f3fc157c7e80f5bb1199baf89e  banking_data_01.dmp
815db6236f2d7d5d0bb0721bd175ff35b283fcbca67070fc06b01df43520f720  banking_data_02.dmp
```

These values are stored in:

```text
export_output/checksums.sha256
```

Both dump files passed checksum verification.

The checksum file belongs specifically to this dump set. If the dataset is exported again, the new dump files must be treated as a new export set and new checksums must be generated.

---

## Execution Workflow

### 1. Run the Export Precheck

Run:

```text
01_Data_Export_Precheck.sql
```

against the source `BANKING_DB` schema.

Do not continue if required project tables are missing or the configured export scope does not match the expected schema.

### 2. Verify Data Pump Directory Access

Confirm that `BANKING_DB` has:

```text
READ
WRITE
```

on the selected Oracle Data Pump directory object.

Where administrative setup is required, use:

```text
02_Grant_Data_Pump_Directory.sql
```

with an appropriately privileged account in the verified source PDB.

### 3. Run the Export

From Windows PowerShell, open the `01_Data_Export` directory and run:

```powershell
.\04_Export_All_Table_Data.ps1
```

If PowerShell script execution is restricted for the current process, the following may be used for that PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

Data Pump requests the `BANKING_DB` password interactively.

### 4. Verify the Export Set

After the export completes, run:

```powershell
.\05_Verify_Export_Files.ps1
```

The verified export documented by this repository produced:

```text
Overall status : PASS
```

The Data Pump export log should also be reviewed before the dump set is treated as final.

---

## Security Notes

Database passwords are not stored in the project scripts.

The Data Pump password is entered interactively during export execution.

`READ` and `WRITE` privileges on `DATA_PUMP_DIR` provide filesystem access through the Oracle directory object and should be granted only as required by the deployment environment.

Operational audit and diagnostic history from the source environment is intentionally excluded from the reusable banking dataset.

---

## Environment Scope

This export workflow documents the environment in which the verified dataset was created.

The PowerShell automation and physical Data Pump path are specific to the project's Windows and Docker-based source environment.

They should not be interpreted as generic Oracle installation paths.

A different Oracle environment may require different:

- Container names
- Database services
- Oracle directory objects
- Physical Data Pump paths
- Host-to-database file transfer procedures

The logical Data Pump export scope and dataset definition remain documented by the parameter file and precheck script.

---

## Repository Artifacts

The `export_output` directory contains the verified artifacts associated with this export:

| File | Purpose |
|---|---|
| `banking_data_01.dmp` | Data Pump dump piece |
| `banking_data_02.dmp` | Data Pump dump piece |
| `banking_data_export.log` | Data Pump execution log |
| `checksums.sha256` | SHA-256 integrity information |

The dump files are binary deployment artifacts.

The parameter files, automation scripts, export log, and checksum file document how the dataset was generated and verified.

---

## Export Validation Result

The documented export completed with the following verified inventory:

```text
Project tables                  : 26
Included data tables            : 23
Excluded operational log tables : 3
Missing project tables          : 0
Dump pieces                     : 2
Data Pump TABLE_DATA objects    : 23
Checksum algorithm              : SHA-256
Checksum verification           : PASS
Data Pump job status            : SUCCESS
```

The resulting dump set is the source dataset for the `02_Data_Import` stage.