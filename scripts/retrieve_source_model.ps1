[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]{0,63}$')]
    [string]$AttemptId,

    [switch]$AdoptUnboundAttempt
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptVersion = '1.2.0'
$ControlRoot = 'C:\Development\quantization-path-dependence'
$HeavyRoot = 'F:\quantization-path-dependence'
$AllowlistPath = Join-Path $ControlRoot 'execution_input\source-model-allowlist.json'
$ValidatorPath = Join-Path $ControlRoot 'scripts\validate_safetensors_set.py'
$DownloadRoot = Join-Path $HeavyRoot "work\downloads\$AttemptId"
$VerifiedRoot = Join-Path $DownloadRoot 'verified'
$BindingPath = Join-Path $DownloadRoot '.retrieval-binding.json'
$LogRoot = Join-Path $HeavyRoot 'logs\source'
$EventLogPath = Join-Path $LogRoot "$AttemptId.jsonl"
$ValidatedManifestPath = Join-Path $LogRoot "$AttemptId.validated-manifest.json"
$PromotionReceiptPath = Join-Path $LogRoot "$AttemptId.promotion-receipt.json"
$LockPath = Join-Path $LogRoot "$AttemptId.lock"
$FinalRoot = Join-Path $HeavyRoot 'source\model\mistralai--Mistral-7B-v0.3\caa1feb0e54d415e2df31207e5f4e273e33509b1\files'
$BaseUrl = 'https://huggingface.co/mistralai/Mistral-7B-v0.3/resolve/caa1feb0e54d415e2df31207e5f4e273e33509b1'
$Revision = 'caa1feb0e54d415e2df31207e5f4e273e33509b1'
$MinimumFreeBytes = 160000000000
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Get-FullPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-UnderHeavyRoot([string]$Path) {
    $root = (Get-FullPath $HeavyRoot).TrimEnd('\') + '\'
    $candidate = Get-FullPath $Path
    if (-not $candidate.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes approved heavy-object root: $candidate"
    }
}

function Assert-NoReparseComponent([string]$Path) {
    $full = Get-FullPath $Path
    $root = [System.IO.Path]::GetPathRoot($full)
    $relative = $full.Substring($root.Length)
    $cursor = $root
    foreach ($segment in $relative.Split('\', [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $cursor = Join-Path $cursor $segment
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse point is prohibited in retrieval path: $cursor"
            }
        }
    }
}

function Write-Event([string]$Event, [hashtable]$Data = @{}) {
    $record = [ordered]@{
        utc = (Get-Date).ToUniversalTime().ToString('o')
        attempt_id = $AttemptId
        event = $Event
        script_version = $ScriptVersion
        script_sha256 = $scriptHash
        allowlist_sha256 = $allowlistHash
        data = $Data
    }
    $line = ($record | ConvertTo-Json -Depth 10 -Compress) + "`n"
    [System.IO.File]::AppendAllText($EventLogPath, $line, $Utf8NoBom)
}

function Assert-PlainFile([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) {
        throw "Expected a file, found a directory: $Path"
    }
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Reparse-point files are prohibited: $Path"
    }
}

