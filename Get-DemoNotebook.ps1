#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Obtains a pinned upstream demo notebook for local use without republishing it in this repository.
.DESCRIPTION
    Downloads public upstream content or uses a customer-supplied copy. Enforces the adapter SHA256 pin.
.PARAMETER SourcePath
    Optional local copy of the upstream notebook instead of downloading.
.EXAMPLE
    .\Get-DemoNotebook.ps1
.NOTES
    Upstream attribution and redistribution boundaries are documented in docs/demo-provenance.md.
#>
[CmdletBinding()]
param([string]$SourcePath)
$ErrorActionPreference = 'Stop'

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    $Destination = Join-Path $PSScriptRoot 'Zombie_Outbreak_Spread.ipynb'
    $TemporaryPath = "$Destination.tmp"
    $ExpectedHashes = @(
        '5ED29ADEAF63C977FEC3535A01F72E07865F0D11D80F7120DBC6E9D0AD645738'
        '01BAB46195C2CFE4D5AF84E5446477CEB7BE9713DF8430F427945CBC52D1C53A'
    )
    try {
        if (Test-Path -LiteralPath $Destination) {
            if ((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -notin $ExpectedHashes) {
                throw 'Existing notebook does not match the pin. Review it; it will not be overwritten.'
            }
            Write-Host 'Pinned demo notebook already present.'
        } else {
            if ($SourcePath) {
                Copy-Item -LiteralPath $SourcePath -Destination $TemporaryPath
            } else {
                Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/SeanKMcG/fabric_zombie_outbreak/29ac7cdeee63d7cadc8538a128384b58f13aa2c8/Zombie_Outbreak_Spread.ipynb' -OutFile $TemporaryPath
            }
            if ((Get-FileHash -LiteralPath $TemporaryPath -Algorithm SHA256).Hash -notin $ExpectedHashes) {
                throw 'Upstream notebook fingerprint mismatch. No notebook installed; review adapter compatibility.'
            }
            Move-Item -LiteralPath $TemporaryPath -Destination $Destination
            Write-Host 'Pinned upstream notebook installed locally. Do not add it or generated notebook state to Git.'
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue $_.Exception.Message
        exit 1
    }
    finally {
        if (Test-Path -LiteralPath $TemporaryPath) { Remove-Item -LiteralPath $TemporaryPath }
    }
}
#endregion
