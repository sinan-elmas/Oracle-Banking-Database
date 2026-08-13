# Data Import

This directory contains the Oracle Data Pump import workflow used to validate the reusable `BANKING_DB` dataset.

## Environment

```text
Docker Container : oracle_ee_23ai
Database Service : ORCLPDB1
Schema User      : BANKING_DB
Container / PDB  : ORCLPDB1
```

## Files

```text
02_Data_Import/
├── import_logs/
├── 01_pre_import_check.sql
├── 02_post_import_validation.sql
├── import_data.par
└── README.md
```

## Import Parameter File

The import is performed with:

```text
import_data.par
```

The parameter file defines the Data Pump directory, dump files, target schema, logging, and import behavior.

## Pre-Import Validation

Before starting the import, run:

```sql
@01_pre_import_check.sql
```

The script validates the target environment before Data Pump import.

## Data Pump Import

Open a terminal in this directory:

```powershell
cd "C:\path\to\Oracle-Banking-Database\02_Data_Deployment\02_Data_Import"
```

Run the Data Pump import with the project parameter file.

The import uses the `BANKING_DB` schema and the `ORCLPDB1` service.

## Post-Import Validation

After the Data Pump import completes, run:

```sql
@02_post_import_validation.sql
```

The post-import validation checks the imported dataset and confirms the expected application data state.

## Import Logs

Data Pump import logs are retained under:

```text
import_logs/
```

These logs provide execution evidence for the documented deployment workflow.

## Dataset Scope

The reusable Data Pump dataset contains application data from **23 of the 26 project tables**.

The following operational logging tables are intentionally excluded:

```text
AUDIT_LOGS
DDL_AUDIT_LOGS
ERROR_LOGS
```

These tables contain environment-specific operational history and are not part of the reusable application dataset.

## Notes

- Verify the Data Pump directory before import.
- Use the documented `BANKING_DB` schema and `ORCLPDB1` service.
- Review the Data Pump log after execution.
- Run post-import validation before treating the deployment as complete.
- The retained dump files and checksums are maintained under the export module.