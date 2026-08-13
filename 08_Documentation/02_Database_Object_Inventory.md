# Database Object Inventory



### Overview



This document provides a consolidated inventory of the primary database objects implemented in the **Oracle Banking Database** project.



The inventory is based on the validated schema definitions and metadata reviews documented under:



```text

01_Database_Design/

04_PLSQL/

06_Testing/

```



The objective is to provide a single technical reference for the implemented schema without duplicating the detailed deployment definitions maintained in those modules.



---



## Schema Summary



The validated database design contains:



| Object Category | Count |

|---|---:|

| Tables | 26 |

| Primary Key Constraints | 26 |

| Unique Constraints | 26 |

| Foreign Key Constraints | 28 |

| User-Defined Check Constraints | 36 |

| Explicitly Managed Constraints | 116 |

| Independently Managed Supporting Indexes | 28 |

| Independently Managed Function-Based Indexes | 1 |

| Independently Managed Indexes | 29 |

| Application-Managed Sequences | 2 |

| Oracle-Managed Identity Sequences | 24 |

| Package Specifications | 9 |

| Package Bodies | 9 |

| Triggers | 7 |

| User-Defined Views | 0 |



Oracle-generated indexes that support primary key and unique constraints are not included in the **29 independently managed indexes** shown above.



Oracle-generated `NOT NULL` constraints are also not included in the **36 user-defined check constraints**.



---



## 1. Tables



The schema contains **26 tables**.



They are grouped into five functional areas.



---



### 1.1 Reference and Location Data



```text

COUNTRIES

CITIES

DISTRICTS

SECTORS

CURRENCIES

ACCOUNT_TYPES

CARD_TYPES

CONTACT_TYPES

TRANSACTION_CHANNELS

TRANSACTION_TYPES

```



These tables provide reference values used throughout the banking schema.



#### Geographic Structure



```text

COUNTRIES

    ↓

CITIES

    ↓

DISTRICTS

```



The geographic hierarchy is used by customer, company, and branch-related structures.



#### Banking Reference Data



The remaining reference tables provide reusable classifications for:



- Account types

- Card types

- Contact types

- Currencies

- Company sectors

- Transaction channels

- Transaction types



---



### 1.2 Customer and Company Data



```text

CUSTOMERS

INDIVIDUAL_CUSTOMERS

CORPORATE_CUSTOMERS

COMPANIES

CUSTOMER_ADDRESSES

CUSTOMER_CONTACTS

```



`CUSTOMERS` is the central customer entity.



Customer-specific attributes are separated into subtype tables:



```text

CUSTOMERS

├── INDIVIDUAL_CUSTOMERS

└── CORPORATE_CUSTOMERS

```



`INDIVIDUAL_CUSTOMERS.CUSTOMER_ID` and

`CORPORATE_CUSTOMERS.CUSTOMER_ID` reference:



```text

CUSTOMERS.CUSTOMER_ID

```



Both subtype relationships use:



```text

ON DELETE CASCADE

```



The remaining customer-related tables manage:



- Company information

- Customer addresses

- Customer contact channels



---



### 1.3 Account and Banking Data



```text

BRANCHES

ACCOUNTS

BENEFICIARIES

CARDS

EXCHANGE_RATES

```



`ACCOUNTS` is a central banking entity and connects customers with:



- Branches

- Account types

- Currencies



Cards are associated with accounts.



Beneficiaries link customers with beneficiary accounts.



Exchange-rate records maintain currency conversion data independently from transaction records.



---



### 1.4 Transaction Data



```text

TRANSACTIONS

TRANSACTION_STATUS_HISTORY

```



`TRANSACTIONS` stores banking transaction records.



Transactions reference:



- Source accounts

- Optional target accounts

- Transaction types

- Transaction channels

- Currencies



`TRANSACTION_STATUS_HISTORY` records transaction status changes when the transaction-status trigger detects an actual status transition.



The table is structurally part of the transactional model even when the current reusable dataset contains no persisted status-history rows.



---



### 1.5 Audit and Logging Data



```text

AUDIT_LOGS

ERROR_LOGS

DDL_AUDIT_LOGS

```



These tables have different responsibilities.



#### AUDIT_LOGS