function Test-DownloadedFile([string]$Path, [object]$Entry) {
    Assert-PlainFile $Path
    $name = [string]$Entry.path
    $expectedBytes = [int64]$Entry.expected_bytes
    $actualBytes = [int64](Get-Item -LiteralPath $Path -Force).Length
    if ($actualBytes -ne $expectedBytes) {
        throw "Size mismatch for ${name}: expected $expectedBytes, got $actualBytes"
    }

    $actualSha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    $expectedSha256 = if ($null -eq $Entry.expected_sha256) { $null } else { ([string]$Entry.expected_sha256).ToUpperInvariant() }
    $gitBlobSha1 = $null
    $identityKind = $null
    $identityExpected = $null

    if ($null -ne $expectedSha256) {
        $identityKind = 'published-lfs-sha256'
        $identityExpected = $expectedSha256
        if ($actualSha256 -ne $expectedSha256) {
            throw "SHA-256 mismatch for ${name}: expected $expectedSha256, got $actualSha256"
        }
    }
    else {
        $identityKind = 'published-git-blob-sha1'
        $identityExpected = ([string]$Entry.git_blob_sha1).ToLowerInvariant()
        $gitBlobSha1 = ((git hash-object --no-filters -- $Path) -join '').Trim().ToLowerInvariant()
        if ($LASTEXITCODE -ne 0) {
            throw "git hash-object failed for $name with exit code $LASTEXITCODE"
        }
        if ($gitBlobSha1 -ne $identityExpected) {
            throw "Git blob mismatch for ${name}: expected $identityExpected, got $gitBlobSha1"
        }
    }

    return [pscustomobject]@{
        path = $name
        bytes = $actualBytes
        sha256 = $actualSha256
        git_blob_sha1 = $gitBlobSha1
        identity_kind = $identityKind
        identity_expected = $identityExpected
        identity_matched = $true
    }
}

function Assert-AttemptTopology([string[]]$ExpectedNames) {
    Assert-NoReparseComponent $DownloadRoot
    $expectedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($name in $ExpectedNames) {
        [void]$expectedSet.Add($name)
    }

    foreach ($item in @(Get-ChildItem -LiteralPath $DownloadRoot -Force)) {
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point in attempt root: $($item.FullName)"
        }
        if ($item.PSIsContainer) {
            if ($item.Name -ne 'verified') {
                throw "Unexpected directory in attempt root: $($item.Name)"
            }
        }
        elseif ($item.Name -ne '.retrieval-binding.json') {
            if (-not $item.Name.EndsWith('.part', [System.StringComparison]::Ordinal)) {
                throw "Unexpected file in attempt root: $($item.Name)"
            }
            $baseName = $item.Name.Substring(0, $item.Name.Length - 5)
            if (-not $expectedSet.Contains($baseName)) {
                throw "Unallowlisted partial file in attempt root: $($item.Name)"
            }
        }
    }

    if (Test-Path -LiteralPath $VerifiedRoot) {
        foreach ($item in @(Get-ChildItem -LiteralPath $VerifiedRoot -Force -Recurse)) {
            if ($item.PSIsContainer) {
                throw "Subdirectories are prohibited in verified source: $($item.FullName)"
            }
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse point in verified source: $($item.FullName)"
            }
            if ($item.DirectoryName -ne $VerifiedRoot -or -not $expectedSet.Contains($item.Name)) {
                throw "Unexpected verified-source member: $($item.FullName)"
            }
        }
    }
}

foreach ($path in @($DownloadRoot, $VerifiedRoot, $BindingPath, $LogRoot, $EventLogPath, $ValidatedManifestPath, $PromotionReceiptPath, $LockPath, $FinalRoot)) {
    Assert-UnderHeavyRoot $path
}

