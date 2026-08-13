# =============================================================================
# Oracle Banking Database
# Module       : 02_Data_Deployment / 02_Data_Import
# Script       : 03_Import_All_Table_Data.ps1
# Purpose      : Verify the local Data Pump dump set, copy it into the Oracle
#                Docker container, verify the copied dump files, and run a
#                DATA_ONLY import into an existing empty BANKING_DB schema
#
# Requirements
#   - Docker Desktop is running.
#   - Container oracle_ee_23ai is running.
#   - Target schema objects already exist.
#   - The 23 included target tables are empty.
#   - BANKING_DB has READ and WRITE on DATA_PUMP_DIR.
#   - The following files are available in the source export_output directory:
#       banking_data_01.dmp
#       banking_data_02.dmp
#       checksums.sha256
#   - 02_Import_All_Table_Data.par is in the same folder as this script.
#
# Security
#   - The script does not store the BANKING_DB password.
#   - impdp prompts for the password interactively.
# =============================================================================

[CmdletBinding()]
param(
    [string]$ContainerName = "oracle_ee_23ai",
    [string]$DatabaseService = "ORCLPDB1",
    [string]$SchemaUser = "BANKING_DB",
    [string]$ContainerParFile = "/tmp/02_Import_All_Table_Data.par",
    [string]$DataPumpPath = "/opt/oracle/admin/ORCLCDB/dpdump/5568D25A59CF0DCCE063030011AC2144",
    [string]$SourceExportDirectory = (Join-Path $PSScriptRoot "..\01_Data_Export\export_output"),
    [string]$ImportOutputDirectory = (Join-Path $PSScriptRoot "import_output")
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

function Assert-LastExitCode {
    param([string]$Operation)

    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed. Docker exit code: $LASTEXITCODE"
    }
}

$ParFile = Join-Path $PSScriptRoot "02_Import_All_Table_Data.par"
$ChecksumFile = Join-Path $SourceExportDirectory "checksums.sha256"

$ExpectedDumpFiles = @(
    "banking_data_01.dmp",
    "banking_data_02.dmp"
)

Write-Step "A. LOCAL PRECHECK"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI was not found in PATH."
}

if (-not (Test-Path -LiteralPath $ParFile)) {
    throw "Import parameter file not found: $ParFile"
}

if (-not (Test-Path -LiteralPath $SourceExportDirectory)) {
    throw "Source export directory not found: $SourceExportDirectory"
}

if (-not (Test-Path -LiteralPath $ChecksumFile)) {
    throw "Checksum file not found: $ChecksumFile"
}

foreach ($DumpFileName in $ExpectedDumpFiles) {
    $DumpFilePath = Join-Path $SourceExportDirectory $DumpFileName

    if (-not (Test-Path -LiteralPath $DumpFilePath)) {
        throw "Expected dump file not found: $DumpFilePath"
    }
}

$RunningState = docker inspect -f "{{.State.Running}}" $ContainerName 2>$null
Assert-LastExitCode "Container inspection"

if ($RunningState.Trim() -ne "true") {
    throw "Docker container '$ContainerName' is not running."
}

Write-Host "Container              : $ContainerName"
Write-Host "Database service       : $DatabaseService"
Write-Host "Schema user            : $SchemaUser"
Write-Host "Import parameter file  : $ParFile"
Write-Host "Source export directory: $SourceExportDirectory"
Write-Host "Data Pump path         : $DataPumpPath"
Write-Host "Import output directory: $ImportOutputDirectory"

Write-Step "B. VERIFY LOCAL SHA-256 CHECKSUMS"

$ChecksumEntries = @{}

foreach ($Line in Get-Content -LiteralPath $ChecksumFile) {
    if ($Line -notmatch '^([a-fA-F0-9]{64})\s{2}(.+)$') {
        throw "Invalid checksum line: $Line"
    }

    $ChecksumEntries[$Matches[2]] = $Matches[1].ToLowerInvariant()
}

