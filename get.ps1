<#
.SYNOPSIS
    Install `note` from its latest GitHub release, on Windows.

.DESCRIPTION
    No toolchain is needed: this downloads the build published for your
    platform, checks it against the release's SHA256SUMS, and puts it in a
    directory on your PATH.

    From PowerShell:

        irm https://raw.githubusercontent.com/lhypds/.note/main/get.ps1 | iex

    From cmd.exe:

        powershell -NoProfile -Command "irm https://raw.githubusercontent.com/lhypds/.note/main/get.ps1 | iex"

    To pass options through the pipe, create the script block yourself:

        &([scriptblock]::Create((irm https://raw.githubusercontent.com/lhypds/.note/main/get.ps1))) -InstallDir C:\tools\note

.PARAMETER Version
    Version to install, with or without the leading "v". Defaults to the
    latest release, or to $env:NOTE_VERSION when that is set.

.PARAMETER Variant
    Build to install: rust (default), a single self-contained binary, or
    python, the PyInstaller bundle.

.PARAMETER InstallDir
    Directory to install note.exe into. Defaults to $env:NOTE_INSTALL_DIR, or
    %LOCALAPPDATA%\Programs\note — a per-user location, so no administrator
    rights are needed.

.PARAMETER Repo
    GitHub repository to download from, as "owner/name".

.PARAMETER NoPath
    Do not touch the user PATH.
#>

param(
    [string] $Version    = $env:NOTE_VERSION,
    [ValidateSet('rust', 'python')]
    [string] $Variant    = $(if ($env:NOTE_VARIANT) { $env:NOTE_VARIANT } else { 'rust' }),
    [string] $InstallDir = $env:NOTE_INSTALL_DIR,
    [string] $Repo       = $(if ($env:NOTE_REPO) { $env:NOTE_REPO } else { 'lhypds/.note' }),
    [switch] $NoPath
)

$ErrorActionPreference = 'Stop'
# Invoke-WebRequest's progress bar makes downloads several times slower on
# Windows PowerShell, and TLS 1.2 is not its default there either.
$ProgressPreference = 'SilentlyContinue'
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    # PowerShell 7 negotiates TLS itself and has no such setting.
}

$UserAgent = 'note-installer'

function Fail($message) {
    Write-Host "get.ps1: $message" -ForegroundColor Red
    exit 1
}

function Save-File($url, $path) {
    Invoke-WebRequest -Uri $url -OutFile $path -UserAgent $UserAgent -UseBasicParsing
}

# ── platform ────────────────────────────────────────────────────────────────
# PROCESSOR_ARCHITECTURE describes the running process, so a 32-bit PowerShell
# on 64-bit Windows reports x86; PROCESSOR_ARCHITEW6432 is the machine's own.
$osArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
switch ($osArch) {
    'AMD64' { $arch = 'amd64' }
    'ARM64' { $arch = 'arm64' }
    default { Fail "unsupported architecture `"$osArch`" — build from source instead: https://github.com/$Repo" }
}

# ── release ─────────────────────────────────────────────────────────────────
# The release is read through the API rather than guessed at, because the asset
# list is what says whether this release has a Windows build at all.
$headers = @{ 'Accept' = 'application/vnd.github+json' }
# A token is not required, but it lifts GitHub's anonymous rate limit.
if ($env:GITHUB_TOKEN) { $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN" }

$Version = $Version -replace '^v', ''
$endpoint = if ($Version) {
    "https://api.github.com/repos/$Repo/releases/tags/v$Version"
} else {
    "https://api.github.com/repos/$Repo/releases/latest"
}
try {
    $release = Invoke-RestMethod -Uri $endpoint -Headers $headers -UserAgent $UserAgent
} catch {
    Fail "could not read the release of ${Repo}: $($_.Exception.Message)"
}
if (-not $Version) { $Version = ($release.tag_name -replace '^v', '') }
if (-not $Version) { Fail "$Repo has no published release yet; pass -Version <ver>" }

$assets = @($release.assets | ForEach-Object { $_.name })

if (-not $InstallDir) { $InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\note' }

# ── asset ───────────────────────────────────────────────────────────────────
# Preferred name first, then any Windows asset of this variant, so a release
# that names its archives differently still installs.
function Find-Asset($wanted) {
    $exact = "dot_note_${Variant}_v${Version}_windows_${wanted}.zip"
    if ($assets -contains $exact) { return $exact }
    $assets | Where-Object { $_ -match 'windows' -and $_ -match [regex]::Escape($wanted) -and $_ -match [regex]::Escape($Variant) } |
        Select-Object -First 1
}

$archive = Find-Asset $arch
if (-not $archive -and $arch -eq 'arm64') {
    # Windows runs x64 binaries on ARM64 under emulation, so a release without
    # a native build is still installable.
    $archive = Find-Asset 'amd64'
    if ($archive) { Write-Host "get.ps1: release v$Version has no arm64 build; installing the amd64 one (Windows will emulate it)" }
}
if (-not $archive) {
    Write-Host "get.ps1: release v$Version of $Repo publishes no Windows build of the $Variant variant." -ForegroundColor Red
    if ($assets) { Write-Host "get.ps1: it has: $($assets -join ', ')" }
    Write-Host "get.ps1: install it under WSL instead:"
    Write-Host "get.ps1:   curl -fsSL https://raw.githubusercontent.com/$Repo/main/get.sh | sh"
    Write-Host "get.ps1: or build it from source:"
    Write-Host "get.ps1:   git clone https://github.com/$Repo.git; cd .note\rust; cargo build --release"
    exit 1
}

$base = "https://github.com/$Repo/releases/download/v$Version"
$temp = Join-Path ([IO.Path]::GetTempPath()) ("note-install-" + [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null

try {
    # ── download and verify ─────────────────────────────────────────────────
    Write-Host "get.ps1: downloading note $Version ($Variant build) for windows/$arch..."
    $zip = Join-Path $temp $archive
    try {
        Save-File "$base/$archive" $zip
    } catch {
        Fail "could not download $base/${archive}: $($_.Exception.Message)"
    }

    # Releases up to v0.0.22 shipped without checksums; verify when the release
    # has them, and say plainly when it does not rather than implying it was
    # checked. The sums go through a file rather than a string, because a
    # release asset is served as application/octet-stream and comes back as
    # bytes.
    if ($assets -contains 'SHA256SUMS') {
        $sumsPath = Join-Path $temp 'SHA256SUMS'
        try {
            Save-File "$base/SHA256SUMS" $sumsPath
        } catch {
            Fail "could not download $base/SHA256SUMS: $($_.Exception.Message)"
        }
        $sums = @{}
        foreach ($line in ((Get-Content -LiteralPath $sumsPath -Raw) -split "`n")) {
            $fields = $line.Trim() -split '\s+'
            # Each line is "<hash>  <asset>"; binary mode marks the name with "*".
            if ($fields.Count -eq 2) { $sums[$fields[1].TrimStart('*')] = $fields[0].ToLower() }
        }
        if (-not $sums.ContainsKey($archive)) {
            Fail "SHA256SUMS of release v$Version lists no checksum for $archive"
        }
        $got = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
        if ($got -ne $sums[$archive]) {
            Fail "checksum mismatch for ${archive}: got $got, want $($sums[$archive])"
        }
    } else {
        Write-Host "get.ps1: release v$Version publishes no SHA256SUMS — the download was not verified." -ForegroundColor Yellow
    }

    # ── unpack ──────────────────────────────────────────────────────────────
    $unpacked = Join-Path $temp 'unpacked'
    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
        Expand-Archive -LiteralPath $zip -DestinationPath $unpacked -Force
    } else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $unpacked)
    }
    $binary = Get-ChildItem -LiteralPath $unpacked -Filter 'note.exe' -Recurse -File | Select-Object -First 1
    if (-not $binary) { Fail "$archive contains no note.exe" }

    # ── install ─────────────────────────────────────────────────────────────
    # New-Item also normalises the directory, so a relative -InstallDir and a
    # trailing backslash both end up as one absolute path for the PATH check.
    $InstallDir = (New-Item -ItemType Directory -Path $InstallDir -Force).FullName
    $target = Join-Path $InstallDir 'note.exe'
    if (Test-Path -LiteralPath $target) {
        # Windows will not overwrite a running executable, but it will let it
        # be renamed out of the way.
        $old = "$target.old"
        Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue
        try {
            Move-Item -LiteralPath $target -Destination $old -Force
        } catch {
            Fail "note.exe in $InstallDir is in use; close any running note and try again"
        }
    }
    try {
        Copy-Item -LiteralPath $binary.FullName -Destination $target -Force
        if ($Variant -eq 'python') {
            # The PyInstaller bundle only runs beside its _internal directory,
            # so that ships with the executable.
            $internal = Join-Path $binary.Directory.FullName '_internal'
            if (-not (Test-Path -LiteralPath $internal)) {
                Fail "$archive is not a python bundle — it has no _internal directory"
            }
            $installedInternal = Join-Path $InstallDir '_internal'
            Remove-Item -LiteralPath $installedInternal -Recurse -Force -ErrorAction SilentlyContinue
            Copy-Item -LiteralPath $internal -Destination $installedInternal -Recurse -Force
        }
    } catch {
        Fail "could not write ${target}: $($_.Exception.Message)"
    }
    Remove-Item -LiteralPath "$target.old" -Force -ErrorAction SilentlyContinue

    $reported = & $target --version
    Write-Host "get.ps1: installed $target ($reported)" -ForegroundColor Green

    # ── PATH ────────────────────────────────────────────────────────────────
    if (-not $NoPath) {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $entries = @()
        if ($userPath) { $entries = @($userPath -split ';' | Where-Object { $_ }) }
        if ($entries -notcontains $InstallDir) {
            [Environment]::SetEnvironmentVariable('Path', (($entries + $InstallDir) -join ';'), 'User')
            Write-Host "get.ps1: added $InstallDir to your user PATH"
            Write-Host "get.ps1: open a new terminal for `"note`" to be found"
        }
        # Make it work in this session too, without waiting for a new terminal.
        if (($env:Path -split ';') -notcontains $InstallDir) { $env:Path = "$env:Path;$InstallDir" }
    } else {
        Write-Host "get.ps1: leaving PATH alone; run note as $target"
    }

    # ── .noterc ─────────────────────────────────────────────────────────────
    $noterc = Join-Path $HOME '.noterc'
    if (-not (Test-Path -LiteralPath $noterc)) {
        Set-Content -LiteralPath $noterc -Value 'notePath='
        Write-Host "get.ps1: created $noterc — set notePath to your note directories, e.g."
        Write-Host "         notePath=C:\Users\you\Dropbox\Note;"
    }

    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "next: install fzf for `"note search`", `"note open`" and `"note delete`""
        Write-Host "      (run: winget install fzf)"
    }
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