Stores application and business-operation audit information.



The structure supports information such as:



- Action type

- Entity

- Entity identifier

- Module

- Procedure

- Operation

- Old data

- New data

- Execution context

- Session information



#### ERROR_LOGS



Stores application and PL/SQL diagnostic information.



The structure supports information such as:



- Error code

- Error message

- Error stack

- Error backtrace

- Call stack

- Severity

- Module and procedure

- Execution context

- Session information



#### DDL_AUDIT_LOGS



Stores schema-level DDL audit activity.



The structure supports information such as:



- DDL event type

- Object owner

- Object name

- Object type

- Login user

- Session user

- Current schema

- Host information

- Event timestamp

- Executed SQL text



These three tables are part of the database schema but their existing development-environment records are intentionally excluded from the reusable Data Pump dataset.



---



## 2. Primary Key Constraints



The schema contains:



```text

26 primary key constraints

```



Every project table has one primary key.



Metadata validation confirmed:



```text

Expected primary keys : 26

Present primary keys  : 26

Enabled primary keys  : 26

Validated primary keys: 26

Tables without PK     : 0

```



The deployment scripts use stable descriptive `PK_*` names instead of reproducing Oracle-generated `SYS_C...` names from the development database.



Examples include:



```text

PK_ACCOUNTS

PK_CUSTOMERS

PK_TRANSACTIONS

PK_AUDIT_LOGS

PK_DDL_AUDIT_LOGS

```



---



## 3. Unique Constraints



The schema contains:



```text

26 unique constraints

```



These constraints protect both single-column and composite business identifiers.



Validated examples include uniqueness rules for:



- Account numbers

- IBAN values

- Customer numbers

- Card numbers

- Branch codes

- Currency codes

- Country codes

- Transaction reference numbers

- Individual national identifiers

- Corporate tax numbers

- Corporate registration numbers

- Customer/contact combinations

- Exchange-rate combinations



All expected unique constraint mappings were verified against the implemented schema metadata.



Validation confirmed:



```text

Expected unique constraints : 26

Present unique constraints  : 26

Enabled unique constraints  : 26

Validated unique constraints: 26

Unexpected mappings         : 0

```



---



## 4. Foreign Key Constraints



The schema contains:



```text

28 foreign key constraints

```



The foreign keys enforce relationships across all major banking domains.



Metadata validation confirmed:



```text

Expected foreign keys : 28

Present foreign keys  : 28

Enabled foreign keys  : 28

Validated foreign keys: 28

Unexpected mappings   : 0

```



---



### Delete Rules



The verified foreign key delete-rule distribution is:



| Delete Rule | Count |

|---|---:|

| `NO ACTION` | 26 |

| `CASCADE` | 2 |



The two cascading relationships are:



```text

INDIVIDUAL_CUSTOMERS.CUSTOMER_ID

    → CUSTOMERS.CUSTOMER_ID



CORPORATE_CUSTOMERS.CUSTOMER_ID

    → CUSTOMERS.CUSTOMER_ID

```



All other foreign keys use Oracle's default non-cascading behavior.



---



## 5. User-Defined Check Constraints



The project contains:



```text

36 user-defined check constraints

```



distributed across **14 tables**.



These constraints enforce business rules directly in the database.



Validated rule categories include:



- Non-negative account balances

- Account status validation

- Account opening and closing date consistency

- IBAN format rules

- Card-number length

- Card status validation

- Customer type validation

- Customer status validation

- Corporate tax-number length

- Currency-code length

- Customer address-type validation

- Customer contact flags

- Customer contact source-channel validation

- Positive exchange rates

- Exchange-rate relationship rules

- Different base and target currencies

- Positive transaction amounts

- Different source and target accounts

- Transaction status validation

- Audit action validation

- Error severity validation

- JSON validation for audit and error context data

- Transaction status-history transition validation



Metadata validation confirmed that all 36 expected user-defined check constraints were:



```text

ENABLED

VALIDATED

```



and that no unexpected user-defined check constraints were detected.



---



### NOT NULL Rules



Oracle internally represents column-level `NOT NULL` rules as check constraints.



These Oracle-generated constraints are intentionally not duplicated in the explicit check-constraint deployment script.



Column nullability is defined directly in:



