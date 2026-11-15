param(
    [string]$GameRoot = 'D:\AetherGazerLauncher\AetherGazer\AetherGazer_Data\StreamingAssets\Windows',
    [string]$OutputRoot = (Join-Path $PSScriptRoot 'Input')
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $GameRoot 'AssetHash_Info.bytes'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Asset manifest not found: $manifestPath"
}

$wanted = @(
    '^allshaders\.ys$',
    '^comchar/assets/comchar/artresources/char/hero/1085\.ys$',
    '^comchar/char/108502.*\.ys$',
    '^comchar/t0world/model/108502/.*\.ys$',
    '^comchar/weapon/108502ui_weapon\.ys$',
    '^comchar/assets/comchar/artresources/weapon/108502/.*\.ys$',
    '^comchar/assets/comchar/artresources/prop/1085/108502/.*\.ys$',
    '^comchar/assets/comchar/artresources/prop/dlc/models/ch_(arm|bat)_108502\.ys$'
)

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$entries = foreach ($raw in $manifest.assetHashList) {
    $parts = $raw -split '\|'
    if ($parts.Count -lt 3) { continue }
    $logicalPath = $parts[0]
    if ($wanted.Where({ $logicalPath -match $_ }, 'First').Count -eq 0) { continue }
    [pscustomobject]@{
        LogicalPath = $logicalPath
        Hash = $parts[1]
        DeclaredSize = [int64]$parts[2]
    }
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$records = foreach ($entry in $entries) {
    $hash = $entry.Hash
    $source = Join-Path $GameRoot (Join-Path $hash.Substring(0, 1) (Join-Path $hash.Substring(1, 1) "$hash.ys"))
    if (-not (Test-Path -LiteralPath $source)) {
        Write-Warning "Missing source bundle for $($entry.LogicalPath): $source"
        continue
    }

    $safeName = ($entry.LogicalPath -replace '[/\\:$]', '__')
    $destination = Join-Path $OutputRoot $safeName
    $input = [IO.File]::OpenRead($source)
    try {
        $probe = New-Object byte[] 128
        $read = $input.Read($probe, 0, $probe.Length)
        $signature = [Text.Encoding]::ASCII.GetBytes('UnityFS')
        $offset = -1
        for ($i = 0; $i -le $read - $signature.Length; $i++) {
            $match = $true
            for ($j = 0; $j -lt $signature.Length; $j++) {
                if ($probe[$i + $j] -ne $signature[$j]) { $match = $false; break }
            }
            if ($match) { $offset = $i; break }
        }
        if ($offset -lt 0) {
            Write-Warning "UnityFS signature not found in first 128 bytes: $source"
            continue
        }

        $input.Position = $offset
        $output = [IO.File]::Open($destination, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $input.CopyTo($output) } finally { $output.Dispose() }

        [pscustomobject]@{
            LogicalPath = $entry.LogicalPath
            Hash = $hash
            SourcePath = $source
            OutputPath = $destination
            RemovedPrefixBytes = $offset
            DeclaredSize = $entry.DeclaredSize
            OutputSize = (Get-Item -LiteralPath $destination).Length
        }
    }
    finally {
        $input.Dispose()
    }
}

$records | Sort-Object LogicalPath | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'bundle-manifest.json') -Encoding utf8
$records | Sort-Object LogicalPath | Export-Csv -LiteralPath (Join-Path $PSScriptRoot 'bundle-manifest.csv') -NoTypeInformation -Encoding utf8
$records | Sort-Object LogicalPath | Format-Table LogicalPath, RemovedPrefixBytes, OutputSize -AutoSize