foreach ($DumpFileName in $ExpectedDumpFiles) {
    if (-not $ChecksumEntries.ContainsKey($DumpFileName)) {
        throw "No checksum entry found for $DumpFileName"
    }

    $DumpFilePath = Join-Path $SourceExportDirectory $DumpFileName
    $ActualHash = (Get-FileHash -LiteralPath $DumpFilePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $ExpectedHash = $ChecksumEntries[$DumpFileName]

    if ($ActualHash -ne $ExpectedHash) {
        throw "Checksum mismatch for $DumpFileName"
    }

    Write-Host "[PASS] $DumpFileName"
}

Write-Step "C. COPY IMPORT PARAMETER FILE INTO CONTAINER"

docker cp $ParFile "${ContainerName}:$ContainerParFile"
Assert-LastExitCode "Copying the import parameter file into the container"

docker exec $ContainerName bash -lc "test -r '$ContainerParFile'"
Assert-LastExitCode "Verifying the import parameter file inside the container"

Write-Host "Import parameter file copied successfully."

Write-Step "D. COPY DUMP FILES INTO DATA_PUMP_DIR"

foreach ($DumpFileName in $ExpectedDumpFiles) {
    $DumpFilePath = Join-Path $SourceExportDirectory $DumpFileName

    docker cp $DumpFilePath "${ContainerName}:$DataPumpPath/$DumpFileName"
    Assert-LastExitCode "Copying $DumpFileName into DATA_PUMP_DIR"
}

Write-Host "Dump files copied successfully."

Write-Step "E. VERIFY CONTAINER SHA-256 CHECKSUMS"

foreach ($DumpFileName in $ExpectedDumpFiles) {
    docker exec $ContainerName bash -lc "test -f '$DataPumpPath/$DumpFileName'"
    Assert-LastExitCode "Verifying $DumpFileName inside the container"

    $ContainerHashOutput = docker exec $ContainerName `
        bash -lc "sha256sum '$DataPumpPath/$DumpFileName'"

    Assert-LastExitCode "Calculating container checksum for $DumpFileName"

    $ContainerHashLine = ($ContainerHashOutput | Out-String).Trim()

    if ($ContainerHashLine -notmatch '^([a-fA-F0-9]{64})\s+') {
        throw "Unable to parse container checksum for $DumpFileName"
    }

    $ContainerHash = $Matches[1].ToLowerInvariant()
    $ExpectedHash = $ChecksumEntries[$DumpFileName]

    if ($ContainerHash -ne $ExpectedHash) {
        throw "Container checksum mismatch for $DumpFileName"
    }

    Write-Host "[PASS] $DumpFileName"
}

Write-Step "F. REMOVE OLD IMPORT LOG"

docker exec $ContainerName bash -lc "rm -f '$DataPumpPath/banking_data_import.log'"
Assert-LastExitCode "Removing the previous import log"

Write-Step "G. RUN ORACLE DATA PUMP IMPORT"

Write-Host "IMPORTANT: Run 01_Data_Import_Precheck.sql first." -ForegroundColor Yellow
Write-Host "Continue only if INCLUDED_TABLE_ROWS_BEFORE_IMPORT = 0 PASS." -ForegroundColor Yellow
Write-Host ""
Write-Host "impdp will prompt for the BANKING_DB password." -ForegroundColor Yellow
Write-Host "The password is not stored by this script." -ForegroundColor Yellow
Write-Host ""

$Confirmation = Read-Host "Type IMPORT to start the Data Pump import"

if ($Confirmation -cne "IMPORT") {
    throw "Import cancelled. The required confirmation text was not entered."
}

docker exec -it $ContainerName `
    bash -lc "impdp '${SchemaUser}@${DatabaseService}' parfile='$ContainerParFile'"

Assert-LastExitCode "Oracle Data Pump import"

Write-Step "H. VERIFY IMPORT LOG"

docker exec $ContainerName bash -lc "test -f '$DataPumpPath/banking_data_import.log'"
Assert-LastExitCode "Verifying the Data Pump import log"

New-Item -ItemType Directory -Path $ImportOutputDirectory -Force | Out-Null

docker cp "${ContainerName}:$DataPumpPath/banking_data_import.log" $ImportOutputDirectory
Assert-LastExitCode "Copying banking_data_import.log to Windows"

Write-Step "I. IMPORT LOG SUMMARY"

$LocalImportLog = Join-Path $ImportOutputDirectory "banking_data_import.log"

if (-not (Test-Path -LiteralPath $LocalImportLog)) {
    throw "Import log was not copied to Windows: $LocalImportLog"
}

$SuccessLine = Select-String `
    -Path $LocalImportLog `
    -Pattern 'successfully completed' `
    -SimpleMatch

$OraErrors = Select-String `
    -Path $LocalImportLog `
    -Pattern 'ORA-[0-9]{5}' `
    -AllMatches

if ($OraErrors) {
    Write-Host "Oracle errors found in import log:" -ForegroundColor Red

    $OraErrors | ForEach-Object {
        Write-Host $_.Line -ForegroundColor Red
    }

    throw "The Data Pump import log contains ORA errors."
}

if (-not $SuccessLine) {
    throw "The import log does not contain a successful completion message."
}

Write-Host "[PASS] No ORA errors found."
Write-Host "[PASS] Successful completion message found."

Write-Step "IMPORT COMPLETED"

Write-Host "Import log:"
Write-Host $LocalImportLog
Write-Host ""
Write-Host "Run the following next:"
Write-Host "  04_Synchronize_Application_Sequences.sql"
Write-Host "  05_Data_Import_Postcheck.sql"