```text

01_Database_Design/02_Tables/

```



Therefore:



```text

36

```



represents the project's explicitly managed **business-rule check constraints**, not every internal constraint classified by Oracle as type `C`.



---



## 6. Constraint Inventory



The explicitly managed constraint inventory is:



| Constraint Type | Count |

|---|---:|

| Primary Keys | 26 |

| Unique Constraints | 26 |

| Foreign Keys | 28 |

| User-Defined Check Constraints | 36 |

| **Total** | **116** |



The constraint layer is maintained under:



```text

01_Database_Design/03_Constraints/

```



---



## 7. Independently Managed Indexes



The project explicitly manages:



```text

29 indexes

```



outside the indexes associated with primary key and unique constraints.



These consist of:



| Index Category | Count |

|---|---:|

| Supporting Nonunique Indexes | 28 |

| Function-Based Unique Indexes | 1 |

| **Total** | **29** |



---



### 7.1 Supporting Indexes



The schema contains **28 independently managed nonunique supporting indexes**.



They primarily support:



- Foreign key access paths

- Customer relationships

- Account relationships

- Card relationships

- Branch and location relationships

- Beneficiary relationships

- Exchange-rate access

- Transaction access

- Transaction status history

- DDL audit metadata



Examples include:



```text

IDX_ACCOUNTS_CUSTOMER_ID

IDX_ACCOUNTS_BRANCH_ID

IDX_CARDS_ACCOUNT_ID

IDX_ADDR_CUSTOMER_ID

IDX_CC_CUSTOMER_ID

IDX_RATES_CURRENCY_ID

IDX_TR_SOURCE_ACCOUNT_ID

IDX_TR_TARGET_ACCOUNT_ID

IDX_TRX_STATUS_HIST_TRANSACTION

```



The schema also includes the composite supporting index:



```text

IDX_DDL_AUDIT_LOGS_OBJECT

```



with column order:



```text

OBJECT_OWNER

OBJECT_NAME

OBJECT_TYPE

```



The supporting indexes were validated for:



- Index name

- Table

- Indexed columns

- Composite column order

- Index type

- Uniqueness

- Status

- Visibility



---



### 7.2 Function-Based Index



The project contains one independently managed function-based unique index:



```text

UQ_CUSTOMER_PRIMARY_CONTACT

```



on:



```text

CUSTOMER_CONTACTS

```



Its validated indexed structure is:



```text

CUSTOMER_ID

CONTACT_TYPE_ID

CASE WHEN IS_PRIMARY = 'Y' THEN IS_PRIMARY END

```



Oracle stores the expression as:



```sql

CASE WHEN "IS_PRIMARY"='Y' THEN "IS_PRIMARY" END

```



The index was verified as:



```text

INDEX TYPE : FUNCTION-BASED NORMAL

UNIQUENESS : UNIQUE

STATUS     : VALID

VISIBILITY : VISIBLE

```



Its purpose is to enforce that a customer cannot have more than one primary contact for the same contact type.



---



### Constraint-Backed Indexes



Indexes automatically created or reused by Oracle for:



```text

PRIMARY KEY

UNIQUE

```



constraints are intentionally not recreated by the independent index deployment module.



Their lifecycle belongs to the corresponding constraints.



Therefore the number:



```text

29 independently managed indexes

```



must not be interpreted as the total number of physical indexes visible in the database.



---



## 8. Application-Managed Sequences



The project explicitly manages two application sequences:



```text

CARD_SEQ

SEQ_CUSTOMER_NO

```



Both were validated with:



```text

MINVALUE     = 1

MAXVALUE     = 9999999999999999999999999999

INCREMENT BY = 1

CACHE        = 100

NOCYCLE

NOORDER

NOSCALE

NOEXTEND

NOKEEP

```



---



### CARD_SEQ



`CARD_SEQ` supports card creation.



The card-management package uses:



```text

CARD_SEQ.NEXTVAL

```



when generating new card identifiers.



---



### SEQ_CUSTOMER_NO



`SEQ_CUSTOMER_NO` supports customer-number generation.



Customer numbers follow the project format:



```text

CUST######

```



The sequence provides the numeric component used by the customer-management package.



---



