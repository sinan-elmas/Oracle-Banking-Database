# Troubleshooting

This module documents technical issues encountered and resolved during the **Oracle Banking Database** project.

Each case records the problem, the applied resolution or workaround, and the verification result.

## Troubleshooting Cases

| Case | Description | Status |
|---|---|---|
| `01_SQL_Developer_CTE_Parser_Issue` | SQL Developer client-side CTE parser issue resolved through JVM locale configuration | Resolved |
| `02_Data_Pump_Compatibility_ORA_39405` | `ORA-39405` Data Pump compatibility blocker encountered during `BANKING_DB` migration to Oracle Database 19c | Resolved |

## Structure

```text
10_Troubleshooting/
├── 01_SQL_Developer_CTE_Parser_Issue/
│   └── README.md
├── 02_Data_Pump_Compatibility_ORA_39405/
│   └── README.md
└── README.md
```

## Notes

- The SQL Developer case required a client-side JVM locale change; no SQL rewrite or database-side change was required.
- The `ORA-39405` case used a controlled lab-only Data Pump master-table workaround.
- Post-import `ORA-31685` and `ORA-39082` issues were separate from the `ORA-39405` blocker.

Both troubleshooting cases are retained as technical references for the project.
