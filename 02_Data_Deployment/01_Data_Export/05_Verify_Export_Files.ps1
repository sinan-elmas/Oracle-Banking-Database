# =============================================================================
# Oracle Banking Database
# Module       : 02_Data_Deployment / 01_Data_Export
# Script       : 05_Verify_Export_Files.ps1
# Purpose      : Generate SHA-256 checksums for the Data Pump dump pieces and
#                verify that the expected export files are present
#
# Expected files in export_output:
#   banking_data_01.dmp
#   banking_data_02.dmp
#   banking_data_export.log
# =============================================================================

[CmdletBinding()]
param(
    [string]$ExportDirectory = (Join-Path $PSScriptRoot "export_output"),
    [string]$ChecksumFile = (Join-Path $PSScriptRoot "export_output\checksums.sha256")
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

Write-Step "A. EXPORT FILE PRESENCE CHECK"

if (-not (Test-Path -LiteralPath $ExportDirectory)) {
    throw "Export directory not found: $ExportDirectory"
}

$ExpectedFiles = @(
    "banking_data_01.dmp",
    "banking_data_02.dmp",
    "banking_data_export.log"
)

$MissingFiles = @()

foreach ($FileName in $ExpectedFiles) {
    $FilePath = Join-Path $ExportDirectory $FileName

    if (Test-Path -LiteralPath $FilePath) {
        Write-Host "[PASS] $FileName"
    }
    else {
        Write-Host "[FAIL] $FileName" -ForegroundColor Red
        $MissingFiles += $FileName
    }
}

if ($MissingFiles.Count -gt 0) {
    throw "Missing expected export file(s): $($MissingFiles -join ', ')"
}

Write-Step "B. EXPORT FILE SIZE INVENTORY"

$Files = Get-ChildItem -LiteralPath $ExportDirectory -File |
    Where-Object {
        $_.Name -like "banking_data_*.dmp" -or
        $_.Name -eq "banking_data_export.log"
    } |
    Sort-Object Name

$Files |
    Select-Object Name,
                  @{Name = "SizeBytes"; Expression = { $_.Length }},
                  @{Name = "SizeMB"; Expression = { [math]::Round($_.Length / 1MB, 2) }},
                  LastWriteTime |
    Format-Table -AutoSize

Write-Step "C. SHA-256 CHECKSUM GENERATION"

$DumpFiles = Get-ChildItem -LiteralPath $ExportDirectory -File -Filter "banking_data_*.dmp" |
    Sort-Object Name

if ($DumpFiles.Count -ne 2) {
    throw "Expected exactly 2 dump pieces, but found $($DumpFiles.Count)."
}

$ChecksumLines = foreach ($DumpFile in $DumpFiles) {
    $Hash = Get-FileHash -LiteralPath $DumpFile.FullName -Algorithm SHA256

    "{0}  {1}" -f $Hash.Hash.ToLowerInvariant(), $DumpFile.Name
}

$ChecksumLines | Set-Content -LiteralPath $ChecksumFile -Encoding ascii

Write-Host "Checksum file created:"
Write-Host $ChecksumFile
Write-Host ""

Get-Content -LiteralPath $ChecksumFile

Write-Step "D. CHECKSUM SELF-VERIFICATION"

$VerificationFailures = @()

foreach ($Line in Get-Content -LiteralPath $ChecksumFile) {
    if ($Line -notmatch '^([a-f0-9]{64})\s{2}(.+)$') {
        $VerificationFailures += "Invalid checksum line: $Line"
        continue
    }

    $ExpectedHash = $Matches[1]
    $FileName = $Matches[2]
    $FilePath = Join-Path $ExportDirectory $FileName

    if (-not (Test-Path -LiteralPath $FilePath)) {
        $VerificationFailures += "File not found: $FileName"
        continue
    }

    $ActualHash = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()

    if ($ActualHash -eq $ExpectedHash) {
        Write-Host "[PASS] $FileName"
    }
    else {
        Write-Host "[FAIL] $FileName" -ForegroundColor Red
        $VerificationFailures += "Checksum mismatch: $FileName"
    }
}

if ($VerificationFailures.Count -gt 0) {
    throw ($VerificationFailures -join [Environment]::NewLine)
}

Write-Step "EXPORT FILE VERIFICATION COMPLETED"

Write-Host "Expected dump pieces : 2"
Write-Host "Verified dump pieces : $($DumpFiles.Count)"
Write-Host "Checksum algorithm   : SHA-256"
Write-Host "Overall status       : PASS"
