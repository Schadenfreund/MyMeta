# Testing MyMeta

## Flutter widget tests

```powershell
flutter test
```

Runs everything under `test/*.dart`. Currently just `widget_test.dart`.

## Update flow tests (Windows only)

The update flow is tested by a PowerShell harness at the project root, not by
Flutter tests, because it exercises `cmd.exe` + `powershell.exe` + the
filesystem of an installed build.

### One-shot end-to-end check

```powershell
flutter build windows --release      # rebuild if code changed
..\test_update_staging.ps1 -Automated
```

Stages a fake pending update against the release build, fires the production
launch chain, polls the install log for completion, asserts that:

- `Robocopy` finished cleanly (exit code < 8)
- The marker injected into the staged release made it into the app folder
  (proves the copy actually ran)
- The sentinel in `UserData/` survived (proves `/XD UserData` worked)
- `MyMeta.exe` relaunched within 10 seconds
- No `FATAL` line in the install log

Always cleans up after itself (kills the relaunched MyMeta, removes
`UserData/Updates/`, deletes the marker + sentinel) — runs in a `try/finally`
so cleanup happens even on failure.

Output goes to console **and** `test_update_log.txt` in the project root,
which also captures the full install log (which the cleanup step deletes from
its original location).

Exits non-zero if any assertion fails, so you can gate releases on it:

```powershell
.\test_update_staging.ps1 -Automated
if ($LASTEXITCODE -ne 0) { throw "update test failed" }
```

### What automation can't check

The script can't reliably detect a console window that flashed for 50 ms.
The screen during step `[4/5]` should show **nothing** — eyeball it on the
first run after any change to `lib/services/update_installer.dart`.

### Other modes (manual)

```powershell
..\test_update_staging.ps1                # stages only; you drive the app
..\test_update_staging.ps1 -Launch        # stages + fires launch chain, no app
..\test_update_staging.ps1 -FakeVersion 1.1.7   # tests the "Updated to v…" toast
```

See the comment block at the top of `test_update_staging.ps1` for the full
parameter list.
