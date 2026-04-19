$ErrorActionPreference = 'Stop'
$workspace = (Get-Location).Path
$workspaceFull = [System.IO.Path]::GetFullPath($workspace)
$flutterCmd = (Get-Command flutter).Source
$promptRegex = 'Flutter run key commands\.|The Flutter DevTools debugger and profiler on Windows is available at:|A Dart VM Service on Windows is available at:|An Observatory debugger and profiler on Windows is available at:'

function Get-LogText {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return '' }
    try { return (Get-Content -Path $Path -Raw -ErrorAction Stop) } catch { return '' }
}

function Stop-StaleWorkspaceProcesses {
    param([string]$WorkspaceFull)
    $targets = Get-CimInstance Win32_Process | Where-Object {
        $_.ProcessId -ne $PID -and (
            (
                $_.ExecutablePath -and
                [System.IO.Path]::GetFullPath($_.ExecutablePath).StartsWith($WorkspaceFull, [System.StringComparison]::OrdinalIgnoreCase)
            ) -or (
                $_.CommandLine -and
                $_.CommandLine.IndexOf($WorkspaceFull, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
                $_.Name -match '^(?i)(flutter|dart|ftune|cmd|conhost)(\.exe)?$'
            )
        )
    } | Sort-Object ProcessId -Unique

    if ($targets) {
        Write-Host ('Stopping stale processes: ' + (($targets | ForEach-Object { '{0}({1})' -f $_.Name, $_.ProcessId }) -join ', '))
        foreach ($t in $targets) {
            try { Stop-Process -Id $t.ProcessId -Force -ErrorAction Stop } catch { Write-Host ('Could not stop PID ' + $t.ProcessId + ': ' + $_.Exception.Message) }
        }
        $ids = $targets.ProcessId | Select-Object -Unique
        if ($ids) { Wait-Process -Id $ids -Timeout 5 -ErrorAction SilentlyContinue }
    } else {
        Write-Host 'Stopping stale processes: none'
    }
}

function Close-WorkspaceAppProcesses {
    param([string]$WorkspaceFull)
    $apps = Get-CimInstance Win32_Process | Where-Object {
        $_.ProcessId -ne $PID -and $_.ExecutablePath -and
        [System.IO.Path]::GetFullPath($_.ExecutablePath).StartsWith($WorkspaceFull, [System.StringComparison]::OrdinalIgnoreCase)
    } | Sort-Object ProcessId -Unique

    if (-not $apps) {
        Write-Host 'No workspace app processes found to close.'
        return
    }

    Write-Host ('Closing workspace app processes: ' + (($apps | ForEach-Object { '{0}({1})' -f $_.Name, $_.ProcessId }) -join ', '))
    foreach ($app in $apps) {
        try {
            $p = Get-Process -Id $app.ProcessId -ErrorAction Stop
            if ($p.MainWindowHandle -ne 0) { $null = $p.CloseMainWindow() } else { Stop-Process -Id $app.ProcessId -Force -ErrorAction Stop }
        } catch { Write-Host ('Close attempt failed for PID ' + $app.ProcessId + ': ' + $_.Exception.Message) }
    }

    $ids = $apps.ProcessId | Select-Object -Unique
    if ($ids) {
        Wait-Process -Id $ids -Timeout 10 -ErrorAction SilentlyContinue
        foreach ($id in $ids) {
            $still = Get-Process -Id $id -ErrorAction SilentlyContinue
            if ($still) { try { Stop-Process -Id $id -Force -ErrorAction Stop } catch {} }
        }
    }
}

function Invoke-ObservedRun {
    param([int]$RunNumber,[string]$Workspace,[string]$WorkspaceFull,[string]$FlutterCmd,[string]$PromptRegex)
    Stop-StaleWorkspaceProcesses -WorkspaceFull $WorkspaceFull
    $log = Join-Path $Workspace ('plain_run_{0}.log' -f $RunNumber)
    if (Test-Path $log) { Remove-Item $log -Force }

    $cmdCommand = "cd /d `"$Workspace`" && `"$FlutterCmd`" run -d windows > `"$log`" 2>&1"
    Write-Host ('Starting run ' + $RunNumber + ': ' + $cmdCommand)
    $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d','/c',$cmdCommand) -WorkingDirectory $Workspace -PassThru -WindowStyle Hidden

    $reachedPrompt = $false
    $lostConnection = $false
    $wmClose = $false
    $wmDestroy = $false
    $promptAt = $null
    $breakAt = $null
    $reason = 'process exited before prompt window condition'
    $safety = [System.Diagnostics.Stopwatch]::StartNew()

    while ($true) {
        $exited = $proc.WaitForExit(1000)
        $text = Get-LogText -Path $log
        if (-not $reachedPrompt -and $text -match $PromptRegex) {
            $reachedPrompt = $true
            $promptAt = Get-Date
            Write-Host ('Run ' + $RunNumber + ': interactive prompt detected at ' + $promptAt.ToString('s'))
        }
        if (-not $lostConnection -and $text -match 'Lost connection to device') {
            $lostConnection = $true
            $breakAt = Get-Date
            $reason = 'lost connection detected'
            break
        }
        if (-not $wmClose -and $text -match '\[runner\] WM_CLOSE') { $wmClose = $true }
        if (-not $wmDestroy -and $text -match '\[runner\] WM_DESTROY') { $wmDestroy = $true }

        if ($reachedPrompt -and ((Get-Date) - $promptAt).TotalSeconds -ge 30) {
            $breakAt = Get-Date
            $reason = '30-second observation window completed'
            break
        }
        if ($exited) {
            $breakAt = Get-Date
            $reason = 'process exited'
            break
        }
        if ($safety.Elapsed.TotalMinutes -ge 12) {
            $breakAt = Get-Date
            $reason = 'safety timeout'
            break
        }
    }

    if (-not $proc.HasExited -and $reachedPrompt -and -not $lostConnection) {
        Close-WorkspaceAppProcesses -WorkspaceFull $WorkspaceFull
        $null = $proc.WaitForExit(15000)
    }

    if (-not $proc.HasExited) {
        Stop-StaleWorkspaceProcesses -WorkspaceFull $WorkspaceFull
        if (-not $proc.HasExited) { try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop } catch {} }
    }

    $null = $proc.WaitForExit(3000)
    $finalText = Get-LogText -Path $log
    if (-not $reachedPrompt -and $finalText -match $PromptRegex) { $reachedPrompt = $true }
    if (-not $lostConnection -and $finalText -match 'Lost connection to device') { $lostConnection = $true }
    if (-not $wmClose -and $finalText -match '\[runner\] WM_CLOSE') { $wmClose = $true }
    if (-not $wmDestroy -and $finalText -match '\[runner\] WM_DESTROY') { $wmDestroy = $true }

    $stayedAlive = $false
    if ($reachedPrompt -and $promptAt -and $breakAt) {
        $stayedAlive = (-not $lostConnection) -and ((New-TimeSpan -Start $promptAt -End $breakAt).TotalSeconds -ge 30)
    }

    [pscustomobject]@{
        Run = $RunNumber
        Log = $log
        BuiltAndReachedInteractivePrompt = $reachedPrompt
        LostConnectionToDeviceAppeared = $lostConnection
        RunnerWM_CLOSEAppeared = $wmClose
        RunnerWM_DESTROYAppeared = $wmDestroy
        StayedAliveForObservationWindow = $stayedAlive
        StopReason = $reason
    }
}

$results = foreach ($n in 1..3) {
    Write-Host ('=== RUN ' + $n + ' ===')
    Invoke-ObservedRun -RunNumber $n -Workspace $workspace -WorkspaceFull $workspaceFull -FlutterCmd $flutterCmd -PromptRegex $promptRegex
}

Write-Host '=== RESULTS ==='
$results | Format-List * | Out-String | Write-Host
$results | ConvertTo-Json -Depth 4
