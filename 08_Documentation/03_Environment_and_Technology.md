# Environment and Technology



### Overview



The **Oracle Banking Database** project uses two separate Oracle environments for different technical responsibilities.



The environments are intentionally separated:



```text

Application Development Environment

            │

            ├── Database Design

            ├── Data Deployment

            ├── SQL Reports

            ├── PL/SQL

            ├── Performance Analysis

            └── Testing





Database Administration Lab

            │

            └── DBA Operations

```



This separation prevents application-development activities and database-administration exercises from being represented as if they were performed against the same Oracle installation.



---



## 1. Application Development Environment



The primary application-side environment is used for:



```text

01_Database_Design

02_Data_Deployment

03_SQL_Reports

04_PLSQL

05_Performance

06_Testing

```



It hosts the working `BANKING_DB` schema and the banking dataset used throughout the application-side modules.



---



### Platform



```text

Host Operating System : Windows 11

Container Platform     : Docker

Database Container     : oracle_ee_23ai

Database Service / PDB : ORCLPDB1

Application Schema     : BANKING_DB

```



The Oracle database runs inside Docker while development and repository operations are performed from Windows.



---



### Oracle Database



The application environment reports:



```text

Oracle AI Database 26ai Enterprise Edition

Release 23.26.1.0.0

Version 23.26.1.0.0

```



The Docker image used by the environment is:



```text

container-registry.oracle.com/database/enterprise:23.26.1.0

```



The project documentation therefore distinguishes between:



```text

Product branding : Oracle AI Database 26ai

Database version : 23.26.1.0.0

```



rather than treating the product branding and database version number as the same value.



---



### Container Connectivity



The development database is exposed from the Docker container through:



```text

Host port      : 1522

Container port : 1521

Service / PDB  : ORCLPDB1

```



The application schema used by the project is:



```text

BANKING_DB

```



---



### Development Client



The primary graphical SQL development client is:



```text

Oracle SQL Developer

Version 24.3.1.347.1826

Java 17.0.13

```



SQL Developer is used for activities including:



- Schema inspection

- SQL development

- SQL report execution

- PL/SQL development

- Package and trigger validation

- Data inspection

- Performance-query execution

- Test execution



Command-line Oracle tools are also used where appropriate.



---



### Container Administration



The Oracle container can be accessed from Windows PowerShell using Docker.



Typical container access:



```powershell

docker exec -it oracle_ee_23ai bash

```



Administrative database access inside the container uses:



```text

sqlplus / as sysdba

```



The database initially connects to:



```text

CDB$ROOT

```



and application-side administrative operations targeting the banking PDB use:



```sql

ALTER SESSION SET CONTAINER = ORCLPDB1;

```



The application schema itself operates inside:



```text

ORCLPDB1

```



---



## 2. Application Schema



The main application schema is:



```text

BANKING_DB

```



It contains the banking project's:



- Tables

- Constraints

- Indexes

- Sequences

- PL/SQL packages

- Triggers

- Banking dataset

- Audit structures

- Error logging structures



The schema is the primary target of the project's application-side development and validation activities.



---



### Dataset Scale



The current reusable dataset includes major table volumes such as:



```text

TRANSACTIONS           : 200,000

CUSTOMER_CONTACTS      : 22,850

ACCOUNTS               : 21,000

BENEFICIARIES          : 15,644

CUSTOMER_ADDRESSES     : 14,293

CUSTOMERS              : 10,003

INDIVIDUAL_CUSTOMERS   : 9,002

CARDS                  : 7,866

COMPANIES              : 1,001

CORPORATE_CUSTOMERS    : 1,001

```



The dataset is large enough to support meaningful:



- SQL reporting

- PL/SQL workflow testing

- Execution-plan analysis

- Index analysis

- Integration testing



without presenting it as a production banking workload.



---



## 3. Data Deployment Environment



Data deployment uses Oracle Data Pump together with Windows PowerShell and Docker.



The relevant technologies are:



```text

Oracle Data Pump Export  : expdp

Oracle Data Pump Import  : impdp

Automation               : Windows PowerShell

Container transfer       : Docker

Integrity verification   : SHA-256

```



