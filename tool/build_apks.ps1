param(
    [switch]$Debug
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

function Invoke-FlutterBuild {
    param([string[]]$FlutterArgs, [string]$Label)
    Write-Host "`n=== $Label ===" -ForegroundColor Cyan
    & flutter build apk @FlutterArgs
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build apk $($FlutterArgs -join ' ') failed (exit $LASTEXITCODE)"
    }
}
Invoke-FlutterBuild -FlutterArgs @('--release', '--split-per-abi') -Label 'Per-ABI release APKs'
Invoke-FlutterBuild -FlutterArgs @('--release') -Label 'Universal release APK'

if ($Debug) {
    Invoke-FlutterBuild -FlutterArgs @('--debug') -Label 'Debug APK'
}
Write-Host "`n=== Verification ===" -ForegroundColor Cyan

$aapt2 = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Recurse -Filter aapt2.exe -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
if (-not $aapt2) {
    Write-Warning 'aapt2 not found; skipping resource verification.'
}
Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkDir = Join-Path $repo 'build/app/outputs/flutter-apk'
$failed = @()

Get-ChildItem "$apkDir/*.apk" | Sort-Object Name | ForEach-Object {
    $hasIcon = $true
    if ($aapt2) {
        $dump = & $aapt2.FullName dump resources $_.FullName 2>&1
        $hasIcon = ($dump | Select-String -Pattern 'drawable/ic_stat_nudgr$' | Measure-Object).Count -gt 0
    }
    $zip = [System.IO.Compression.ZipFile]::OpenRead($_.FullName)
    $abis = ($zip.Entries |
        Where-Object { $_.FullName -match '^lib/([^/]+)/' } |
        ForEach-Object { ($_.FullName -split '/')[1] } |
        Sort-Object -Unique) -join ', '
    $zip.Dispose()
    if (-not $hasIcon -and $_.Name -notlike '*debug*') { $failed += $_.Name }
    [pscustomobject]@{
        APK       = $_.Name
        MB        = [math]::Round($_.Length / 1MB, 1)
        Built     = $_.LastWriteTime.ToString('HH:mm:ss')
        BrandIcon = if ($hasIcon) { 'yes' } else { 'NO' }
        ABIs      = $abis
    }
} | Format-Table -AutoSize

if ($failed.Count -gt 0) {
    throw "Notification brand icon missing from: $($failed -join ', ')"
}
Write-Host 'All APK variants built and verified.' -ForegroundColor Green
