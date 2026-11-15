[CmdletBinding()]
param(
    [string]$ExportRoot = (Join-Path $PSScriptRoot 'OriginalShaderExport\ExportedProject\Assets'),
    [string]$OutputRoot = (Join-Path $PSScriptRoot 'OriginalShaderEvidence')
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $ExportRoot -PathType Container)) {
    throw "Shader export was not found: $ExportRoot"
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$guidMap = @{}
foreach ($meta in Get-ChildItem -LiteralPath $ExportRoot -Recurse -File -Filter '*.meta') {
    $line = Select-String -LiteralPath $meta.FullName -Pattern '^guid:\s*([0-9a-f]{32})$' | Select-Object -First 1
    if ($line) {
        $guidMap[$line.Matches[0].Groups[1].Value] = $meta.FullName.Substring(0, $meta.FullName.Length - 5)
    }
}

$materials = Get-ChildItem -LiteralPath $ExportRoot -Recurse -File -Filter '*.mat' |
    Where-Object {
        ($_.FullName -match '(?i)102003ui|prop\\1020\\102003') -and
        ($_.FullName -notmatch '(?i)(^|\\)weapon(\\|$)')
    }

$records = [System.Collections.Generic.List[object]]::new()
$shaderPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($material in $materials) {
    $shaderLine = Select-String -LiteralPath $material.FullName -Pattern 'm_Shader:.*guid:\s*([0-9a-f]{32})' | Select-Object -First 1
    if (-not $shaderLine) { continue }
    $guid = $shaderLine.Matches[0].Groups[1].Value
    $shaderPath = if ($guidMap.ContainsKey($guid)) { $guidMap[$guid] } else { $null }
    if ($shaderPath) { [void]$shaderPaths.Add($shaderPath) }
    $records.Add([pscustomobject]@{
        material = [IO.Path]::GetRelativePath($ExportRoot, $material.FullName)
        shaderGuid = $guid
        shader = if ($shaderPath) { [IO.Path]::GetRelativePath($ExportRoot, $shaderPath) } else { $null }
    })
}

$copied = [System.Collections.Generic.List[object]]::new()
foreach ($shader in $shaderPaths) {
    $relative = [IO.Path]::GetRelativePath($ExportRoot, $shader)
    $target = Join-Path $OutputRoot (Join-Path 'SerializedShaders' $relative)
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath $shader -Destination $target -Force
    if (Test-Path -LiteralPath "$shader.meta") {
        Copy-Item -LiteralPath "$shader.meta" -Destination "$target.meta" -Force
    }
    $copied.Add([pscustomobject]@{
        path = [IO.Path]::GetRelativePath($OutputRoot, $target)
        bytes = (Get-Item -LiteralPath $target).Length
        sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    })
}

foreach ($bundleName in @('comchar__shader.ys', 'shader.ys', 'shaderextracollect_comchar.ys', 'allshaders.ys')) {
    $bundle = Join-Path (Join-Path $PSScriptRoot 'Input') $bundleName
    if (-not (Test-Path -LiteralPath $bundle)) { continue }
    $target = Join-Path $OutputRoot (Join-Path 'RawBundles' $bundleName)
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath $bundle -Destination $target -Force
    $copied.Add([pscustomobject]@{
        path = [IO.Path]::GetRelativePath($OutputRoot, $target)
        bytes = (Get-Item -LiteralPath $target).Length
        sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    })
}

$variant = Get-ChildItem -LiteralPath $ExportRoot -Recurse -File -Filter '*.shadervariants' | Select-Object -First 1
if ($variant) {
    $target = Join-Path $OutputRoot (Join-Path 'Variants' $variant.Name)
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath $variant.FullName -Destination $target -Force
    if (Test-Path -LiteralPath "$($variant.FullName).meta") {
        Copy-Item -LiteralPath "$($variant.FullName).meta" -Destination "$target.meta" -Force
    }
}

$manifest = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    note = 'Unity player builds contain serialized/compiled shader data, not the original authoring source. These files preserve the recoverable property, pass, render-state, keyword and compiled subprogram evidence.'
    weaponAssetCount = @($records | Where-Object { $_.material -match '(?i)weapon' }).Count
    materials = @($records | Sort-Object material)
    evidenceFiles = @($copied | Sort-Object path)
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $OutputRoot 'original-shader-manifest.json') -Encoding utf8
if ($manifest.weaponAssetCount -ne 0) { throw 'Weapon shader evidence was unexpectedly selected.' }

[pscustomobject]@{
    materialCount = $records.Count
    shaderCount = $shaderPaths.Count
    evidenceFileCount = $copied.Count
    weaponAssetCount = $manifest.weaponAssetCount
}
