# 04 - RMAN

## Purpose

This module contains executable RMAN command files for performing Oracle Database backup, validation, and repository maintenance operations.

Unlike the SQL reporting modules, the scripts in this directory execute RMAN commands that create, validate, or remove backup metadata and backup files.

These scripts are intended for Oracle Database Administrators performing backup administration in a controlled environment.

---

## Target Environment

- Oracle Database 19c Enterprise Edition
- Oracle Linux 8.x
- RMAN
- Oracle software owner
- Target database using operating-system authentication

---

## Module Contents

| Script | Description |
|---------|-------------|
| 01_show_configuration.rman | Displays the current RMAN configuration and repository settings. |
| 02_full_database_backup.rman | Creates a compressed full online database backup. |
| 03_incremental_level0_backup.rman | Creates a compressed incremental level 0 backup. |
| 04_incremental_level1_backup.rman | Creates a compressed differential incremental level 1 backup. |
| 05_archivelog_backup.rman | Creates a compressed backup of archived redo logs not previously backed up. |
| 06_controlfile_spfile_backup.rman | Creates explicit backups of the current control file and server parameter file. |
| 07_validate_database.rman | Validates database blocks and backup availability without performing a restore. |
| 08_crosscheck_and_cleanup.rman | Crosschecks RMAN metadata and removes expired or obsolete backup records according to the configured retention policy. |
| run_rman_job.sh | Executes RMAN scripts with logging and basic execution validation. |

---

## Execution

Run RMAN scripts through the provided shell wrapper.

```bash
./run_rman_job.sh 02_full_database_backup.rman
```

The wrapper automatically:

- Starts RMAN.
- Creates timestamped log files.
- Stores execution logs.
- Checks the RMAN exit code and log for common RMAN, ORA, LRM, and SP2 errors.

---

## Notes

- RMAN scripts in this module perform real backup and maintenance operations.
- Backup destinations must exist and be writable before execution.
- RMAN connects using operating-system authentication.
- The backup directory may require adjustment for different environments.
- Validation operations may generate significant disk I/O.
- Output is intended for Oracle Database 19c.
- Review RMAN logs after every execution to verify successful completion.

---

## Safety

Some scripts permanently modify the RMAN repository and may delete physical backup files.

In particular:

- `08_crosscheck_and_cleanup.rman` executes cleanup operations based on the configured retention policy.
- Always review `REPORT OBSOLETE` output before allowing obsolete backups to be deleted.
- Verify the active retention policy before executing cleanup operations.
- Test all RMAN procedures in a non-production environment before applying them to production systems.

---