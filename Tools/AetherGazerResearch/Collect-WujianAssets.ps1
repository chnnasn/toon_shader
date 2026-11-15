[CmdletBinding()]
param(
    [string]$ExportedAssets = (Join-Path $PSScriptRoot 'AssetRipperExport\ExportedProject\Assets'),
    [string]$Destination = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Assets\Studies\BrahmaWujianStudy\SourceArt')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ExportedAssets -PathType Container)) {
    throw "AssetRipper export folder was not found: $ExportedAssets"
}

$seedPatterns = @(
    '*\char\102003ui_tpose.ys\*\102003ui_tpose.prefab',
    '*\char\102003ui_tpose$naive.ys\*\102003ui_tpose$naive.prefab'
)

$allMeta = Get-ChildItem -LiteralPath $ExportedAssets -Recurse -File -Filter '*.meta'
$guidToAsset = @{}
foreach ($meta in $allMeta) {
    $guidLine = Select-String -LiteralPath $meta.FullName -Pattern '^guid:\s*([0-9a-f]{32})$' | Select-Object -First 1
    if ($guidLine) {
        $assetPath = $meta.FullName.Substring(0, $meta.FullName.Length - 5)
        $guidToAsset[$guidLine.Matches[0].Groups[1].Value] = $assetPath
    }
}

$allAssets = Get-ChildItem -LiteralPath $ExportedAssets -Recurse -File |
    Where-Object { $_.Extension -ne '.meta' }

$seeds = @()
foreach ($pattern in $seedPatterns) {
    $matches = $allAssets | Where-Object { $_.FullName -like $pattern }
    if (-not $matches) {
        throw "Required seed was not found: $pattern"
    }
    $seeds += $matches.FullName
}

$queue = [System.Collections.Generic.Queue[string]]::new()
$visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$blocked = [System.Collections.Generic.List[object]]::new()
$unresolved = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($seed in $seeds) { $queue.Enqueue($seed) }

while ($queue.Count -gt 0) {
    $asset = $queue.Dequeue()
    if (-not $visited.Add($asset)) { continue }

    $relative = [System.IO.Path]::GetRelativePath($ExportedAssets, $asset)
    if ($relative -match '(?i)(^|\\)weapon(\\|$)' -or [System.IO.Path]::GetFileName($asset) -match '(?i)weapon') {
        [void]$visited.Remove($asset)
        $blocked.Add([pscustomobject]@{ Path = $relative; Reason = 'weapon-path-or-name' })
        continue
    }

    $extension = [System.IO.Path]::GetExtension($asset).ToLowerInvariant()
    if ($extension -notin @('.prefab', '.asset', '.mat', '.controller', '.anim', '.shader', '.shadergraph', '.playable')) {
        continue
    }

    $content = Get-Content -LiteralPath $asset -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    foreach ($match in [regex]::Matches($content, 'guid:\s*([0-9a-f]{32})')) {
        $guid = $match.Groups[1].Value
        if ($guid -match '^0+$' -or $guid -like '*deadbeef*') { continue }
        if ($guidToAsset.ContainsKey($guid)) {
            $queue.Enqueue($guidToAsset[$guid])
        } else {
            [void]$unresolved.Add($guid)
        }
    }
}

New-Item -ItemType Directory -Path $Destination -Force | Out-Null

$copied = [System.Collections.Generic.List[object]]::new()
foreach ($asset in ($visited | Sort-Object)) {
    $relative = [System.IO.Path]::GetRelativePath($ExportedAssets, $asset)
    $target = Join-Path $Destination $relative
    $targetFolder = Split-Path -Parent $target
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
    Copy-Item -LiteralPath $asset -Destination $target -Force

    $meta = "$asset.meta"
    if (Test-Path -LiteralPath $meta) {
        Copy-Item -LiteralPath $meta -Destination "$target.meta" -Force
    }

    $copied.Add([pscustomobject]@{
        Path = $relative
        Bytes = (Get-Item -LiteralPath $asset).Length
        Sha256 = (Get-FileHash -LiteralPath $asset -Algorithm SHA256).Hash.ToLowerInvariant()
    })
}

$report = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    source = $ExportedAssets
    destination = $Destination
    seeds = @($seeds | ForEach-Object { [System.IO.Path]::GetRelativePath($ExportedAssets, $_) })
    copiedAssetCount = $copied.Count
    copiedBytes = ($copied | Measure-Object -Property Bytes -Sum).Sum
    weaponAssetCount = @($copied | Where-Object { $_.Path -match '(?i)(^|\\)weapon(\\|$)|weapon' }).Count
    blocked = @($blocked)
    unresolvedGuids = @($unresolved | Sort-Object)
    files = @($copied)
}

$reportPath = Join-Path $Destination 'wujian-asset-manifest.json'
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding utf8

if ($report.weaponAssetCount -ne 0) {
    throw "Weapon exclusion invariant failed. See $reportPath"
}

$report | Select-Object generatedUtc, copiedAssetCount, copiedBytes, weaponAssetCount, @{n='blockedCount';e={$_.blocked.Count}}, @{n='unresolvedGuidCount';e={$_.unresolvedGuids.Count}}
