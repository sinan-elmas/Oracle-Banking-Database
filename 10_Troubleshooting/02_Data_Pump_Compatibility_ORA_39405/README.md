# Data Pump Compatibility - ORA-39405

## Problem

The `BANKING_DB` schema import into Oracle Database 19c was blocked by `ORA-39405`.

A lab-only Data Pump master-table workaround was used to allow the import to continue.

> This was not treated as a normal Oracle-supported migration procedure. It was used in a controlled lab environment with a snapshot available.

## Workaround

Two Oracle Linux terminals were used.

### Terminal 1 - Monitor and Modify the Data Pump Master Table

Connect as the Data Pump import user:

```bash
sqlplus dp_import@ORCLDB
```

Enable `DBMS_OUTPUT`:

```sql
SET SERVEROUTPUT ON
```

Remove a master table left from a previous attempt:

```sql
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE MY_MASTER_TABLE PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/
```

Run the following block before starting `impdp`:

```sql
DECLARE
    n NUMBER := 1;
BEGIN
    LOOP
        BEGIN
            EXECUTE IMMEDIATE '
                UPDATE dp_import.MY_MASTER_TABLE
                   SET property = 32
                 WHERE property = 43
                   AND process_order = -1
                   AND operation = ''EXPORT''
            ';

            IF SQL%ROWCOUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE(
                    'Update done at loop counter: ' || n
                );

                COMMIT;
                EXIT;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        n := n + 1;
        ROLLBACK;
        SYS.DBMS_SESSION.SLEEP(1 / 50);
    END LOOP;
END;
/
```

Keep this terminal running while the Data Pump job starts.

### Terminal 2 - Start the Data Pump Import

Create the parameter file:

```bash
cat > /home/oracle/expdp_orcl/banking_db_workaround_import.par <<'EOF'
DIRECTORY=EXPDP_DIR
DUMPFILE=banking_db_20260802.dmp
LOGFILE=banking_db_workaround_import.log

SCHEMAS=BANKING_DB
REMAP_TABLESPACE=USERS:BANKING_TBS

EXCLUDE=USER
EXCLUDE=SYSTEM_GRANT
EXCLUDE=ROLE_GRANT
EXCLUDE=DEFAULT_ROLE
EXCLUDE=TABLESPACE_QUOTA
EXCLUDE=STATISTICS

LOGTIME=ALL
METRICS=YES
TRANSFORM=OID:N
EOF
```

Start the import:

```bash
impdp dp_import@ORCLDB \
JOB_NAME=MY_MASTER_TABLE \
PARFILE=/home/oracle/expdp_orcl/banking_db_workaround_import.par
```

`JOB_NAME=MY_MASTER_TABLE` must match the master table referenced by the PL/SQL block.

## Verification

The first terminal reported that the master-table row was updated:

```text
Update done at loop counter: <n>
PL/SQL procedure successfully completed.
```

The Data Pump job then continued past the previous `ORA-39405` blocker and began processing schema objects and table data.

The retained import output confirmed that the `TRANSACTIONS` table was imported with **200,000 rows**.

## Remaining Import Issues

Resolving `ORA-39405` did not make the entire import error-free. Separate post-import issues remained:

- `ORA-31685` on 24 `IDENTITY_COLUMN` operations because of insufficient privileges
- `ORA-39082` compilation warnings on 3 package bodies

These were handled separately from the `ORA-39405` compatibility blocker.

## Log Check

After the import:

```bash
grep -E "successfully completed|completed with|ORA-|UDI-|UDE-" \
/home/oracle/expdp_orcl/banking_db_workaround_import.log
```

## Result

`ORA-39405` compatibility blocker: **Resolved**

`BANKING_DB` import: **Successfully proceeded past the compatibility failure**
