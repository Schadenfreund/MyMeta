# test_update_staging.ps1
#
# Three modes for testing the update flow without releasing to GitHub:
#
#   .\test_update_staging.ps1 -Automated    # full end-to-end, asserts, cleans up
#   .\test_update_staging.ps1 -Launch       # fires the production launch chain (no app)
#   .\test_update_staging.ps1               # just stages files; user drives the app
#
# Other knobs:
#   -AppDir <path>          Override auto-detection of MyMeta.exe
#   -FakeVersion <v>        Version stamped into pending.json (default 99.0.0).
#                           Ignored in -Automated.
#
# Both -Launch and -Automated mirror the launch chain produced by
# `WindowsInstaller.launchScript()` in lib/services/update_installer.dart.
# Keep the two in sync when either changes.

param(
    [string]$AppDir      = "",
    [string]$FakeVersion = "99.0.0",
    [switch]$Launch,
    [switch]$Automated
)

$ErrorActionPreference = 'Stop'
$ExeName = "MyMeta.exe"

# ── Locate MyMeta.exe ────────────────────────────────────────────────────────
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

$AppDir       = (Resolve-Path $AppDir).Path
$UpdatesDir   = Join-Path $AppDir "UserData\Updates"
$ExtractedDir = Join-Path $UpdatesDir "extracted"
$ScriptPath   = Join-Path $UpdatesDir "update_mymeta.ps1"
$LogPath      = Join-Path $UpdatesDir "update_mymeta.log"
$PendingPath  = Join-Path $UpdatesDir "pending.json"
$ProcessName  = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)

# =============================================================================
# Shared: stage a fake update (extracted/, .ps1, pending.json)
# =============================================================================
function New-StagedUpdate {
    param(
        [int]   $WaitForPid,
        [string]$Version,
        [string]$InjectMarkerFile = ""
    )

    if (Test-Path $UpdatesDir) {
        Remove-Item $UpdatesDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $ExtractedDir -Force | Out-Null

    & robocopy $AppDir $ExtractedDir /E /XD UserData /NP /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed (exit $LASTEXITCODE)"
    }

    # Optionally inject a unique file into the "new" release so the test can
    # prove robocopy actually ran — its presence in $AppDir after install is
    # only possible via the install script copying it there.
    if ($InjectMarkerFile -ne "") {
        $marker = Join-Path $ExtractedDir $InjectMarkerFile
        "automated-test marker $(Get-Date -Format o)" | Out-File -Encoding utf8 -FilePath $marker
    }

    # The PowerShell template here must match WindowsInstaller.createScript().
    @"
`$ErrorActionPreference = 'Stop'

function Log(`$msg) {
    "[`$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] `$msg" |
        Out-File -Append -Encoding utf8 -FilePath '$LogPath'
}

