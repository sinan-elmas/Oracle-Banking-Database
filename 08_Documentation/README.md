# Documentation

This directory provides consolidated technical documentation for the **Oracle Banking Database** project.

Detailed implementation and execution instructions remain in the corresponding technical modules; this directory provides the cross-project view.

## Documents

| Document | Purpose |
|---|---|
| [`01_Project_Architecture.md`](01_Project_Architecture.md) | Explains the repository architecture, module responsibilities, cross-module relationships, and separation between application development and DBA work |
| [`02_Database_Object_Inventory.md`](02_Database_Object_Inventory.md) | Consolidates the validated schema, constraint, index, sequence, package, trigger, and view inventory |
| [`03_Environment_and_Technology.md`](03_Environment_and_Technology.md) | Documents the application-development and DBA environments and the technologies used in each |

## Environment Boundary

The project intentionally uses two separate Oracle environments:

```text
Application Development
    Windows 11
    Docker
    Oracle AI Database 26ai Enterprise Edition
    Version 23.26.1.0.0
    Service / PDB: ORCLPDB1
    Schema: BANKING_DB

Database Administration Lab
    Oracle Linux 8.10
    VirtualBox
    Oracle Database 19c Enterprise Edition
    Database: ORCL
```

Application-side modules cover database design, data deployment, SQL reporting, PL/SQL, performance analysis, and testing. The DBA module covers instance administration, storage, backup, RMAN, recovery, Data Pump administration, maintenance, monitoring, and DBA performance diagnostics.

## Validated Object Summary

| Object Type | Count |
|---|---:|
| Tables | 26 |
| Primary key constraints | 26 |
| Unique constraints | 26 |
| Foreign key constraints | 28 |
| User-defined check constraints | 36 |
| Independently managed indexes | 29 |
| Application-managed sequences | 2 |
| Oracle-managed identity sequences | 24 |
| Package specifications | 9 |
| Package bodies | 9 |
| Triggers | 7 |
| User-defined views | 0 |

Oracle-generated indexes supporting primary key and unique constraints are not included in the independently managed index count. Oracle-generated `NOT NULL` constraints are not included in the user-defined check-constraint count.

## Documentation Principles

- Keep the application-development and DBA environments clearly separated.
- Distinguish explicitly managed project objects from Oracle-generated implementation objects.
- Base technical claims and object counts on retained project evidence.
- Do not duplicate detailed module instructions unnecessarily.
- Keep operational commands and validation procedures in the module where they belong.

## Recommended Reading Order

```text
01_Project_Architecture.md
        ↓
02_Database_Object_Inventory.md
        ↓
03_Environment_and_Technology.md
        ↓
Module-specific README files
```

## Scope

This directory contains documentation only. Executable SQL, PL/SQL, Data Pump, RMAN, testing, and administration assets remain in their respective technical modules.