---



### Data Pump Directory



The development PDB exposes:



```text

DATA_PUMP_DIR

```



mapped to the Oracle container path:



```text

/opt/oracle/admin/ORCLCDB/dpdump/5568D25A59CF0DCCE063030011AC2144

```



The project uses the Oracle directory object rather than embedding an arbitrary filesystem location directly into Data Pump operations.



---



### Export Artifacts



The verified export workflow generated:



```text

banking_data_01.dmp

banking_data_02.dmp

banking_data_export.log

checksums.sha256

```



The dump files are transferred from the Oracle container to the Windows repository workspace.



SHA-256 checksums provide file-integrity verification before the dump set is treated as a reusable deployment artifact.



---



## 4. SQL and PL/SQL Technology



The application layer uses Oracle SQL and PL/SQL.



---



### Oracle SQL



The reporting and analysis workload includes techniques such as:



```text

Common Table Expressions

Analytic Functions

Ranking Functions

Conditional Aggregation

LISTAGG

PIVOT

ROLLUP

GROUPING SETS

Multi-table Joins

Aggregate Functions

```



SQL reporting is maintained separately from PL/SQL business logic.



---



### Oracle PL/SQL



PL/SQL is used for reusable database-side business operations.



The implemented object inventory contains:



```text

Package Specifications : 9

Package Bodies          : 9

Triggers                : 7

```



The package architecture covers:



- Customer operations

- Account operations

- Beneficiary operations

- Card operations

- Transaction processing

- Exchange-rate operations

- Audit logging

- Error logging

- Log maintenance



Triggers are reserved for database-event behavior where trigger semantics are appropriate.



---



## 5. Performance Analysis Technology



Performance analysis is performed against the application-side Oracle environment.



The methodology uses Oracle runtime evidence rather than relying only on estimated execution plans.



Technologies and Oracle interfaces used include:



```text

GATHER_PLAN_STATISTICS

DBMS_XPLAN.DISPLAY_CURSOR

V$SQL

V$SQL_PLAN

V$SQL_PLAN_STATISTICS_ALL

V$SESSION

```



The application schema has the required access to the relevant dynamic performance views used by the performance module.



---



### Performance Methodology



The workflow follows:



```text

Baseline

   ↓

Runtime SQL evidence

   ↓

Execution-plan analysis

   ↓

Index analysis

   ↓

Tuning assessment

   ↓

PL/SQL runtime review

```



The project does not assume that every query requires tuning.



A change is recommended only when collected evidence provides sufficient justification.



---



## 6. Testing Environment



Functional and integration testing is performed against the application-side banking schema.



The testing framework validates:



```text

Schema structure

Data integrity

SQL reports

PL/SQL packages

Triggers

Cross-module workflows

Final object health

```



Tests are implemented using Oracle SQL and PL/SQL scripts rather than an external application testing framework.



This keeps the validation focused on database behavior.



---



## 7. Database Administration Lab



The DBA module uses a separate Oracle environment.



It is associated exclusively with:



```text

07_DBA/

```



The DBA environment is not the same database installation used for application-side development.



---



### DBA Platform



The DBA laboratory uses:



```text

Operating System : Oracle Linux 8.10

Database         : Oracle Database 19c Enterprise Edition

Database Name    : ORCL

Architecture     : Non-CDB

Virtualization   : VirtualBox

```



The validated database inventory reports:



```text

Database Name : ORCL

Open Mode     : READ WRITE

Log Mode      : ARCHIVELOG

Database Role : PRIMARY

Platform      : Linux x86 64-bit

CDB           : NO

```



The instance runs on:



```text

dbserver.localdomain

```



---



### Oracle Version



The DBA environment reports:



```text

Oracle Database 19c Enterprise Edition

Version 19.0.0.0.0

```



with the database banner reporting the 19c installation level used by the lab.



This version is intentionally different from the application-development environment.



---



### DBA Command-Line Environment



The DBA workflow primarily uses:



```text

SQLcl

RMAN

Oracle Linux shell

```



