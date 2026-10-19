# initial-setup.ps1: first-time setup on Windows. Shows what will be pulled and
# linked, asks, then links every tt-* skill into the personal skill locations of
# Claude Code, Copilot CLI and Codex CLI. Safe to re-run.
# The linking itself lives in tt-guide/scripts/guide.sh (update check|apply),
# which this runs with Git for Windows' bash.

$ErrorActionPreference = 'Stop'

function Find-GitBash {
    # Not "bash" from PATH: that can be WSL's System32\bash.exe.
    $candidates = @()
    if ($env:CLAUDE_CODE_GIT_BASH_PATH) { $candidates += $env:CLAUDE_CODE_GIT_BASH_PATH }
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($git) {
        # <git root>\cmd\git.exe or <git root>\mingw64\bin\git.exe -> <git root>\bin\bash.exe
        $dir = Split-Path -Parent $git.Source
        foreach ($up in @('..', '..\..')) {
            $candidates += (Join-Path $dir "$up\bin\bash.exe")
        }
    }
    $candidates += "$env:ProgramFiles\Git\bin\bash.exe"
    $candidates += "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
    $candidates += "$env:LocalAppData\Programs\Git\bin\bash.exe"
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) { return (Resolve-Path -LiteralPath $c).Path }
    }
    return $null
}

$bash = Find-GitBash
if (-not $bash) {
    Write-Host 'Could not find Git for Windows (its bash.exe).' -ForegroundColor Red
    Write-Host 'Install it from https://git-scm.com/download/win, then run this again.'
    exit 1
}

# bash gets a forward-slash path so there is no backslash quoting to go wrong.
$guide = ((Join-Path $PSScriptRoot 'tt-guide\scripts\guide.sh') -replace '\\', '/')
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'tt-guide\scripts\guide.sh'))) {
    Write-Host "Can't find tt-guide\scripts\guide.sh. Run this from the toolbox folder." -ForegroundColor Red
    exit 1
}

& $bash $guide update check
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
$answer = Read-Host 'Go ahead and pull and link the skills? [y/N]'
if ($answer -notmatch '^(y|yes)$') {
    Write-Host 'Nothing was changed.'
    exit 0
}

Write-Host ''
& $bash $guide update apply
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host 'Setup done. Restart Claude Code, then type /tt-guide.'