## 9. Oracle-Managed Identity Sequences



The schema contains:



```text

24 Oracle-managed identity sequences

```



using Oracle's internal naming pattern:



```text

ISEQ$$_...

```



These objects are generated automatically for identity columns.



They are intentionally excluded from manual sequence deployment.



The corresponding identity behavior belongs to the table definitions.



The project therefore follows this rule:



```text

Application-managed sequences

    → explicitly version controlled



Oracle identity sequences

    → automatically managed by Oracle

```



---



## 10. PL/SQL Packages



The schema contains:



```text

9 package specifications

9 package bodies

```



The package inventory is:



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



---



### Package Responsibilities



| Package | Primary Responsibility |

|---|---|

| `PKG_ACCOUNT_MANAGEMENT` | Account operations |

| `PKG_AUDIT` | Application audit logging |

| `PKG_BENEFICIARY_MANAGEMENT` | Beneficiary operations |

| `PKG_CARD_MANAGEMENT` | Card operations |

| `PKG_CUSTOMER_MANAGEMENT` | Customer operations |

| `PKG_ERROR_LOG` | Error logging |

| `PKG_EXCHANGE_RATE_MANAGEMENT` | Exchange-rate operations |

| `PKG_LOG_MAINTENANCE` | Log maintenance |

| `PKG_TRANSACTION_MANAGEMENT` | Banking transaction processing |



The package layer centralizes reusable business logic instead of distributing core application behavior across triggers.



---



## 11. Triggers



The schema contains:



```text

7 triggers

```



The trigger inventory is:



```text

TRG_ACCOUNTS_NO_DELETE

TRG_BRANCHES_AUDIT

TRG_CUSTOMERS_NO_DELETE

TRG_EXCHANGE_RATES_AUDIT

TRG_SCHEMA_DDL_AUDIT

TRG_TRANSACTION_STATUS_HISTORY

TRG_TRANSACTIONS_NO_DELETE

```



---



### Trigger Categories



#### Delete Protection



```text

TRG_ACCOUNTS_NO_DELETE

TRG_CUSTOMERS_NO_DELETE

TRG_TRANSACTIONS_NO_DELETE

```



These triggers enforce protected delete behavior for important banking entities.



#### Data Audit



```text

TRG_BRANCHES_AUDIT

TRG_EXCHANGE_RATES_AUDIT

```



These triggers support audit metadata on relevant update operations.



#### Transaction Status History



```text

TRG_TRANSACTION_STATUS_HISTORY

```



This trigger records actual changes to:



```text

TRANSACTIONS.STATUS

```



in:



```text

TRANSACTION_STATUS_HISTORY

```



#### Schema DDL Audit



```text

TRG_SCHEMA_DDL_AUDIT

```



This trigger records schema-level DDL activity in:



```text

DDL_AUDIT_LOGS

```



---



## 12. Views



Metadata inspection confirmed:



```text

User-defined views: 0

```



No artificial view objects were introduced merely to populate the project.



The `06_Views` module therefore documents the intentionally empty view layer rather than containing unnecessary `CREATE VIEW` statements.



---



## 13. PL/SQL Object Health



The recorded final testing validation confirmed:



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



The recorded final PL/SQL object-health result was:



```text

PASS

```



---



## Inventory Boundaries



This document distinguishes between different types of object counts.



For example:



```text

29 independently managed indexes

```



does not mean that the database contains only 29 physical indexes.



Primary key and unique constraints may use additional Oracle-managed or constraint-backed indexes.



Similarly:



```text

36 user-defined check constraints

```



does not include Oracle-generated `NOT NULL` check constraints.



And:



```text

2 application-managed sequences

```



does not include the 24 Oracle-managed identity sequences.



These distinctions are intentional and prevent Oracle-generated implementation objects from being confused with explicitly version-controlled project objects.



---



## Source Modules



Detailed definitions and validation logic remain under:



```text

01_Database_Design/

├── 02_Tables/

├── 03_Constraints/

├── 04_Indexes/

├── 05_Sequences/

└── 06_Views/



04_PLSQL/



06_Testing/

```



This document provides only the consolidated database-object inventory.



The corresponding module README files and SQL scripts remain the authoritative source for individual object definitions and validation procedures.