Administrative SQL access follows:



```text

sql / as sysdba

```



This reflects the operational nature of the DBA module rather than normal application-schema access.



---



## 8. DBA Database Configuration



The validated DBA environment includes:



```text

Database      : ORCL

Architecture  : Non-CDB

Open Mode     : READ WRITE

Log Mode      : ARCHIVELOG

Role          : PRIMARY

Flashback     : NO

Force Logging : NO

```



---



### Memory Management



The DBA environment uses:



```text

Automatic Shared Memory Management (ASMM)

```



with the recorded configuration:



```text

MEMORY_TARGET     : 0 MB

MEMORY_MAX_TARGET : 0 MB

SGA_TARGET        : 1392 MB

SGA_MAX_SIZE      : 1392 MB

PGA_AGGREGATE_TARGET : 463 MB

PGA_AGGREGATE_LIMIT  : 2048 MB

```



This configuration is documented and analyzed by the DBA environment and instance inventory scripts.



---



### Redo Configuration



The validated redo configuration contains:



```text

Redo groups : 3

Size/group  : 200 MB

Log mode    : ARCHIVELOG

```



The redo members are stored under the Oracle database storage path for `ORCL`.



Redo configuration is analyzed by the DBA module rather than the application-development modules.



---



## 9. DBA Technology Areas



The DBA environment is used to demonstrate operational Oracle administration across:



```text

Environment and Instance

Storage Management

Backup

RMAN

Recovery

Data Pump

Maintenance

Monitoring

Performance

```



This includes work with Oracle facilities such as:



- Dynamic performance views

- Data dictionary views

- RMAN

- Data Pump

- FRA

- Archive destinations

- Optimizer statistics

- Scheduler jobs

- Session monitoring

- Wait-event analysis

- SQL execution statistics

- Latch and mutex diagnostics



---



## 10. Environment Responsibility Matrix



| Technical Area | Application Environment | DBA Lab |

|---|:---:|:---:|

| Database Design | Yes | No |

| Banking Dataset | Yes | No |

| SQL Reports | Yes | No |

| PL/SQL Development | Yes | No |

| Functional Testing | Yes | No |

| Application Performance Analysis | Yes | No |

| Data Deployment Workflow | Yes | No |

| Instance Administration | No | Yes |

| Storage Administration | No | Yes |

| RMAN | No | Yes |

| Recovery Exercises | No | Yes |

| Operational Monitoring | No | Yes |

| DBA Performance Diagnostics | No | Yes |



This distinction is intentional.



---



## 11. Technology Summary



The project demonstrates practical use of:



```text

Oracle AI Database 26ai

Oracle Database 19c Enterprise Edition

Oracle SQL

Oracle PL/SQL

Oracle SQL Developer

SQL*Plus

SQLcl

Oracle Data Pump

RMAN

Oracle Linux

Windows 11

Docker

VirtualBox

PowerShell

Git / GitHub repository structure

SHA-256 file verification

```



Each technology is used for a defined project responsibility rather than being listed independently of the implemented work.



---



## 12. Environment Boundaries



The project should not be interpreted as claiming that:



```text

Oracle 26ai and Oracle 19c are the same environment

```



or that:



```text

all project modules execute against one Oracle database installation

```



Instead:



```text

Application Development

    → Windows + Docker + Oracle AI Database 26ai



Database Administration

    → Oracle Linux + VirtualBox + Oracle Database 19c

```



The application environment demonstrates database development and application-side database engineering.



The DBA environment demonstrates Oracle administration and operational database management.



Keeping these environments separate provides a clearer boundary between:



```text

Developer responsibilities

and

DBA responsibilities

```



within the same portfolio project.



---



## Documentation Scope



This document records the technology stack and execution environments used by the project.



Detailed commands, validation procedures, and operational instructions remain in their respective module documentation:



```text

01_Database_Design/

02_Data_Deployment/

03_SQL_Reports/

04_PLSQL/

05_Performance/

06_Testing/

07_DBA/

```



This document should therefore be used as the central reference for understanding **where and with which technologies each part of the project was implemented**.