try {
    Log "=== MyMeta Update Started (PID $WaitForPid) ==="
    Log "Source: $ExtractedDir"
    Log "Target: $AppDir"

    try {
        Wait-Process -Id $WaitForPid -Timeout 60 -ErrorAction Stop
        Log "Process $WaitForPid exited."
    } catch [System.TimeoutException] {
        Log "WARNING: Timed out after 60s waiting for PID $WaitForPid; proceeding."
    } catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
        Log "Process $WaitForPid was already gone."
    }
    Start-Sleep -Milliseconds 500

    Log "Copying files..."
    `$output = & robocopy '$ExtractedDir' '$AppDir' /E /XD UserData /R:5 /W:2 /NP /NJH /NJS 2>&1
    `$rc = `$LASTEXITCODE
    `$output | Out-File -Append -Encoding utf8 -FilePath '$LogPath'
    Log "Robocopy exit code: `$rc"

    if (`$rc -ge 8) {
        Log "ERROR: File copy failed (robocopy exit `$rc)"
        exit 1
    }

    Log "Restarting app..."
    Start-Sleep -Seconds 1
    Start-Process -FilePath '$AppDir\$ExeName' -WorkingDirectory '$AppDir'
    Log "=== Update Complete ==="
} catch {
    Log "FATAL: `$(`$_.Exception.Message)"
    Log `$_.ScriptStackTrace
    exit 1
}
"@ | Out-File -Encoding utf8 -FilePath $ScriptPath

    @{
        version    = $Version
        scriptPath = $ScriptPath
        stagedAt   = (Get-Date).ToString("o")
    } | ConvertTo-Json | Out-File -Encoding utf8 -FilePath $PendingPath
}

# =============================================================================
# Shared: fire the production launch chain (matches WindowsInstaller.launchScript)
# =============================================================================
# PowerShell's `Start-Process -ArgumentList @(...)` joins elements with spaces
# but does NOT auto-quote elements that themselves contain spaces — so a path
# like `C:\Users\Foo\My Drive\...\update.ps1` would be parsed by powershell.exe
# as `-File C:\Users\Foo\My` followed by stray tokens, and the script never
# runs. Build the argument string by hand with explicit quotes instead.
#
# Dart's `Process.start(args: [...])` on Windows handles this automatically
# via the MSVC quoting rules, which is why the production launch in
# `WindowsInstaller.launchScript()` does not need this treatment.
function Invoke-InstallScript {
    $cmdArgs = '/c start "" /b ' +
               'powershell.exe ' +
               '-ExecutionPolicy Bypass ' +
               '-WindowStyle Hidden ' +
               '-NonInteractive ' +
               '-NoProfile ' +
               '-File "' + $ScriptPath + '"'

    if ($script:VerbosePreference -eq 'Continue' -or $Automated) {
        Write-Host "  cmd.exe $cmdArgs" -ForegroundColor DarkGray
    }

    Start-Process -FilePath cmd.exe -ArgumentList $cmdArgs -WindowStyle Hidden
}

# =============================================================================
# AUTOMATED MODE
# =============================================================================
if ($Automated) {
    # Test runner state
    $TestLogPath  = Join-Path $PSScriptRoot "test_update_log.txt"
    $script:Results = @()
    $script:StartTime = Get-Date

    function Write-TestLog {
        param([string]$Line, [string]$Color = "Gray")
        $stamp = (Get-Date).ToString("HH:mm:ss.fff")
        "$stamp  $Line" | Out-File -Append -Encoding utf8 -FilePath $TestLogPath
        Write-Host $Line -ForegroundColor $Color
    }

    function Test-Assert {
        param([string]$Name, [bool]$Condition, [string]$Detail = "")
        if ($Condition) {
            $script:Results += [pscustomobject]@{ Name = $Name; Passed = $true; Detail = "" }
            Write-TestLog "  PASS  $Name" "Green"
        } else {
            $script:Results += [pscustomobject]@{ Name = $Name; Passed = $false; Detail = $Detail }
            Write-TestLog "  FAIL  $Name  -  $Detail" "Red"
        }
    }

    function Wait-ForLogPattern {
        param([string]$Path, [string]$Pattern, [int]$TimeoutSec)
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        while ((Get-Date) -lt $deadline) {
            if (Test-Path $Path) {
                $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
                if ($content -and $content.Contains($Pattern)) { return $true }
            }
            Start-Sleep -Milliseconds 200
        }
        return $false
    }

    function Wait-ForProcess {
        param([string]$Name, [int]$TimeoutSec)
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        while ((Get-Date) -lt $deadline) {
            if (Get-Process -Name $Name -ErrorAction SilentlyContinue) { return $true }
            Start-Sleep -Milliseconds 200
        }
        return $false
    }

    # Sentinel that lives in UserData/ — must survive the install. Its
    # presence after install proves /XD UserData worked.
    $SentinelInUserData = Join-Path $AppDir "UserData\AUTOMATED_TEST_SHOULD_SURVIVE.txt"

    # Marker we inject into the staged "new release". Its presence in
    # $AppDir after install proves robocopy actually executed the copy.
    $MarkerFileName        = "AUTOMATED_TEST_UPDATED_MARKER.txt"
    $MarkerInAppDir        = Join-Path $AppDir $MarkerFileName

    # Reset the per-run test log
    Remove-Item $TestLogPath -ErrorAction SilentlyContinue

    Write-TestLog ""
    Write-TestLog "=== MyMeta Update Test Runner ===" "Cyan"
    Write-TestLog "Target:  $AppDir"
    Write-TestLog "Log:     $TestLogPath"
    Write-TestLog "Started: $($script:StartTime.ToString('o'))"
    Write-TestLog ""

    try {
        # ── [1/5] Pre-flight ──────────────────────────────────────────────
        Write-TestLog "[1/5] Pre-flight" "Cyan"

        $existing = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-TestLog "  Stopping existing $ProcessName process(es) ($($existing.Count))..."
            Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        Test-Assert "No $ProcessName running before test" `
            (-not (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue))

        if (Test-Path $UpdatesDir) {
            Remove-Item $UpdatesDir -Recurse -Force
        }
        Test-Assert "Clean staging directory" (-not (Test-Path $UpdatesDir))

        Remove-Item $SentinelInUserData -ErrorAction SilentlyContinue
        Remove-Item $MarkerInAppDir     -ErrorAction SilentlyContinue
        Write-TestLog ""

        # ── [2/5] Plant sentinels ─────────────────────────────────────────
        Write-TestLog "[2/5] Plant sentinels" "Cyan"

        New-Item -ItemType Directory -Force -Path (Split-Path $SentinelInUserData) | Out-Null
        "do not delete me $(Get-Date -Format o)" | Out-File -Encoding utf8 -FilePath $SentinelInUserData
        Test-Assert "Sentinel planted in UserData/" (Test-Path $SentinelInUserData)
        Write-TestLog ""

        # ── [3/5] Stage update ────────────────────────────────────────────
        Write-TestLog "[3/5] Stage update" "Cyan"

        # PID 999999 is a never-existing process. The install script's
        # Wait-Process will throw ProcessCommandException immediately,
        # the catch block logs "was already gone", and the install proceeds
        # without a 60-second hang.
        New-StagedUpdate -WaitForPid 999999 -Version "99.0.0" `
                         -InjectMarkerFile $MarkerFileName

        Test-Assert "extracted/ created"                (Test-Path $ExtractedDir)
        Test-Assert "extracted/$MarkerFileName injected" (Test-Path (Join-Path $ExtractedDir $MarkerFileName))
        Test-Assert "update_mymeta.ps1 written"          (Test-Path $ScriptPath)
        Test-Assert "pending.json written"               (Test-Path $PendingPath)
        Write-TestLog ""

        # ── [4/5] Fire launch chain ───────────────────────────────────────
        Write-TestLog "[4/5] Fire launch chain (watch for visible windows...)" "Cyan"
        Invoke-InstallScript

        # First milestone: did the script even start? If the log file is still
        # missing after 5 seconds, PowerShell never ran (e.g. unquoted path,
        # execution policy, broken -File path). Distinguish that from "script
        # ran but didn't reach the end" so the failure message is actionable.
        $stepStart = Get-Date
        $logStartOk = Wait-ForLogPattern -Path $LogPath -Pattern "Update Started" -TimeoutSec 5
        $logStartElapsed = ((Get-Date) - $stepStart).TotalSeconds
        $startDetail = if ($logStartOk) {
            "first log line in $($logStartElapsed.ToString('F1'))s"
        } else {
            ("waited $($logStartElapsed.ToString('F1'))s, no log appeared at $LogPath — " +
             "most likely PowerShell didn't launch. Check the cmd.exe command line " +
             "printed above this step.")
        }
        Test-Assert "Install script began executing (within 5s)" $logStartOk $startDetail

        if (-not $logStartOk) {
            # No point waiting another 30s for a completion line that will
            # never arrive. Skip ahead to verification, which will catch the
            # rest of the cascade.
            Test-Assert "Install log reports 'Update Complete' (skipped)" $false `
                "skipped because the script never started"
            Test-Assert "$ProcessName relaunched (skipped)" $false `
                "skipped because the script never started"
        } else {
            $stepStart = Get-Date
            $logOk = Wait-ForLogPattern -Path $LogPath -Pattern "=== Update Complete ===" -TimeoutSec 30
            $logElapsed = ((Get-Date) - $stepStart).TotalSeconds
            Test-Assert "Install log reports 'Update Complete' (within 30s)" $logOk `
                ("waited $($logElapsed.ToString('F1'))s — log path: $LogPath")

            $stepStart = Get-Date
            $procOk = Wait-ForProcess -Name $ProcessName -TimeoutSec 10
            $procElapsed = ((Get-Date) - $stepStart).TotalSeconds
            Test-Assert "$ProcessName relaunched (within 10s)" $procOk `
                ("waited $($procElapsed.ToString('F1'))s")
        }

        $stepStart = Get-Date
        $procOk = Wait-ForProcess -Name $ProcessName -TimeoutSec 10
        $procElapsed = ((Get-Date) - $stepStart).TotalSeconds
        Test-Assert "$ProcessName relaunched (within 10s)" `
            $procOk ("waited $($procElapsed.ToString('F1'))s")
        Write-TestLog ""

        # ── [5/5] Verify outcomes ─────────────────────────────────────────
        Write-TestLog "[5/5] Verify outcomes" "Cyan"

        $logContent = if (Test-Path $LogPath) { Get-Content $LogPath -Raw } else { "" }

        $robocopyMatch = [regex]::Match($logContent, 'Robocopy exit code:\s*(\d+)')
        $robocopyOk = $false
        if ($robocopyMatch.Success) {
            $rc = [int]$robocopyMatch.Groups[1].Value
            $robocopyOk = ($rc -lt 8)
            Test-Assert "Robocopy exit code < 8" $robocopyOk "exit code: $rc"
        } else {
            Test-Assert "Robocopy exit code recorded" $false "no 'Robocopy exit code: N' line in log"
        }

        Test-Assert "Marker copied into app dir (proves robocopy ran)" `
            (Test-Path $MarkerInAppDir) `
            "expected: $MarkerInAppDir"

        Test-Assert "Sentinel survived in UserData/ (proves /XD worked)" `
            (Test-Path $SentinelInUserData) `
            "expected: $SentinelInUserData"

        Test-Assert "No 'FATAL' in install log" `
            (-not ($logContent -match 'FATAL:')) `
            "log contains a FATAL line"

        # Capture the install log into the test log for the record
        Write-TestLog ""
        Write-TestLog "--- install log -----------------------------------------------" "DarkGray"
        if (Test-Path $LogPath) {
            Get-Content $LogPath | ForEach-Object { Write-TestLog "  $_" "DarkGray" }
        }
        Write-TestLog "---------------------------------------------------------------" "DarkGray"
        Write-TestLog ""
    }
    finally {
        # ── Cleanup (always runs, even on failure) ────────────────────────
        Write-TestLog "[Cleanup]" "Cyan"
        if (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) {
            Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
            Write-TestLog "  Stopped $ProcessName"
        }
        if (Test-Path $UpdatesDir) {
            Remove-Item $UpdatesDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-TestLog "  Removed UserData\Updates\"
        }
        if (Test-Path $MarkerInAppDir) {
            Remove-Item $MarkerInAppDir -Force -ErrorAction SilentlyContinue
            Write-TestLog "  Removed $MarkerFileName from app dir"
        }
        if (Test-Path $SentinelInUserData) {
            Remove-Item $SentinelInUserData -Force -ErrorAction SilentlyContinue
            Write-TestLog "  Removed sentinel from UserData\"
        }
        Write-TestLog ""

        # ── Summary ───────────────────────────────────────────────────────
        $passed = ($script:Results | Where-Object Passed).Count
        $failed = ($script:Results | Where-Object { -not $_.Passed }).Count
        $total  = $script:Results.Count
        $duration = ((Get-Date) - $script:StartTime).TotalSeconds

        Write-TestLog "=== Summary ===" "Cyan"
        Write-TestLog "Passed:   $passed / $total"
        Write-TestLog "Failed:   $failed / $total" ($(if ($failed -gt 0) { "Red" } else { "Green" }))
        Write-TestLog "Duration: $($duration.ToString('F1'))s"
        Write-TestLog "Log:      $TestLogPath"

        if ($failed -gt 0) {
            Write-TestLog ""
            Write-TestLog "Failed assertions:" "Red"
            foreach ($r in $script:Results | Where-Object { -not $_.Passed }) {
                Write-TestLog "  - $($r.Name): $($r.Detail)" "Red"
            }
            exit 1
        }

        Write-TestLog ""
        Write-TestLog "All tests passed." "Green"
        Write-TestLog ""
        Write-TestLog "Note: this verifies the install scripting, robocopy /XD"
        Write-TestLog "behaviour, and relaunch chain. Visual confirmation that NO"
        Write-TestLog "PowerShell / cmd window flashed during the run is still on"
        Write-TestLog "you — keep an eye on the screen during step [4/5] of future runs."
    }

    exit 0
}

