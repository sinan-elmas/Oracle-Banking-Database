# Project Architecture



### Overview



The **Oracle Banking Database** project is organized as a modular Oracle database portfolio that separates database design, data deployment, SQL reporting, PL/SQL business logic, performance analysis, testing, and database administration responsibilities.



The repository is intentionally structured so that each technical area can be reviewed independently while still representing a single banking database project.



The architecture is divided into seven implemented technical layers:



```text

Database Design

      ↓

Data Deployment

      ↓

SQL Reporting

      ↓

PL/SQL Business Logic

      ↓

Performance Analysis

      ↓

Testing

      ↓

Database Administration

```



Documentation, visual assets, and troubleshooting records are maintained separately from the executable database modules.



---



### Repository Architecture



```text

Oracle-Banking-Database/

│

├── 01_Database_Design/

├── 02_Data_Deployment/

├── 03_SQL_Reports/

├── 04_PLSQL/

├── 05_Performance/

├── 06_Testing/

├── 07_DBA/

├── 08_Documentation/

├── 09_Images/

└── 10_Troubleshooting/

```



Each top-level directory has a specific responsibility and is designed to minimize overlap between modules.



---



## 1. Database Design Layer



```text

01_Database_Design/

```



The Database Design layer defines the structural foundation of the banking schema.



It contains:



- Table definitions

- Primary key constraints

- Unique constraints

- Foreign key constraints

- Check constraints

- Supporting indexes

- Function-based indexes

- Application-managed sequences

- View inventory

- ER diagram source material



The validated schema contains:



```text

Tables                              : 26

Primary key constraints             : 26

Unique constraints                  : 26

Foreign key constraints             : 28

Application-managed sequences       : 2

Oracle-managed identity sequences   : 24

User-defined views                  : 0

```



The schema is organized around the following functional domains:



```text

Reference and Location Data

Customer and Company Data

Account and Banking Data

Transaction Data

Audit and Logging Data

```



This layer is responsible only for structural database objects.



Business operations are handled separately by the PL/SQL layer.



---



## 2. Data Deployment Layer



```text

02_Data_Deployment/

```



The Data Deployment layer provides a controlled mechanism for preserving and transferring the banking dataset between Oracle environments.



It is divided into:



```text

01_Data_Export/

02_Data_Import/

```



Oracle Data Pump is used for data movement.



The reusable dataset contains data from **23 project tables**.



The following environment-specific operational tables are intentionally excluded from the portable dataset:



```text

AUDIT_LOGS

DDL_AUDIT_LOGS

ERROR_LOGS

```



Their table structures remain part of the schema, but their existing operational history is not transferred to a new environment.



The export workflow includes:



```text

Source precheck

      ↓

Data Pump export

      ↓

Dump-file creation

      ↓

SHA-256 checksum generation

      ↓

Checksum verification

```



The current export produced:



```text

banking_data_01.dmp

banking_data_02.dmp

```



with SHA-256 integrity verification.



The corresponding import workflow provides:



```text

Target precheck

      ↓

Dump checksum verification

      ↓

Data Pump import

      ↓

Application sequence synchronization

      ↓

Post-import validation

```



The Data Deployment layer moves data only.



Database structures and PL/SQL objects are managed by their respective repository modules.



---



## 3. SQL Reporting Layer



```text

03_SQL_Reports/

```



The SQL Reporting layer contains **15 independent analytical banking reports**.



The reports cover areas including:



- Customer portfolio analysis

- Account portfolio analysis

- High-value customer analysis

- Branch performance

- Dormant account detection

- Monthly transaction trends

- Customer transaction ranking

- Top transaction analysis

- Account and IBAN consolidation

- Transaction channel analysis

- Branch transaction rollups

- Transaction type and channel grouping

- Executive banking KPIs

- Branch portfolio KPIs

- Customer 360 analysis



The reports demonstrate Oracle SQL features including:



- Common Table Expressions

- Analytic functions

- Ranking functions

- Conditional aggregation

- `LISTAGG`

- `PIVOT`

- `ROLLUP`

- `GROUPING SETS`

- Multi-table joins

- Aggregate functions



The reporting layer is read-only and does not modify application data.



---



## 4. PL/SQL Business Logic Layer



```text

04_PLSQL/

```



The PL/SQL layer centralizes application-side database logic.



It contains:



```text

9 package specifications

9 package bodies

7 triggers

```



The package layer includes:



