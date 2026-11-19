# Shared Windows packaging. Kept in each repo so source/ can rebuild on its own.

function Get-ReleaseVersion([string]$ProjectRoot) {
    $manifest = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'pubspec.yaml'))
    $pattern = '(?m)^version:[ \t]*(?<quote>[''"]?)(?<version>\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)\k<quote>[ \t]*(?:#.*)?\r?$'
    $versions = [regex]::Matches($manifest, $pattern)
    if ($versions.Count -ne 1) { throw 'pubspec.yaml must contain one top-level semantic version.' }
    $versions[0].Groups['version'].Value
}

function Assert-ReleaseChildPath([string]$Root, [string]$Path) {
    $rootPrefix = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $ancestor = [IO.Path]::GetFullPath($Path)
    if (-not $ancestor.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the release directory: $Path"
    }
    while ($ancestor) {
        if ((Test-Path -LiteralPath $ancestor) -and
            ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Refusing a release path through a link: $ancestor"
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
}

function Get-ReleaseSourceFiles([string]$ProjectRoot) {
    # Follow MyPay's allowlist approach. Include working changes within project
    # sources and known build files, without copying the whole checkout.
    $rootFiles = @(
        'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml', '.metadata',
        '.gitignore', '.markdownlint.json', 'LICENSE', 'LICENSE.md', 'README.md',
        'CHANGELOG.md', 'ARCHITECTURE.md', 'TODO.md', 'QUICK_START.md',
        'CROSS_PLATFORM_GUIDE.md', 'GETTING_STARTED.md', 'GITHUB_RELEASE_GUIDE.md',
        'LOCALIZATION_README.md', 'PRE_LAUNCH_CHECKLIST.md', 'REVIEW.md', 'Improvement.md',
        'PORTABLE-README.txt', 'BUILD_FIX_README.txt', 'THIRD_PARTY_NOTICES.md',
        'UPDATE_INSTRUCTIONS.txt', 'build-release.ps1', 'build.bat', 'build-windows.ps1',
        'package-windows.ps1', 'fix-portable-cmake.ps1', 'verify-build-syntax.ps1',
        'verify-portable-zip.ps1', 'test-portable-zip.ps1', 'test-analyzer-verdict.ps1',
        'test_update_staging.ps1', 'update_font_assets.dart', 'BUILD_ON_WINDOWS.cmd',
        'BUILD_QUICK_WINDOWS.cmd', 'START_MYCUT.cmd', 'RUN_ANALYSIS_WINDOWS.cmd',
        'RUN_CHECKS_WINDOWS.cmd', 'RUN_PACKAGE_DIAGNOSTIC.cmd', 'RUN_TEST_HANG_DIAGNOSTIC.cmd'
    )
    $directories = @(
        'lib', 'assets', 'android', 'ios', 'linux', 'macos', 'web', 'windows',
        'scripts', 'build-support', 'test', 'integration_test', '.github',
        'docs', 'branding', 'examples', 'design', 'screenshot', 'DEMO_DATA'
    )
    $excludedDirectories = @(
        '.git', '.dart_tool', '.pub-cache', '.pub', 'build', 'ephemeral',
        '.gradle', 'Pods', '.symlinks', '.plugin_symlinks', '.idea', '.vscode',
        'xcuserdata', '.generated', 'UserData', 'Private_Data', 'releases', 'dist',
        '__pycache__', '_build_tools', 'logs', 'downloads', 'exports'
    )
    $excludedFiles = @(
        'local.properties', 'key.properties', 'Generated.xcconfig',
        'flutter_export_environment.sh', 'generated_plugin_registrant.cc',
        'generated_plugin_registrant.h', 'generated_plugins.cmake',
        'GeneratedPluginRegistrant.swift', 'GeneratedPluginRegistrant.h',
        'GeneratedPluginRegistrant.m', 'GeneratedPluginRegistrant.java',
        '.flutter-plugins', '.flutter-plugins-dependencies', '.DS_Store',
        '.env', 'secrets.json', 'credentials.json', 'cookies.txt', 'settings.json'
    )
    $files = [Collections.Generic.List[string]]::new()
    foreach ($name in $rootFiles) {
        if (Test-Path -LiteralPath (Join-Path $ProjectRoot $name) -PathType Leaf) { $files.Add($name) }
    }
    $pending = [Collections.Generic.Queue[string]]::new()
    foreach ($directory in $directories) {
        if (Test-Path -LiteralPath (Join-Path $ProjectRoot $directory) -PathType Container) { $pending.Enqueue($directory) }
    }
    while ($pending.Count -gt 0) {
        $directory = $pending.Dequeue()
        $directoryPath = Join-Path $ProjectRoot $directory
        if ((Get-Item -LiteralPath $directoryPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Source contains a linked directory: $directory"
        }
        foreach ($item in Get-ChildItem -LiteralPath $directoryPath -Force) {
            $relative = "$directory/$($item.Name)"
            if ($item.PSIsContainer) {
                if ($excludedDirectories -notcontains $item.Name) { $pending.Enqueue($relative) }
            }
            elseif ($excludedFiles -notcontains $item.Name -and $item.Name -notlike '.env.*' -and
                $item.Extension -notin @('.jks', '.keystore', '.pfx', '.p12', '.pem', '.key', '.log', '.pyc')) {
                $files.Add($relative)
            }
        }
    }
    $files | Sort-Object
}

function Get-ReleaseSourceManifest([string]$ProjectRoot, [string]$CopyTo) {
    $files = @(Get-ReleaseSourceFiles $ProjectRoot)
    foreach ($required in @('pubspec.yaml', 'pubspec.lock', 'lib/main.dart',
            'build-release.ps1', 'scripts/release-package.ps1', 'windows/CMakeLists.txt',
            'windows/flutter/CMakeLists.txt', 'windows/runner/CMakeLists.txt')) {
        if ($files -notcontains $required) { throw "Required source file missing: $required" }
    }
    foreach ($relative in $files) {
        $source = Join-Path $ProjectRoot $relative
        if ((Get-Item -LiteralPath $source -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Source contains a linked file: $relative"
        }
        if ($CopyTo) {
            $target = Join-Path $CopyTo $relative
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
            Copy-Item -LiteralPath $source -Destination $target
            $source = $target
        }
        [pscustomobject]@{ path = $relative; sha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash }
    }
}

function Write-VerifiedReleaseZip([string]$PackagePath, [string]$ReleaseName, [string]$ZipPath) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $items = @(Get-ChildItem -LiteralPath $PackagePath -Recurse -Force)
    $writer = [IO.Compression.ZipFile]::Open($ZipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($item in $items) {
            $relative = $item.FullName.Substring($PackagePath.Length + 1).Replace('\', '/')
            $name = "$ReleaseName/$relative"
            if ($item.PSIsContainer) {
                if (-not (Get-ChildItem -LiteralPath $item.FullName -Force | Select-Object -First 1)) {
                    $writer.CreateEntry("$name/") | Out-Null
                }
            } else {
                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $writer, $item.FullName, $name, [IO.Compression.CompressionLevel]::Optimal
                ) | Out-Null
            }
        }
    } finally { $writer.Dispose() }

    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        foreach ($item in $items | Where-Object { -not $_.PSIsContainer }) {
            $relative = $item.FullName.Substring($PackagePath.Length + 1).Replace('\', '/')
            $entry = $archive.GetEntry("$ReleaseName/$relative")
            if (-not $entry) { throw "ZIP is missing $relative" }
            $stream = $entry.Open()
            try { $hash = (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash }
            finally { $stream.Dispose() }
            if ($hash -ne (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash) {
                throw "ZIP checksum mismatch: $relative"
            }
        }
    } finally { $archive.Dispose() }
}

function New-WindowsReleasePackage {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$AppName,
        [Parameter(Mandatory)][string]$ExeName,
        [object[]]$BuildSource,
        [string]$FlutterExecutable,
        [scriptblock]$PreparePackage,
        [scriptblock]$TestZip,
        [switch]$WriteChecksum
    )
    $ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
    $version = Get-ReleaseVersion $ProjectRoot
    $name = "$AppName-v$version-windows"
    $root = Join-Path $ProjectRoot 'releases'
    $build = Join-Path $ProjectRoot 'build/windows/x64/runner/Release'
    foreach ($relative in @($ExeName, 'flutter_windows.dll', 'data/icudtl.dat')) {
        $file = Join-Path $build $relative
        if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Item -LiteralPath $file).Length -eq 0) {
            throw "Required build output missing or empty: $file"
        }
    }
    $stage = Join-Path $root ('.package-' + [guid]::NewGuid().ToString('N'))
    $package = Join-Path $stage $name
    $zip = Join-Path $stage "$name.zip"
    $output = Join-Path $root $name
    $zipOutput = Join-Path $root "$name.zip"
    $backup = Join-Path $root ('previous/' + $name + '-' + [IO.Path]::GetFileName($stage).Substring(9))
    $lockFile = Join-Path $root '.publish.lock'
    foreach ($path in @($stage, $output, $zipOutput, "$zipOutput.sha256", $backup, $lockFile)) {
        Assert-ReleaseChildPath $root $path
    }
    [IO.Directory]::CreateDirectory($package) | Out-Null
    try {
        $source = Join-Path $package 'source'
        $manifest = @(Get-ReleaseSourceManifest $ProjectRoot $source)
        if ($BuildSource -and (Compare-Object -ReferenceObject $BuildSource -DifferenceObject $manifest -Property path, sha256)) {
            throw 'Source changed during the build. Run the release build again.'
        }
        Copy-Item -LiteralPath (Join-Path $build $ExeName) -Destination $package
        Get-ChildItem -LiteralPath $build -Filter '*.dll' -File | Copy-Item -Destination $package
        Copy-Item -LiteralPath (Join-Path $build 'data') -Destination $package -Recurse
        foreach ($file in @('README.md', 'LICENSE', 'CHANGELOG.md', 'QUICK_START.md')) {
            $document = Join-Path $source $file
            if (Test-Path -LiteralPath $document -PathType Leaf) { Copy-Item -LiteralPath $document -Destination $package }
        }
        if ($PreparePackage) { & $PreparePackage $package $source | Out-Null }

        $flutterVersion = if ($FlutterExecutable) {
            $json = & $FlutterExecutable --version --machine | Out-String
            if ($LASTEXITCODE -ne 0) { throw 'Could not read the Flutter toolchain version.' }
            $json | ConvertFrom-Json
        }
        $sourceStatus = if ($BuildSource) { 'Working source verified against the start of compilation.' }
            else { 'Current working source packaged with an existing build. The binary may predate this snapshot.' }
        ConvertTo-Json -InputObject $manifest -Depth 4 | Set-Content -LiteralPath (Join-Path $package 'SOURCE-MANIFEST.json') -Encoding UTF8
        [ordered]@{ version = $version; builtAtUtc = [DateTime]::UtcNow.ToString('o'); flutter = $flutterVersion;
            sourceFileCount = $manifest.Count; source = $sourceStatus } |
            ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $package 'BUILD-INFO.json') -Encoding UTF8
        @"
Recovering $AppName $version

Copy source/ to a writable folder and run .\build-release.ps1 from there.
Use the Flutter version recorded in BUILD-INFO.json and the Windows C++ toolchain.
SOURCE-MANIFEST.json checks the archived files. The snapshot has no Git history.
$sourceStatus
Restore your personal data from a separate backup.
"@ | Set-Content -LiteralPath (Join-Path $package 'SOURCE-RECOVERY.txt') -Encoding UTF8
        Write-VerifiedReleaseZip $package $name $zip
        if ($TestZip) { & $TestZip $zip $ProjectRoot | Out-Null }
        if ($WriteChecksum) {
            $digest = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
            "$digest  $name.zip" | Set-Content -LiteralPath "$zip.sha256" -Encoding ASCII
        }

        $lock = [IO.File]::Open($lockFile, 'OpenOrCreate', 'Write', 'None')
        try {
            $pairs = @(@{ Build = $package; Live = $output }, @{ Build = $zip; Live = $zipOutput })
            if ($WriteChecksum) { $pairs += @{ Build = "$zip.sha256"; Live = "$zipOutput.sha256" } }
            $saved = @()
            $published = @()
            try {
                foreach ($pair in $pairs) {
                    if (Test-Path -LiteralPath $pair.Live) {
                        [IO.Directory]::CreateDirectory($backup) | Out-Null
                        $previous = Join-Path $backup ([IO.Path]::GetFileName($pair.Live))
                        Move-Item -LiteralPath $pair.Live -Destination $previous -ErrorAction Stop
                        $saved += @{ Previous = $previous; Live = $pair.Live }
                    }
                }
                foreach ($pair in $pairs) {
                    Move-Item -LiteralPath $pair.Build -Destination $pair.Live -ErrorAction Stop
                    $published += $pair
                }
            } catch {
                foreach ($pair in $published) { Move-Item -LiteralPath $pair.Live -Destination $pair.Build -ErrorAction Stop }
                foreach ($pair in $saved) { Move-Item -LiteralPath $pair.Previous -Destination $pair.Live -ErrorAction Stop }
                throw
            }
        } finally { $lock.Dispose() }

        [pscustomobject]@{ OutputPath = $output; ZipPath = $zipOutput; SourceFiles = $manifest.Count }
    } finally {
        Assert-ReleaseChildPath $root $stage
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    }
}
