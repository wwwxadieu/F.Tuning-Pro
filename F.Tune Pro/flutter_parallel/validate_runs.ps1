$ErrorActionPreference = 'Stop'
function Stop-WorkspaceRelated {
    param([string]$Workspace)
    $escaped = [Regex]::Escape($Workspace)
    $table = Get-CimInstance Win32_Process
    $byId = @{}
    $children = @{}
    foreach ($p in $table) {
        $id = [int]$p.ProcessId
        $parent = [int]$p.ParentProcessId
        $byId[$id] = $p
        if (-not $children.ContainsKey($parent)) { $children[$parent] = New-Object System.Collections.Generic.List[int] }
        $children[$parent].Add($id)
    }
    $ids = New-Object System.Collections.Generic.HashSet[int]
    function Add-Child([int]$Id) {
        if (-not $ids.Add($Id)) { return }
        if ($children.ContainsKey($Id)) {
            foreach ($childId in $children[$Id]) {
                if ($byId[$childId].Name -match 'cmd|ftune|flutter|dart') { Add-Child $childId }
            }
        }
    }
    foreach ($p in $table) {
        if (($p.Name -match 'ftune|flutter|dart') -and ((($p.CommandLine -ne $null) -and ($p.CommandLine -match $escaped)) -or (($p.ExecutablePath -ne $null) -and ($p.ExecutablePath -match $escaped)))) {
            Add-Child ([int]$p.ProcessId)
        }
    }
    foreach ($id in (@($ids) | ForEach-Object { [int]$_ } | Sort-Object -Descending)) {
        try { Stop-Process -Id $id -Force -ErrorAction Stop } catch {}
    }
}
function Stop-ProcessTree {
    param([int]$RootId)
    $table = Get-CimInstance Win32_Process
    $children = @{}
    foreach ($p in $table) {
        $parent = [int]$p.ParentProcessId
        if (-not $children.ContainsKey($parent)) { $children[$parent] = New-Object System.Collections.Generic.List[int] }
        $children[$parent].Add([int]$p.ProcessId)
    }
    $ids = New-Object System.Collections.Generic.HashSet[int]
    function Add-Child([int]$Id) {
        if (-not $ids.Add($Id)) { return }
        if ($children.ContainsKey($Id)) {
            foreach ($childId in $children[$Id]) { Add-Child $childId }
        }
    }
    Add-Child $RootId
    foreach ($id in (@($ids) | ForEach-Object { [int]$_ } | Sort-Object -Descending)) {
        try { Stop-Process -Id $id -Force -ErrorAction Stop } catch {}
    }
}
function Get-LogText {
    param([string]$Path)
    if (Test-Path $Path) { return [System.IO.File]::ReadAllText($Path) }
    return ''
}
function Invoke-ObservedRun {
    param([int]$RunNumber, [string]$Workspace)
    Stop-WorkspaceRelated -Workspace $Workspace
    $combinedLog = Join-Path $Workspace ("observed_run_{0}.combined.log" -f $RunNumber)
    if (Test-Path $combinedLog) { Remove-Item $combinedLog -Force }
    $cmdText = '/d /c call flutter run -d windows > "' + $combinedLog + '" 2>&1'
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'cmd.exe'
    $psi.Arguments = $cmdText
    $psi.WorkingDirectory = $Workspace
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $pattern = 'Flutter run key commands\.|The Flutter DevTools debugger and profiler on Windows is available at:|A Dart VM Service on Windows is available at:|An Observatory debugger and profiler on Windows is available at:'
    $reachedPrompt = $false
    $startup = [System.Diagnostics.Stopwatch]::StartNew()
    while ($startup.Elapsed.TotalMinutes -lt 8) {
        $text = Get-LogText -Path $combinedLog
        if ($text -match $pattern) { $reachedPrompt = $true; break }
        if ($proc.HasExited) { break }
        [void]$proc.WaitForExit(200)
    }
    $lost = $false
    $wmClose = $false
    $wmDestroy = $false
    $alive20 = $false
    if ($reachedPrompt) {
        $observe = [System.Diagnostics.Stopwatch]::StartNew()
        while ($observe.Elapsed.TotalSeconds -lt 20) {
            if ($proc.HasExited) { break }
            [void]$proc.WaitForExit(200)
        }
        $snapshot = Get-LogText -Path $combinedLog
        $match = [Regex]::Match($snapshot, $pattern)
        $windowText = if ($match.Success) { $snapshot.Substring($match.Index) } else { $snapshot }
        $lost = $windowText -match 'Lost connection to device'
        $wmClose = $windowText -match '\[runner\]\s*WM_CLOSE'
        $wmDestroy = $windowText -match '\[runner\]\s*WM_DESTROY'
        $alive20 = -not $proc.HasExited
    }
    if (-not $proc.HasExited) {
        Stop-ProcessTree -RootId $proc.Id
        $proc.WaitForExit()
    }
    Stop-WorkspaceRelated -Workspace $Workspace
    [pscustomobject]@{
        Run = $RunNumber
        BuiltAndReachedPrompt = $reachedPrompt
        LostConnectionDuringObservation = $lost
        RunnerWmCloseDuringObservation = $wmClose
        RunnerWmDestroyDuringObservation = $wmDestroy
        StayedAliveFullObservationWindow = $alive20
    }
}
$workspace = (Get-Location).Path
$results = for ($run = 1; $run -le 3; $run++) { Invoke-ObservedRun -RunNumber $run -Workspace $workspace }
$json = $results | ConvertTo-Json -Depth 4 -Compress
Set-Content -Path (Join-Path $workspace 'validate_runs_result.json') -Value $json
Write-Output $json