```text

PKG_ACCOUNT_MANAGEMENT

PKG_AUDIT

PKG_BENEFICIARY_MANAGEMENT

PKG_CARD_MANAGEMENT

PKG_CUSTOMER_MANAGEMENT

PKG_ERROR_LOG

PKG_EXCHANGE_RATE_MANAGEMENT

PKG_LOG_MAINTENANCE

PKG_TRANSACTION_MANAGEMENT

```



These packages provide business operations for:



- Customer management

- Account management

- Beneficiary management

- Card management

- Transaction processing

- Exchange-rate management

- Audit logging

- Error logging

- Log maintenance



The trigger layer contains:



```text

TRG_ACCOUNTS_NO_DELETE

TRG_BRANCHES_AUDIT

TRG_CUSTOMERS_NO_DELETE

TRG_EXCHANGE_RATES_AUDIT

TRG_SCHEMA_DDL_AUDIT

TRG_TRANSACTION_STATUS_HISTORY

TRG_TRANSACTIONS_NO_DELETE

```



The trigger design is intentionally limited.



Reusable business logic is implemented in packages instead of being duplicated across triggers.



---



### Transaction Model



Most business packages participate in the caller's transaction.



This allows business data changes and their associated audit operations to succeed or fail together.



Error logging uses separate handling where persistence outside the failed caller transaction is required.



The PL/SQL design therefore separates:



```text

Business transaction processing

Audit logging

Error logging

DDL auditing

Transaction status history

```



according to their operational purpose.



---



## 5. Performance Analysis Layer



```text

05_Performance/

```



The Performance layer evaluates the database workload using measurable Oracle runtime evidence.



It is divided into:



```text

01_Baseline/

02_Execution_Plans/

03_Index_Analysis/

04_SQL_Tuning_Assessment/

05_PLSQL_Performance_Review/

```



The performance workflow follows an evidence-driven approach:



```text

Baseline

   ↓

Runtime execution plans

   ↓

Index analysis

   ↓

SQL tuning assessment

   ↓

PL/SQL runtime review

```



The project follows the principle:



```text

Measure before changing.

```



Performance changes are not introduced solely to demonstrate tuning activity.



Recommendations are made only where the collected evidence provides sufficient technical justification.



---



### SQL Performance Analysis



The SQL reporting workload is evaluated using runtime execution evidence.



The methodology includes:



- `GATHER_PLAN_STATISTICS`

- `V$SQL`

- `DBMS_XPLAN.DISPLAY_CURSOR`

- Actual row counts

- Buffer gets

- Disk reads

- Join methods

- Access paths

- Aggregation strategy

- Optimizer decisions



Actual runtime plans are preferred over estimated plans where available.



---



### Index Analysis



The indexing strategy is evaluated using:



- Index usage evidence

- Index selectivity

- Foreign-key index coverage

- Existing workload access patterns

- Optimization justification



Indexes are not added or removed without evidence.



---



### PL/SQL Performance Review



The PL/SQL layer has a separate runtime review.



The reviewed PL/SQL inventory confirmed:



```text

Package specifications       : 9

Package bodies               : 9

Triggers                     : 7

Compilation errors           : 0

Low optimization objects     : 0

Debug-enabled objects        : 0

```



Runtime SQL evidence retained in Oracle's shared SQL area was also analyzed.



The documented assessment did not identify sufficient evidence requiring an immediate PL/SQL code or index change.



---



## 6. Testing Layer



```text

06_Testing/

```



The Testing layer provides structural, functional, integration, and regression validation.



It is organized into:



```text

01_Schema_Validation/

02_Data_Integrity/

03_SQL_Report_Validation/

04_PLSQL_Tests/

05_Integration_And_Regression/

06_Test_Results/

```



The testing architecture follows:



```text

Schema Validation

       ↓

Data Integrity

       ↓

SQL Report Validation

       ↓

PL/SQL Package and Trigger Tests

       ↓

Integration and Regression Tests

       ↓

Final Object Health

```



This separation allows structural failures, data-quality failures, PL/SQL defects, and integration failures to be identified independently.



---



### PL/SQL Test Coverage



The recorded package test suites show:



```text

Package suites       : 9 PASS

Failed package suites: 0

```



The trigger test suites show:



```text

Trigger suites            : 4 PASS

Recorded trigger assertions: 50 PASS

Failed trigger assertions : 0

```



Integration testing includes:



```text

Customer -> Account -> Card

Transaction and Balance

Audit and Error Logging

```



Recorded integration results:



