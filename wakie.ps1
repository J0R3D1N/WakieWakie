[cmdletbinding()]
Param()
Add-Type -Assembly PresentationFramework            
Add-Type -Assembly PresentationCore

$CheckRunspace = Get-Runspace -Name WakieWakie
If (($CheckRunspace | Measure).Count -ge 1) {
    $CheckRunspace | % {
        $_.Close()
        sleep -Milliseconds 500
        $_.Dispose()
    }
}

$script:syncHash = [hashtable]::Synchronized(@{})
$syncHash.Host = $Host
$syncHash.XAMLPath = Join-Path $PSScriptRoot '\WakieWakie'
$PathLIO = $PSCmdlet.MyInvocation.MyCommand.Source.LastIndexOf("\")
$ScriptPath = $PSCmdlet.MyInvocation.MyCommand.Source.Substring(0,$PathLIO)
$syncHash.ScriptModule = "$ScriptPath\wakiecommon.ps1"
$synchash.StopwatchTimeElapsed = [timespan]::Zero
$syncHash.CountdownIterations = 0

Write-Debug "stop"
$InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$Runspace = [runspacefactory]::CreateRunspace($InitialSessionState)
$Runspace.ThreadOptions = "ReuseThread"
$Runspace.ApartmentState = "STA"
$Runspace.Name = "WakieWakie"

$PowerShell = [powershell]::Create()
$PowerShell.Runspace = $Runspace

$Runspace.Open()
$Runspace.SessionStateProxy.SetVariable("syncHash",$syncHash)


[void]$PowerShell.AddScript({
    . $syncHash.ScriptModule
    $wpf = Get-ChildItem -Path $syncHash.XAMLPath -Filter *.xaml -File | Where-Object {$_.Name -ne "App.xaml"} | Get-XamlObject
    $wpf.GetEnumerator() | % {$script:syncHash.Add($_.Name,$_.Value)}

    $updateblock = {
        $CLStatus = [System.Console]::CapsLock
        $NLStatus = [System.Console]::NumberLock
        If ($CLStatus) {$syncHash.CLStatusIndicator.Background = "#FF0CD3FF"}
        Else {$syncHash.CLStatusIndicator.Background = "#FFD1D1D1"}

        If ($NLStatus) {$syncHash.NLStatusIndicator.Background = "#FF0CD3FF"}
        Else {$syncHash.NLStatusIndicator.Background = "#FFD1D1D1"}

        $synchash.ElapsedTime_lbl.Content = ("{0}:{1}:{2}.{3}" -f $syncHash.StopwatchTimeElapsed.Hours,$syncHash.StopwatchTimeElapsed.Minutes,$syncHash.StopwatchTimeElapsed.Seconds,$syncHash.StopwatchTimeElapsed.Milliseconds.ToString('D3'))
        $synchash.LoopCounter_lbl.Content = $syncHash.CountdownIterations
    }

    $timer = New-Object System.Windows.Threading.DispatcherTimer     
	$timer.Interval = [TimeSpan]::FromMilliseconds(1)
	$timer.Add_Tick($updateblock)
	$timer.Start()
	#if ($timer.IsEnabled) {$synchash.Host.ui.WriteVerboseLine('UI timer started')}
    
    #region Navigation buttons
    [Void]$syncHash.MainWindowFrame.NavigationService.Navigate($syncHash.Config)

    $syncHash.ConfigButtonNext.add_Click({
        $syncHash.MainWindowFrame.NavigationService.Navigate($syncHash.CleanUp)
    })

    $syncHash.CleanUpButtonBack.add_Click({
        $syncHash.MainWindowFrame.NavigationService.Navigate($syncHash.Config)
    })
    #endregion

    $syncHash.DurationTextBox.Add_TextChanged({
        $DurationCheck = Compare-Object -ReferenceObject $(1..30) -DifferenceObject ([int]$this.Text) -IncludeEqual -ExcludeDifferent
        If ($DurationCheck) {
            $synchash.DurationBorder.BorderBrush = "gray"
            $SyncHash.StopwatchMax = [timespan]::FromDays(5)
            $syncHash.TotalRuns = [Math]::Round($SyncHash.StopwatchMax.Ticks/([timespan]::FromMinutes($synchash.DurationTextBox.Text)).Ticks)
            $syncHash.MaximumLoops_lbl.Content = ("{0:N0}" -f $syncHash.TotalRuns)
            $synchash.btnStart.IsEnabled = $true
        }
        Else {
            $synchash.DurationBorder.BorderBrush = "red"
            $synchash.btnStart.IsEnabled = $false
        }
    })

    $syncHash.NLRadioButton.add_Checked({
        $syncHash.WakieKey = "NUMLOCK"
        $syncHash.KeySelectionBorder.BorderThickness = 0
    })

    $syncHash.CLRadioButton.add_Checked({
        $syncHash.WakieKey = "CAPSLOCK"
        $syncHash.KeySelectionBorder.BorderThickness = 0
    })

    $syncHash.btnStart.add_Click({
        If ($synchash.NLRadioButton.IsChecked -or $synchash.CLRadioButton.IsChecked) {
            $CountdownRunspace = Get-Runspace -Name Countdown
            If (($CountdownRunspace | Measure).Count -ge 1) {
                $CountdownRunspace | % {
                    $_.Close()
                    sleep -Milliseconds 500
                    $_.Dispose()
                }
            }
            Update-CountdownTimer -syncHash $synchash -Duration $synchash.DurationTextBox.Text
        }
        Else {$syncHash.KeySelectionBorder.BorderThickness = 2}
    })

    $syncHash.btnStop.add_Click({
        $CountdownRunspace = Get-Runspace -Name Countdown
        If (($CountdownRunspace | Measure).Count -ge 1) {
            $CountdownRunspace | % {
                $_.Close()
                sleep -Milliseconds 500
                $_.Dispose()
            }
        }
        $synchash.DurationTextBox.IsEnabled = $true
        $synchash.btnStart.IsEnabled = $true
    })

    [Void]$syncHash.Window.ShowDialog()

})

$AsyncObject = $PowerShell.BeginInvoke()