if (-not (Test-Path -LiteralPath 'F:\')) {
    throw 'Approved F: volume is unavailable.'
}
if (Test-Path -LiteralPath $FinalRoot) {
    throw "Final source directory already exists; refusing to merge or overwrite: $FinalRoot"
}

$scriptHash = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
$allowlistHash = (Get-FileHash -LiteralPath $AllowlistPath -Algorithm SHA256).Hash
$validatorHash = (Get-FileHash -LiteralPath $ValidatorPath -Algorithm SHA256).Hash
$allowlist = Get-Content -LiteralPath $AllowlistPath -Raw | ConvertFrom-Json
if ($allowlist.status -ne 'fixed-before-model-payload-retrieval' -or $allowlist.revision -ne $Revision) {
    throw 'Allowlist status or revision differs from the frozen retrieval contract.'
}
if (@($allowlist.files).Count -ne 11) {
    throw "Expected 11 allowlisted files, found $(@($allowlist.files).Count)."
}
$expectedNames = @($allowlist.files | ForEach-Object { [string]$_.path } | Sort-Object)
foreach ($name in $expectedNames) {
    if ([System.IO.Path]::GetFileName($name) -ne $name -or $name.Contains('/') -or $name.Contains('\')) {
        throw "Allowlisted path is not a simple filename: $name"
    }
}

$freeBytes = [int64](Get-PSDrive -Name F).Free
if ($freeBytes -lt $MinimumFreeBytes) {
    throw "F: free space $freeBytes is below the required $MinimumFreeBytes bytes."
}

$downloadParent = Split-Path -Parent $DownloadRoot
$logParent = Split-Path -Parent $LogRoot
Assert-NoReparseComponent $downloadParent
Assert-NoReparseComponent $logParent
if (Test-Path -LiteralPath $DownloadRoot) {
    Assert-NoReparseComponent $DownloadRoot
}
if (Test-Path -LiteralPath $LogRoot) {
    Assert-NoReparseComponent $LogRoot
}
New-Item -ItemType Directory -Path $DownloadRoot -Force | Out-Null
New-Item -ItemType Directory -Path $VerifiedRoot -Force | Out-Null
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
Assert-NoReparseComponent $DownloadRoot
Assert-NoReparseComponent $VerifiedRoot
Assert-NoReparseComponent $LogRoot
$lockStream = [System.IO.File]::Open($LockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
Assert-AttemptTopology $expectedNames

$bindingExpected = [ordered]@{
    schema_version = '1.0.0'
    attempt_id = $AttemptId
    revision = $Revision
    base_url = $BaseUrl
    allowlist_sha256 = $allowlistHash
    script_sha256 = $scriptHash
    validator_sha256 = $validatorHash
    expected_names = $expectedNames
}

if (Test-Path -LiteralPath $BindingPath) {
    Assert-PlainFile $BindingPath
    $bindingActual = Get-Content -LiteralPath $BindingPath -Raw | ConvertFrom-Json
    $checks = @(
        $bindingActual.schema_version -eq $bindingExpected.schema_version,
        $bindingActual.attempt_id -eq $bindingExpected.attempt_id,
        $bindingActual.revision -eq $bindingExpected.revision,
        $bindingActual.base_url -eq $bindingExpected.base_url,
        $bindingActual.allowlist_sha256 -eq $bindingExpected.allowlist_sha256,
        $bindingActual.script_sha256 -eq $bindingExpected.script_sha256,
        $bindingActual.validator_sha256 -eq $bindingExpected.validator_sha256,
        ((@($bindingActual.expected_names) -join "`n") -eq ($expectedNames -join "`n"))
    )
    if ($checks -contains $false) {
        throw 'Existing attempt binding differs from the frozen URL/allowlist/script/validator contract.'
    }
}
else {
    $existingItems = @(Get-ChildItem -LiteralPath $DownloadRoot -Force -Recurse)
    $hasPayload = @($existingItems | Where-Object { -not $_.PSIsContainer }).Count -gt 0
    if ($hasPayload -and -not $AdoptUnboundAttempt) {
        throw 'Existing unbound payload requires explicit -AdoptUnboundAttempt after topology review.'
    }
    $bindingJson = $bindingExpected | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($BindingPath, $bindingJson + "`n", $Utf8NoBom)
}

$started = (Get-Date).ToUniversalTime().ToString('o')
$results = [System.Collections.Generic.List[object]]::new()
$scriptArgv = @($PSCommandPath, '-AttemptId', $AttemptId)
if ($AdoptUnboundAttempt) {
    $scriptArgv += '-AdoptUnboundAttempt'
}

try {
    Write-Event 'retrieval_started' @{
        started_utc = $started
        adopted_unbound_attempt = [bool]$AdoptUnboundAttempt
        binding_sha256 = (Get-FileHash -LiteralPath $BindingPath -Algorithm SHA256).Hash
        validator_sha256 = $validatorHash
        curl_version = ((curl.exe --version | Select-Object -First 1) -join '')
        git_version = ((git --version) -join '')
        free_bytes_before = $freeBytes
        maximum_internal_curl_retries = 1
        argv = $scriptArgv
        event_log_path = $EventLogPath
        validated_manifest_path = $ValidatedManifestPath
        promotion_receipt_path = $PromotionReceiptPath
    }

    foreach ($entry in $allowlist.files) {
        $name = [string]$entry.path
        $expectedBytes = [int64]$entry.expected_bytes
        $partPath = Join-Path $DownloadRoot "$name.part"
        $verifiedPath = Join-Path $VerifiedRoot $name
        Assert-UnderHeavyRoot $partPath
        Assert-UnderHeavyRoot $verifiedPath

        if (-not (Test-Path -LiteralPath $verifiedPath)) {
            $needCurl = $true
            if (Test-Path -LiteralPath $partPath) {
                Assert-PlainFile $partPath
                $partBytes = [int64](Get-Item -LiteralPath $partPath -Force).Length
                if ($partBytes -gt $expectedBytes) {
                    throw "Partial file exceeds expected size for ${name}: $partBytes > $expectedBytes"
                }
                if ($partBytes -eq $expectedBytes) {
                    $needCurl = $false
                    Write-Event 'complete_partial_adopted_without_network' @{path = $name; bytes = $partBytes}
                }
            }

            if ($needCurl) {
                $url = "$BaseUrl/$([System.Uri]::EscapeDataString($name))"
                $beforeBytes = if (Test-Path -LiteralPath $partPath) { [int64](Get-Item -LiteralPath $partPath -Force).Length } else { 0 }
                $curlEvidenceId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffffffZ')
                $curlStderrPath = Join-Path $LogRoot "$AttemptId.$name.$curlEvidenceId.curl.stderr.txt"
                Assert-UnderHeavyRoot $curlStderrPath
                $curlArgs = @(
                    '--fail', '--location', '--silent', '--show-error',
                    '--retry', '1', '--retry-all-errors', '--continue-at', '-',
                    '--output', $partPath, '--stderr', $curlStderrPath,
                    '--write-out', "%{http_code}`t%{num_retries}`t%{size_download}`t%{url_effective}",
                    $url
                )
                Write-Event 'download_started' @{
                    path = $name
                    existing_partial_bytes = $beforeBytes
                    argv = @('curl.exe') + $curlArgs
                    stderr_path = $curlStderrPath
                }
                $transport = ((& curl.exe @curlArgs) -join '')
                if ($LASTEXITCODE -ne 0) {
                    throw "curl failed for $name with exit code $LASTEXITCODE; stderr=$curlStderrPath"
                }
                $fields = $transport -split "`t", 4
                if ($fields.Count -ne 4) {
                    throw "Unexpected curl transport summary for $name"
                }
                $effectiveHost = ([System.Uri]$fields[3]).Host
                Write-Event 'download_finished' @{
                    path = $name
                    http_code = [int]$fields[0]
                    internal_retries = [int]$fields[1]
                    transferred_bytes = [double]$fields[2]
                    effective_host = $effectiveHost
                    stderr_path = $curlStderrPath
                    stderr_sha256 = (Get-FileHash -LiteralPath $curlStderrPath -Algorithm SHA256).Hash
                }
            }

            $validatedPart = Test-DownloadedFile $partPath $entry
            Move-Item -LiteralPath $partPath -Destination $verifiedPath
            Write-Event 'file_verified' @{
                path = $validatedPart.path
                bytes = $validatedPart.bytes
                sha256 = $validatedPart.sha256
                git_blob_sha1 = $validatedPart.git_blob_sha1
                identity_kind = $validatedPart.identity_kind
                identity_expected = $validatedPart.identity_expected
            }
        }

        $validated = Test-DownloadedFile $verifiedPath $entry
        $results.Add($validated)
    }

    Assert-AttemptTopology $expectedNames
    $actualItems = @(Get-ChildItem -LiteralPath $VerifiedRoot -Force)
    if (@($actualItems | Where-Object { $_.PSIsContainer }).Count -ne 0) {
        throw 'Verified source contains a directory.'
    }
    $actualNames = @($actualItems | Sort-Object Name | ForEach-Object Name)
    if (($actualNames -join "`n") -ne ($expectedNames -join "`n")) {
        throw 'Verified directory membership differs from the frozen allowlist.'
    }

    $python = Get-Command python -ErrorAction Stop
    $pythonHash = (Get-FileHash -LiteralPath $python.Source -Algorithm SHA256).Hash
    $validatorEvidenceId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffffffZ')
    $validatorStderrPath = Join-Path $LogRoot "$AttemptId.$validatorEvidenceId.validator.stderr.txt"
    Assert-UnderHeavyRoot $validatorStderrPath
    $validatorArgs = @(
        $ValidatorPath,
        '--source-dir', $VerifiedRoot,
        '--expected-tensor-count', '291',
        '--expected-dtype', 'BF16',
        '--expected-total-size', '14496047104',
        '--require-zero-unreferenced'
    )
    Write-Event 'safetensors_validator_started' @{
        argv = @($python.Source) + $validatorArgs
        stderr_path = $validatorStderrPath
        python_sha256 = $pythonHash
        validator_sha256 = $validatorHash
    }
    $validatorOutput = ((& $python.Source @validatorArgs 2> $validatorStderrPath) -join '')
    if ($LASTEXITCODE -ne 0) {
        throw "Safetensors validator failed with exit code $LASTEXITCODE; stderr=$validatorStderrPath"
    }
    $safetensors = $validatorOutput | ConvertFrom-Json
    if (-not $safetensors.valid) {
        throw 'Safetensors validator did not return valid=true.'
    }
    Write-Event 'safetensors_set_validated' @{
        validator_sha256 = $validatorHash
        python_path = $python.Source
        python_sha256 = $pythonHash
        tensor_count = $safetensors.tensor_count
        tensor_bytes = $safetensors.tensor_bytes
        dtype_histogram = $safetensors.dtype_histogram
        stderr_path = $validatorStderrPath
        stderr_sha256 = (Get-FileHash -LiteralPath $validatorStderrPath -Algorithm SHA256).Hash
    }

    $validatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    $finalBytes = [int64](($results | Measure-Object bytes -Sum).Sum)
    $manifest = [ordered]@{
        schema_version = '1.0.0'
        status = 'validated-and-authorized-for-promotion'
        attempt_id = $AttemptId
        started_utc = $started
        validated_utc = $validatedUtc
        revision = $Revision
        base_url = $BaseUrl
        argv = $scriptArgv
        script_version = $ScriptVersion
        script_sha256 = $scriptHash
        validator_sha256 = $validatorHash
        validator_argv = @($python.Source) + $validatorArgs
        validator_stderr_path = $validatorStderrPath
        validator_stderr_sha256 = (Get-FileHash -LiteralPath $validatorStderrPath -Algorithm SHA256).Hash
        python_path = $python.Source
        python_sha256 = $pythonHash
        allowlist_sha256 = $allowlistHash
        binding_sha256 = (Get-FileHash -LiteralPath $BindingPath -Algorithm SHA256).Hash
        event_log_path = $EventLogPath
        planned_final_root = $FinalRoot
        selected_file_count = $results.Count
        selected_total_bytes = $finalBytes
        free_bytes_before = $freeBytes
        files = @($results)
        safetensors = $safetensors
    }
    [System.IO.File]::WriteAllText($ValidatedManifestPath, ($manifest | ConvertTo-Json -Depth 12) + "`n", $Utf8NoBom)
    $manifestHash = (Get-FileHash -LiteralPath $ValidatedManifestPath -Algorithm SHA256).Hash
    Write-Event 'promotion_authorized' @{
        validated_manifest_path = $ValidatedManifestPath
        validated_manifest_sha256 = $manifestHash
        planned_final_root = $FinalRoot
    }

    $finalParent = Split-Path -Parent $FinalRoot
    New-Item -ItemType Directory -Path $finalParent -Force | Out-Null
    Assert-NoReparseComponent $finalParent
    if (Test-Path -LiteralPath $FinalRoot) {
        throw "Final source directory appeared before promotion; refusing to merge or overwrite: $FinalRoot"
    }
    Move-Item -LiteralPath $VerifiedRoot -Destination $FinalRoot
    Assert-NoReparseComponent $FinalRoot

    $finished = (Get-Date).ToUniversalTime().ToString('o')
    $freeAfter = [int64](Get-PSDrive -Name F).Free
    $finalItems = @(Get-ChildItem -LiteralPath $FinalRoot -Force)
    $finalNames = @($finalItems | Sort-Object Name | ForEach-Object Name)
    if (($finalNames -join "`n") -ne ($expectedNames -join "`n")) {
        throw 'Promoted final directory membership differs from the frozen allowlist.'
    }
    foreach ($item in $finalItems) {
        if ($item.PSIsContainer -or (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw "Non-plain member in promoted final directory: $($item.FullName)"
        }
    }
    $receipt = [ordered]@{
        schema_version = '1.0.0'
        status = 'complete-and-promoted'
        attempt_id = $AttemptId
        finished_utc = $finished
        revision = $Revision
        script_sha256 = $scriptHash
        allowlist_sha256 = $allowlistHash
        validated_manifest_path = $ValidatedManifestPath
        validated_manifest_sha256 = $manifestHash
        final_root = $FinalRoot
        selected_file_count = $results.Count
        selected_total_bytes = $finalBytes
        free_bytes_after = $freeAfter
        final_names = $finalNames
    }
    [System.IO.File]::WriteAllText($PromotionReceiptPath, ($receipt | ConvertTo-Json -Depth 6) + "`n", $Utf8NoBom)
    $receiptHash = (Get-FileHash -LiteralPath $PromotionReceiptPath -Algorithm SHA256).Hash
    Write-Event 'retrieval_completed' @{
        finished_utc = $finished
        final_root = $FinalRoot
        selected_file_count = $results.Count
        selected_total_bytes = $finalBytes
        validated_manifest_path = $ValidatedManifestPath
        validated_manifest_sha256 = $manifestHash
        promotion_receipt_path = $PromotionReceiptPath
        promotion_receipt_sha256 = $receiptHash
        free_bytes_after = $freeAfter
    }

    Write-Output "retrieval_finished_utc=$finished"
    Write-Output "selected_file_count=$($results.Count)"
    Write-Output "selected_total_bytes=$finalBytes"
    Write-Output "validated_manifest_path=$ValidatedManifestPath"
    Write-Output "validated_manifest_sha256=$manifestHash"
    Write-Output "promotion_receipt_path=$PromotionReceiptPath"
    Write-Output "promotion_receipt_sha256=$receiptHash"
    Write-Output "free_bytes_after=$freeAfter"
}
catch {
    try {
        Write-Event 'retrieval_failed' @{
            error_type = $_.Exception.GetType().FullName
            error_message = $_.Exception.Message
            final_root_exists = (Test-Path -LiteralPath $FinalRoot)
            validated_manifest_exists = (Test-Path -LiteralPath $ValidatedManifestPath)
        }
    }
    catch {
        Write-Warning "Failed to append retrieval failure event: $($_.Exception.Message)"
    }
    throw
}
finally {
    if ($null -ne $lockStream) {
        $lockStream.Dispose()
    }
}