# =============================================================================
# Legacy modes: stage-only or stage + launch
# =============================================================================
# PID 999999 = guaranteed-dead process, so the script proceeds immediately
# instead of waiting 60s for nothing.
New-StagedUpdate -WaitForPid 999999 -Version $FakeVersion

Write-Host ""
Write-Host "Staging complete."
Write-Host "  App dir      : $AppDir"
Write-Host "  Fake version : $FakeVersion"
Write-Host "  Script       : $ScriptPath"
Write-Host "  Log (after)  : $LogPath"
Write-Host ""

if ($Launch) {
    Write-Host "Launching the install script with the production launch chain..."
    Write-Host "Watch the screen — no console / PowerShell window should appear."
    Write-Host ""

    Invoke-InstallScript

    Write-Host "Launched. After ~3 seconds, inspect the log:"
    Write-Host "  Get-Content '$LogPath'"
} else {
    Write-Host "Next steps:"
    Write-Host "  1. Launch $ExeName."
    Write-Host "  2. Settings -> Updates should show 'v$FakeVersion is ready to install'."
    Write-Host "  3. Click 'Restart Now to Update'. The app should close and reopen."
    Write-Host "  4. Inspect $LogPath afterwards."
    Write-Host ""
    Write-Host "Or run end-to-end with assertions and auto-cleanup:"
    Write-Host "  .\test_update_staging.ps1 -Automated"
}
