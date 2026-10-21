# rider-tab.ps1: open a new tab in the Rider terminal that is running this session
# and start a launcher script in it, by sending keystrokes. Rider (2024.3) has no
# command-line or API way to open a terminal tab.
#
# usage: rider-tab.ps1 <launcher script> <bash.exe> [<tab name>]
#
# With a tab name, the new tab is renamed through Rider's "Rename Session" action
# (Find Action), so it no longer says "Local".
#
# It only types when Rider is the foreground window and its title says the
# Terminal tool window has focus ("Terminal - <project>"), which is true while the
# engineer answers a question in the terminal tab. Anything else exits 1 without
# sending a key, and new-session.sh falls back to Windows Terminal.
# It assumes the new tab's shell is PowerShell (Rider's default on Windows).
# Exit: 0 the command is running in a new tab, 1 nothing was typed, 2 usage,
# 3 a tab was opened and the command typed, but nothing started in it.
param([string]$Launcher, [string]$Bash, [string]$TabName = '')

if (-not $Launcher -or -not $Bash) { Write-Error 'usage: rider-tab.ps1 <launcher> <bash.exe>'; exit 2 }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -Namespace Tt -Name Win -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(System.IntPtr h, out uint pid);
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)] public static extern int GetWindowText(System.IntPtr h, System.Text.StringBuilder s, int n);
'@

# The foreground window as "<process name>|<title>|<pid>"
function Get-Foreground {
	$h = [Tt.Win]::GetForegroundWindow()
	$procId = [uint32]0
	[void][Tt.Win]::GetWindowThreadProcessId($h, [ref]$procId)
	$sb = New-Object System.Text.StringBuilder 512
	[void][Tt.Win]::GetWindowText($h, $sb, 512)
	$p = Get-Process -Id $procId -ErrorAction SilentlyContinue
	"$($p.ProcessName)|$($sb.ToString())|$procId"
}

function Test-RiderTerminal { (Get-Foreground) -match '^rider64\|Terminal\b' }

# The shells (one per terminal tab) that are children of a process
function Get-Shells($parent) {
	@(Get-CimInstance Win32_Process -Filter "ParentProcessId=$parent" |
		Where-Object { $_.Name -match '^(powershell|pwsh|cmd|bash)\.exe$' } | ForEach-Object { $_.ProcessId })
}

if (-not (Test-RiderTerminal)) { Write-Host 'Rider is not in the foreground with the Terminal focused'; exit 1 }
$rider = [int](((Get-Foreground) -split '\|')[-1])
$before = Get-Shells $rider

# New terminal tab (Rider's default Ctrl+Shift+T).
[System.Windows.Forms.SendKeys]::SendWait('^+t')

# Wait for the tab's shell to start, then for it to finish loading its profile.
$tab = $null
for ($i = 0; $i -lt 40 -and -not $tab; $i++) {
	Start-Sleep -Milliseconds 250
	$tab = Get-Shells $rider | Where-Object { $before -notcontains $_ } | Select-Object -First 1
}
if (-not $tab) { Write-Host 'No new terminal tab appeared'; exit 1 }
Start-Sleep -Milliseconds 3000
if (-not (Test-RiderTerminal)) { Write-Host 'Rider lost the Terminal focus after opening the tab'; exit 1 }

# SendKeys treats + ^ % ~ ( ) { } [ ] as commands: wrap each in braces.
function Send-Text($text) {
	$escaped = [regex]::Replace($text, '[+^%~(){}\[\]]', { param($m) '{' + $m.Value + '}' })
	[System.Windows.Forms.SendKeys]::SendWait($escaped)
}

# Name the tab: Find Action > Rename Session > the name. Best effort; the session
# still starts if the dialog doesn't appear.
if ($TabName) {
	[System.Windows.Forms.SendKeys]::SendWait('^+a')
	Start-Sleep -Milliseconds 700
	Send-Text 'Rename Session'
	Start-Sleep -Milliseconds 1000
	[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
	Start-Sleep -Milliseconds 800
	[System.Windows.Forms.SendKeys]::SendWait('^a')
	Send-Text $TabName
	[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
	Start-Sleep -Milliseconds 500
	if (-not (Test-RiderTerminal)) { Write-Host 'Rider lost the Terminal focus while naming the tab'; exit 1 }
}

Send-Text "& '$Bash' '$Launcher'"
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')

# Check the launcher started in that tab (bash is its child, or claude below it).
for ($i = 0; $i -lt 40; $i++) {
	Start-Sleep -Milliseconds 250
	if (Get-CimInstance Win32_Process -Filter "ParentProcessId=$tab") { exit 0 }
}
Write-Host 'The command was typed into the new tab but nothing started in it'
exit 3
