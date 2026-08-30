[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$AttemptId
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ControlRoot = 'C:\Development\quantization-path-dependence'
$HeavyRoot = 'F:\quantization-path-dependence'
$AllowlistPath = Join-Path $ControlRoot 'execution_input\source-model-allowlist.json'
$DownloadRoot = Join-Path $HeavyRoot "work\downloads\$AttemptId"
$VerifiedRoot = Join-Path $DownloadRoot 'verified'
$FinalRoot = Join-Path $HeavyRoot 'source\model\mistralai--Mistral-7B-v0.3\caa1feb0e54d415e2df31207e5f4e273e33509b1\files'
$BaseUrl = 'https://huggingface.co/mistralai/Mistral-7B-v0.3/resolve/caa1feb0e54d415e2df31207e5f4e273e33509b1'
$MinimumFreeBytes = 160000000000

function Assert-UnderHeavyRoot([string]$Path) {
    $root = [System.IO.Path]::GetFullPath($HeavyRoot).TrimEnd('\') + '\'
    $candidate = [System.IO.Path]::GetFullPath($Path)
    if (-not $candidate.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes approved heavy-object root: $candidate"
    }
}

Assert-UnderHeavyRoot $DownloadRoot
Assert-UnderHeavyRoot $VerifiedRoot
Assert-UnderHeavyRoot $FinalRoot

if (-not (Test-Path -LiteralPath 'F:\')) {
    throw 'Approved F: volume is unavailable.'
}

$freeBytes = [int64](Get-PSDrive -Name F).Free
if ($freeBytes -lt $MinimumFreeBytes) {
    throw "F: free space $freeBytes is below the required $MinimumFreeBytes bytes."
}

if (Test-Path -LiteralPath $FinalRoot) {
    throw "Final source directory already exists; refusing to merge or overwrite: $FinalRoot"
}

$allowlist = Get-Content -LiteralPath $AllowlistPath -Raw | ConvertFrom-Json
if ($allowlist.status -ne 'fixed-before-model-payload-retrieval') {
    throw "Unexpected allowlist status: $($allowlist.status)"
}
if ($allowlist.revision -ne 'caa1feb0e54d415e2df31207e5f4e273e33509b1') {
    throw "Unexpected source revision: $($allowlist.revision)"
}
if (@($allowlist.files).Count -ne 11) {
    throw "Expected 11 allowlisted files, found $(@($allowlist.files).Count)."
}

New-Item -ItemType Directory -Path $VerifiedRoot -Force | Out-Null

$results = [System.Collections.Generic.List[object]]::new()
$started = (Get-Date).ToUniversalTime().ToString('o')
Write-Output "retrieval_started_utc=$started"
Write-Output "attempt_id=$AttemptId"
Write-Output "allowlist_sha256=$((Get-FileHash -LiteralPath $AllowlistPath -Algorithm SHA256).Hash)"
Write-Output "curl_version=$((curl.exe --version | Select-Object -First 1))"
Write-Output "free_bytes_before=$freeBytes"

foreach ($entry in $allowlist.files) {
    $name = [string]$entry.path
    if ([System.IO.Path]::GetFileName($name) -ne $name -or $name.Contains('/') -or $name.Contains('\')) {
        throw "Allowlisted path is not a simple filename: $name"
    }

    $expectedBytes = [int64]$entry.expected_bytes
    $expectedSha256 = if ($null -eq $entry.expected_sha256) { $null } else { ([string]$entry.expected_sha256).ToUpperInvariant() }
    $partPath = Join-Path $DownloadRoot "$name.part"
    $verifiedPath = Join-Path $VerifiedRoot $name
    Assert-UnderHeavyRoot $partPath
    Assert-UnderHeavyRoot $verifiedPath

    if (-not (Test-Path -LiteralPath $verifiedPath)) {
        $url = "$BaseUrl/$name"
        Write-Output "download_start=$name"
        curl.exe --fail --location --silent --show-error --retry 5 --retry-all-errors --continue-at - --output $partPath $url
        if ($LASTEXITCODE -ne 0) {
            throw "curl failed for $name with exit code $LASTEXITCODE"
        }

        $actualBytes = [int64](Get-Item -LiteralPath $partPath).Length
        if ($actualBytes -ne $expectedBytes) {
            throw "Size mismatch for ${name}: expected $expectedBytes, got $actualBytes"
        }

        $actualSha256 = (Get-FileHash -LiteralPath $partPath -Algorithm SHA256).Hash
        if ($null -ne $expectedSha256 -and $actualSha256 -ne $expectedSha256) {
            throw "SHA-256 mismatch for ${name}: expected $expectedSha256, got $actualSha256"
        }

        Move-Item -LiteralPath $partPath -Destination $verifiedPath
    }

    $verifiedBytes = [int64](Get-Item -LiteralPath $verifiedPath).Length
    $verifiedSha256 = (Get-FileHash -LiteralPath $verifiedPath -Algorithm SHA256).Hash
    if ($verifiedBytes -ne $expectedBytes) {
        throw "Verified-file size mismatch for ${name}: expected $expectedBytes, got $verifiedBytes"
    }
    if ($null -ne $expectedSha256 -and $verifiedSha256 -ne $expectedSha256) {
        throw "Verified-file SHA-256 mismatch for ${name}: expected $expectedSha256, got $verifiedSha256"
    }

    $results.Add([pscustomobject]@{
        path = $name
        bytes = $verifiedBytes
        sha256 = $verifiedSha256
        expected_lfs_sha256_matched = ($null -eq $expectedSha256 -or $verifiedSha256 -eq $expectedSha256)
    })
    Write-Output "verified=$name bytes=$verifiedBytes sha256=$verifiedSha256"
}

$actualNames = @(Get-ChildItem -LiteralPath $VerifiedRoot -File | Sort-Object Name | ForEach-Object Name)
$expectedNames = @($allowlist.files | ForEach-Object path | Sort-Object)
if (($actualNames -join "`n") -ne ($expectedNames -join "`n")) {
    throw 'Verified directory membership differs from the frozen allowlist.'
}

$finalParent = Split-Path -Parent $FinalRoot
New-Item -ItemType Directory -Path $finalParent -Force | Out-Null
Move-Item -LiteralPath $VerifiedRoot -Destination $FinalRoot

$finished = (Get-Date).ToUniversalTime().ToString('o')
$finalBytes = [int64](($results | Measure-Object bytes -Sum).Sum)
$freeAfter = [int64](Get-PSDrive -Name F).Free
Write-Output "retrieval_finished_utc=$finished"
Write-Output "selected_file_count=$($results.Count)"
Write-Output "selected_total_bytes=$finalBytes"
Write-Output "free_bytes_after=$freeAfter"
Write-Output ($results | ConvertTo-Json -Depth 4 -Compress)
