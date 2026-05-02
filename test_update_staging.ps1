# test_update_staging.ps1
#
# Stages a fake pending update so you can test the "Restart Now to Update"
# flow without uploading anything to GitHub.
#
# Usage:
#   .\test_update_staging.ps1              # auto-detects MyMeta.exe
#   .\test_update_staging.ps1 -Launch     # also launches the script immediately (no app needed)
#
# The -Launch flag tests the exact same mechanism the app uses:
#   cmd /c start /b powershell.exe -NonInteractive -EncodedCommand <base64>
# This lets you verify the update script runs and the app relaunches
# without having to open MyMeta and click the button.

param(
    [string]$AppDir = "",
    [string]$FakeVersion = "99.0.0",
    [switch]$Launch
)

$ExeName = "MyMeta.exe"

# Auto-detect: script's own folder → Release build output → error
if ($AppDir -eq "") {
    $candidates = @(
        $PSScriptRoot,
        (Join-Path $PSScriptRoot "build\windows\x64\runner\Release")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate $ExeName)) {
            $AppDir = $candidate
            break
        }
    }
}

if ($AppDir -eq "" -or -not (Test-Path (Join-Path $AppDir $ExeName))) {
    Write-Error "Could not find $ExeName. Build first with: flutter build windows --release"
    exit 1
}

$AppDir = Resolve-Path $AppDir
Write-Host "Found $ExeName in: $AppDir"

$UpdatesDir   = Join-Path $AppDir "UserData\Updates"
$ExtractedDir = Join-Path $UpdatesDir "extracted"
$ScriptPath   = Join-Path $UpdatesDir "update_mymeta.ps1"
$LogPath      = Join-Path $UpdatesDir "update_mymeta.log"
$PendingPath  = Join-Path $UpdatesDir "pending.json"
$ProcessName  = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)

# ── Clean up any previous test run ───────────────────────────────────────────
if (Test-Path $UpdatesDir) {
    Remove-Item $UpdatesDir -Recurse -Force
    Write-Host "Cleaned up previous staging."
}
New-Item -ItemType Directory -Path $ExtractedDir -Force | Out-Null

# ── Copy current app files into extracted/ (this is the "new" version) ───────
Write-Host "Copying app files to extracted/ ..."
& robocopy $AppDir $ExtractedDir /E /XD UserData /NP /NFL /NDL | Out-Null
if ($LASTEXITCODE -ge 8) {
    Write-Error "robocopy failed (exit $LASTEXITCODE)"
    exit 1
}
Write-Host "  Done."

# ── Write the update script (mirrors what _createUpdateScript generates) ─────
@"
function Log(`$msg) {
    "[(`$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))] `$msg" |
        Out-File -Append -Encoding utf8 -FilePath '$LogPath'
}

Log "=== MyMeta Update Started ==="
Log "Source : $ExtractedDir"
Log "Target : $AppDir"

Log "Waiting for $ProcessName to exit..."
Start-Sleep -Seconds 2
`$waited = 0
while (Get-Process -Name '$ProcessName' -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 1
    `$waited++
    if (`$waited -ge 60) {
        Log "WARNING: Timeout after `$waited s, proceeding anyway"
        break
    }
}
Log "Process gone after `$waited s"

Log "Copying files..."
`$out = & robocopy '$ExtractedDir' '$AppDir' /E /XD UserData /R:5 /W:2 /NP 2>&1
`$rc  = `$LASTEXITCODE
`$out | Out-File -Append -Encoding utf8 -FilePath '$LogPath'
Log "Robocopy exit code: `$rc"

if (`$rc -ge 8) {
    Log "ERROR: File copy failed — aborting"
    exit 1
}

Log "Restarting app..."
Start-Sleep -Seconds 1
Start-Process -FilePath '$AppDir\$ExeName' -WorkingDirectory '$AppDir'
Log "=== Update Complete ==="
"@ | Out-File -Encoding utf8 -FilePath $ScriptPath

# ── Write pending.json ────────────────────────────────────────────────────────
@{ version = $FakeVersion; scriptPath = $ScriptPath } |
    ConvertTo-Json |
    Out-File -Encoding utf8 -FilePath $PendingPath

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Staging complete!"
Write-Host "  App dir      : $AppDir"
Write-Host "  Fake version : $FakeVersion"
Write-Host "  Script       : $ScriptPath"
Write-Host "  Log (after)  : $LogPath"
Write-Host ""

if ($Launch) {
    # ── Test the exact launch mechanism the app uses ──────────────────────────
    Write-Host "Launching update script via cmd /c start /b (same as the app does)..."
    $scriptContent = Get-Content $ScriptPath -Raw -Encoding utf8
    $utf16leBytes  = [System.Text.Encoding]::Unicode.GetBytes($scriptContent)
    $encoded       = [Convert]::ToBase64String($utf16leBytes)
    Start-Process cmd.exe -ArgumentList "/c", "start", "/b", "powershell.exe", "-NonInteractive", "-EncodedCommand", $encoded
    Write-Host ""
    Write-Host "Script launched. MyMeta should reopen in a few seconds."
    Write-Host "Check the log for details:"
    Write-Host "  $LogPath"
} else {
    Write-Host "Next steps:"
    Write-Host "  1. Launch MyMeta.exe — the 'Restart Now to Update' banner should appear."
    Write-Host "  2. Click the button. The app will close and reopen automatically."
    Write-Host "  3. If it doesn't reopen, check the log at:"
    Write-Host "     $LogPath"
    Write-Host ""
    Write-Host "Or skip the app entirely and test the launch mechanism directly:"
    Write-Host "  .\test_update_staging.ps1 -Launch"
}