```text

Integration suites      : 3 PASS

Integration assertions  : 48 PASS

Failed assertions       : 0

```



---



### Final PL/SQL Object Health



The recorded final object-health validation confirmed:



```text

Package specifications present : 9 / 9

Package specifications VALID   : 9 / 9

Package bodies present         : 9 / 9

Package bodies VALID           : 9 / 9

Triggers present               : 7 / 7

Triggers VALID                 : 7 / 7

Triggers ENABLED               : 7 / 7

Compilation errors             : 0

```



The recorded overall PL/SQL test result is:



```text

PASS

```



---



## 7. Database Administration Layer



```text

07_DBA/

```



The DBA module is intentionally separated from the application-development environment.



It demonstrates practical Oracle Database Administration using a dedicated Oracle Database 19c environment on Oracle Linux.



The module contains:



```text

01_Environment_and_Instance/

02_Storage_Management/

03_Backup/

04_RMAN/

05_Recovery/

06_Data_Pump/

07_Maintenance/

08_Monitoring/

09_Performance/

```



The DBA layer covers:



- Database and instance inventory

- Initialization parameters

- Memory configuration

- Process and session capacity

- Database options

- Redo logs

- Control files

- Tablespaces

- Datafiles

- Tempfiles

- UNDO

- Storage usage

- Backup readiness

- RMAN

- Recovery

- Data Pump

- Object maintenance

- Optimizer statistics

- Scheduler jobs

- Database health monitoring

- FRA usage

- Archive destinations

- Blocking sessions

- Long-running sessions

- Resource limits

- Alert-log reporting

- SQL performance diagnostics

- Wait events

- Latch and mutex contention



Most SQL scripts in the DBA layer are assessment and reporting scripts.



RMAN scripts intentionally perform backup and maintenance operations.



---



## Environment Separation



The project contains two intentionally separate technical contexts.



### Application / Development Context



Used for:



```text

Database Design

Data Deployment

SQL Reports

PL/SQL

Performance Analysis

Testing

```



This environment represents the application-side banking database used for schema development, dataset management, SQL analysis, PL/SQL execution, and functional validation.



### DBA Lab Context



Used for:



```text

07_DBA

```



This environment uses:



```text

Oracle Database 19c Enterprise Edition

Oracle Linux

SQLcl

RMAN

SYSDBA

ARCHIVELOG mode

```



The DBA environment is maintained separately so that administrative exercises and operational scripts do not interfere with the application development database.



The two environments should not be interpreted as one physical Oracle installation.



---



## Separation of Responsibilities



The repository architecture intentionally separates responsibilities.



| Layer | Responsibility |

|---|---|

| Database Design | Structural database objects |

| Data Deployment | Dataset export and import |

| SQL Reports | Read-only business analysis |

| PL/SQL | Business logic and database APIs |

| Performance | Evidence-based runtime analysis |

| Testing | Functional and structural validation |

| DBA | Operational database administration |



This separation reduces duplication and makes each technical area easier to review independently.



---



## Cross-Module Relationships



The major dependencies are:



```text

01_Database_Design

        │

        ├──────────────► 03_SQL_Reports

        │

        ├──────────────► 04_PLSQL

        │

        ├──────────────► 05_Performance

        │

        └──────────────► 06_Testing

        │

        ▼

02_Data_Deployment

```



The schema structure provides the foundation for every application-side module.



The dataset is used by:



```text

SQL reports

PL/SQL workflows

Performance analysis

Testing

```



The PL/SQL layer is validated by the Testing module and reviewed separately by the PL/SQL Performance Review.



The DBA module remains operationally separate from this application dependency chain.



---



## Architectural Principles



The project follows these principles:



- Separate schema structure from application data.

- Separate business logic from reporting logic.

- Prefer reusable PL/SQL packages over trigger-heavy design.

- Keep reporting SQL read-only.

- Measure performance before making tuning changes.

- Validate structural health before functional testing.

- Validate business workflows with integration tests.

- Keep development and DBA environments clearly separated.

- Avoid recreating Oracle-generated internal objects manually.

- Preserve deployment artifacts with integrity verification.

- Document only results supported by executed tests or collected evidence.

- Avoid introducing database objects or tuning changes without a verified requirement.



---



## Documentation Boundary



This document describes the architecture and responsibility of each repository module.



Detailed implementation information remains in the README files inside the corresponding directories.



This avoids duplicating module-specific documentation while providing a single architectural view of the project.
