# =============================================================================
# Oracle Banking Database
# Module       : 02_Data_Deployment / 01_Data_Export
# Script       : 04_Export_All_Table_Data.ps1
# Purpose      : Copy the Data Pump parameter file into the Oracle container,
#                run a DATA_ONLY export for the 23 included tables, and copy
#                the generated dump pieces and export log back to Windows
#
# Requirements
#   - Docker Desktop is running.
#   - Container oracle_ee_23ai is running.
#   - BANKING_DB has READ and WRITE on DATA_PUMP_DIR.
#   - 03_Export_All_Table_Data.par is in the same folder as this script.
#
# Security
#   - The script does not store the BANKING_DB password.
#   - expdp prompts for the password interactively.
# =============================================================================

[CmdletBinding()]
param(
    [string]$ContainerName = "oracle_ee_23ai",
    [string]$DatabaseService = "ORCLPDB1",
    [string]$SchemaUser = "BANKING_DB",
    [string]$ContainerParFile = "/tmp/03_Export_All_Table_Data.par",
    [string]$DataPumpPath = "/opt/oracle/admin/ORCLCDB/dpdump/5568D25A59CF0DCCE063030011AC2144",
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "export_output")
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

$ParFile = Join-Path $PSScriptRoot "03_Export_All_Table_Data.par"

Write-Step "A. PRECHECK"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI was not found in PATH."
}

if (-not (Test-Path -LiteralPath $ParFile)) {
    throw "Parameter file not found: $ParFile"
}

$RunningState = docker inspect -f "{{.State.Running}}" $ContainerName 2>$null
Assert-LastExitCode "Container inspection"

if ($RunningState.Trim() -ne "true") {
    throw "Docker container '$ContainerName' is not running."
}

Write-Host "Container       : $ContainerName"
Write-Host "Database service: $DatabaseService"
Write-Host "Schema user     : $SchemaUser"
Write-Host "Parameter file  : $ParFile"
Write-Host "Data Pump path  : $DataPumpPath"
Write-Host "Output directory: $OutputDirectory"

Write-Step "B. COPY PARAMETER FILE INTO CONTAINER"

docker cp $ParFile "${ContainerName}:$ContainerParFile"
Assert-LastExitCode "Copying the parameter file into the container"

docker exec $ContainerName bash -lc "test -r '$ContainerParFile'"
Assert-LastExitCode "Verifying the parameter file inside the container"

Write-Host "Parameter file copied successfully."

Write-Step "C. REMOVE OLD EXPORT FILES WITH THE SAME NAME"

docker exec $ContainerName bash -lc "rm -f '$DataPumpPath'/banking_data_*.dmp '$DataPumpPath'/banking_data_export.log"
Assert-LastExitCode "Removing old export files"

Write-Host "Old banking_data export files removed from DATA_PUMP_DIR."

Write-Step "D. RUN ORACLE DATA PUMP EXPORT"

Write-Host "expdp will prompt for the BANKING_DB password." -ForegroundColor Yellow
Write-Host "The password is not stored by this script." -ForegroundColor Yellow
Write-Host ""

docker exec -it $ContainerName bash -lc "expdp '${SchemaUser}@${DatabaseService}' parfile='$ContainerParFile'"
Assert-LastExitCode "Oracle Data Pump export"

Write-Step "E. VERIFY GENERATED FILES"

$DumpFileNames = @(
    docker exec $ContainerName bash -lc "find '$DataPumpPath' -maxdepth 1 -type f -name 'banking_data_*.dmp' -printf '%f\n' | sort"
)
Assert-LastExitCode "Listing generated dump files"

$DumpFileNames = @(
    $DumpFileNames |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne "" }
)

if ($DumpFileNames.Count -eq 0) {
    throw "No banking_data_*.dmp file was found after export."
}

docker exec $ContainerName bash -lc "test -f '$DataPumpPath/banking_data_export.log'"
Assert-LastExitCode "Verifying the Data Pump export log"

Write-Host "Generated dump pieces:"
$DumpFileNames | ForEach-Object { Write-Host "  $_" }
Write-Host "  banking_data_export.log"

Write-Step "F. COPY EXPORT FILES TO WINDOWS"

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

foreach ($DumpFileName in $DumpFileNames) {
    $Source = "${ContainerName}:$DataPumpPath/$DumpFileName"
    docker cp $Source $OutputDirectory
    Assert-LastExitCode "Copying $DumpFileName to Windows"
}

docker cp "${ContainerName}:$DataPumpPath/banking_data_export.log" $OutputDirectory
Assert-LastExitCode "Copying banking_data_export.log to Windows"

Write-Step "G. WINDOWS EXPORT INVENTORY"

$CopiedFiles = Get-ChildItem -LiteralPath $OutputDirectory -File |
    Where-Object {
        $_.Name -like "banking_data_*.dmp" -or
        $_.Name -eq "banking_data_export.log"
    } |
    Sort-Object Name

$CopiedFiles |
    Select-Object Name,
                  @{Name = "SizeMB"; Expression = { [math]::Round($_.Length / 1MB, 2) }},
                  LastWriteTime |
    Format-Table -AutoSize

Write-Step "EXPORT COMPLETED"

Write-Host "Export output:"
Write-Host $OutputDirectory
Write-Host ""
Write-Host "Review banking_data_export.log before treating the dump set as final."
