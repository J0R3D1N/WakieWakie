<#
. [COPYRIGHT]
. © 2011-2018 Microsoft Corporation. All rights reserved. 
.
. [DISCLAIMER]
. This sample script is not supported under any Microsoft standard support
. program or service. The sample scripts are provided AS IS without warranty of
. any kind. Microsoft disclaims all implied warranties including, without
. limitation, any implied warranties of merchantability or of fitness for a
. particular purpose. The entire risk arising out of the use or performance of
. the sample scripts and documentation remains with you. In no event shall
. Microsoft, its authors, or anyone else involved in the creation, production,
. or delivery of the scripts be liable for any damages whatsoever (including,
. without limitation, damages for loss of business profits, business
. interruption, loss of business information, or other pecuniary loss) arising
. out of the use of or inability to use the sample scripts or documentation,
. even if Microsoft has been advised of the possibility of such damages.
.
. [AUTHOR]
. Jason Parker, Senior Consultant
. 
. [CONTRIBUTORS]
.
. 
. [MODULE]
. WakieWakie.psm1
.
. [VERSION]
. 1.0
.
. [VERSION HISTORY / UPDATES]
. 1.0 - Jason Parker
. Original Release 
.
#>

Function Global:Start-WakieWakie {
    <#
    .SYNOPSIS
    Launches the WakieWakie application

    .DESCRIPTION
    WPF XAML based application used to send Numlock or Capslock key presses on a specific interval to help keep system from going to sleep or standby.

    .EXAMPLE
    Launches the application

    Start-WakieWakie

    .NOTES
    #>
    [CmdletBinding()]
    Param()
    # Adds WPF Assemblies
    Add-Type -Assembly PresentationFramework            
    Add-Type -Assembly PresentationCore

    # Clean up previous runspace
    $CheckRunspace = Get-Runspace -Name WakieWakie
    If (($CheckRunspace | Measure-Object).Count -ge 1) {
        $CheckRunspace | ForEach-Object {
            $_.Close()
            Start-Sleep -Milliseconds 500
            $_.Dispose()
        }
    }

    # Create a Hashtable that will span across multiple runspaces
    $Script:syncHash = [hashtable]::Synchronized(@{})
    $syncHash.Host = $Host

    # Prevents hard coding the XAML Path
    $ModulePath = (Get-Module -ListAvailable WakieWakie).Path
    $ModulePathLIO = $ModulePath.LastIndexOf("\")
    $syncHash.XAMLPath = ("{0}\XAML" -f $ModulePath.Substring(0,$ModulePathLIO))

    #$syncHash.XAMLPath = Join-Path $PSScriptRoot '\WakieWakie'
    #$PathLIO = $PSCmdlet.MyInvocation.MyCommand.Source.LastIndexOf("\")
    #$ScriptPath = $PSCmdlet.MyInvocation.MyCommand.Source.Substring(0,$PathLIO)
    #$syncHash.ScriptModule = "$ScriptPath\wakiecommon.ps1"

    $synchash.StopwatchTimeElapsed = [timespan]::Zero
    $syncHash.CountdownIterations = 0

    #$InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    #$Runspace = [runspacefactory]::CreateRunspace($InitialSessionState)

    # Create, Configure, and Open Runspace for the Main UI
    $Runspace.ThreadOptions = "ReuseThread"
    $Runspace.ApartmentState = "STA"
    $Runspace.Name = "WakieWakie"

    $PowerShell = [powershell]::Create()
    $PowerShell.Runspace = $Runspace

    $Runspace.Open()
    $Runspace.SessionStateProxy.SetVariable("syncHash",$syncHash) # Adds the sync'd Hashtable to runspace


    [void]$PowerShell.AddScript({
        #. $syncHash.ScriptModule
        #$wpf = Get-ChildItem -Path $syncHash.XAMLPath -Filter *.xaml -File | Where-Object {$_.Name -ne "App.xaml"} | Get-XamlObject

        # Loads the XAML content into $wpf variable then adds all the properties from the XAML to the $syncHash
        $wpf = Get-ChildItem -Path $syncHash.XAMLPath -Filter *.xaml -File | Get-XamlObject
        $wpf.GetEnumerator() | ForEach-Object {$script:syncHash.Add($_.Name,$_.Value)}

        # Scriptblock executed during every iteration of the UI Timer which is what updates the Main portions of the UI for responsiveness
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

        # Creates the UI timer
        $UItimer = New-Object System.Windows.Threading.DispatcherTimer     
        $UItimer.Interval = [TimeSpan]::FromMilliseconds(1)
        $UItimer.Add_Tick($updateblock)
        $UItimer.Start()
        
        # Sets the MainWindow Frame object to load the Config.xaml page
        [Void]$syncHash.MainWindowFrame.NavigationService.Navigate($syncHash.Config)
        
        $syncHash.DurationTextBox.Add_TextChanged({
            # Validation check that the duration is a number between 1 and 30
            $DurationCheck = Compare-Object -ReferenceObject $(1..30) -DifferenceObject ([int]$this.Text) -IncludeEqual -ExcludeDifferent
            If ($DurationCheck) {
                $synchash.DurationBorder.BorderBrush = "gray"

                # Configurable option to determine the maximum run time
                $SyncHash.StopwatchMax = [timespan]::FromDays(5) 
                
                # Based on the duration, determines how many loops will be executed across the maximum run time
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
            $syncHash.KeySelectionBorder.BorderThickness = 0 # Clears the border when the radio button is checked
        })

        $syncHash.CLRadioButton.add_Checked({
            $syncHash.WakieKey = "CAPSLOCK"
            $syncHash.KeySelectionBorder.BorderThickness = 0 # Clears the border when the radio button is checked
        })

        $syncHash.btnStart.add_Click({
            # Validates that a key selection has been made
            If ($synchash.NLRadioButton.IsChecked -or $synchash.CLRadioButton.IsChecked) {
                # Cleans up any previous Countdown runspaces
                $CountdownRunspace = Get-Runspace -Name Countdown
                If (($CountdownRunspace | Measure-Object).Count -ge 1) {
                    $CountdownRunspace | ForEach-Object {
                        $_.Close()
                        Start-Sleep -Milliseconds 500
                        $_.Dispose()
                    }
                }
                New-CountdownTimer -syncHash $synchash -Duration $synchash.DurationTextBox.Text
            }
            Else {$syncHash.KeySelectionBorder.BorderThickness = 2} # Sets the key selection border to red if no option was checked
        })

        $syncHash.btnStop.add_Click({
            # Cleans up any previous Countdown runspaces
            $CountdownRunspace = Get-Runspace -Name Countdown
            If (($CountdownRunspace | Measure-Object).Count -ge 1) {
                $CountdownRunspace | ForEach-Object {
                    $_.Close()
                    Start-Sleep -Milliseconds 500
                    $_.Dispose()
                }
            }
            $synchash.DurationTextBox.IsEnabled = $true
            $synchash.btnStart.IsEnabled = $true
        })

        # Launches the window
        [Void]$syncHash.Window.ShowDialog()

    })

    [Void]$PowerShell.BeginInvoke()
    #$AsyncObject = $PowerShell.BeginInvoke()
}

Function Send-Keys {
    [CmdletBinding()]
    Param ([ValidateSet("CAPSLOCK","NUMLOCK","SCROLLLOCK")]$Key)
    
    $Shell = New-Object -ComObject wscript.shell
    $Shell.SendKeys("{$Key}")
    Start-Sleep -Milliseconds 500
    $Shell.SendKeys("{$Key}")
}

Function Get-XamlObject {
	[CmdletBinding()]
	param(
		[Parameter(Position = 0,
			Mandatory = $true,
			ValuefromPipelineByPropertyName = $true,
			ValuefromPipeline = $true)]
		[Alias("FullName")]
		[System.String[]]$Path
	)

	BEGIN
	{
		Set-StrictMode -Version Latest
		$expandedParams = $null
		$PSBoundParameters.GetEnumerator() | ForEach-Object { $expandedParams += ' -' + $_.key + ' '; $expandedParams += $_.value }
		Write-Verbose "Starting: $($MyInvocation.MyCommand.Name)$expandedParams"
		$output = @{ }
		Add-Type -AssemblyName presentationframework, presentationcore
	} #BEGIN

	PROCESS {
		try
		{
			foreach ($xamlFile in $Path)
			{
				#Wait-Debugger
				#Change content of Xaml file to be a set of powershell GUI objects
				$inputXML = Get-Content -Path $xamlFile -ErrorAction Stop
				[xml]$xaml = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace 'x:Class=".*?"', '' -replace 'd:DesignHeight="\d*?"', '' -replace 'd:DesignWidth="\d*?"', ''
				$tempform = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml -ErrorAction Stop))

				#Grab named objects from tree and put in a flat structure using Xpath
				$namedNodes = $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")
				$namedNodes | ForEach-Object {
					$output.Add($_.Name, $tempform.FindName($_.Name))
				} #foreach-object
			} #foreach xamlpath
		} #try
		catch
		{
			throw $error[0]
		} #catch
	} #PROCESS

	END
	{
		Write-Output $output
		Write-Verbose "Finished: $($MyInvocation.Mycommand)"
	} #END
}

Function New-CountdownTimer {
    Param($syncHash,$Duration)
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ApartmentState = "STA"
    $Runspace.ThreadOptions = "ReuseThread"
    $Runspace.Name = "Countdown"
    $Runspace.Open()
    $Runspace.SessionStateProxy.SetVariable("syncHash",$syncHash)
    $Runspace.SessionStateProxy.SetVariable("Duration",$Duration)

    $code = {
        #$syncHash.Host.UI.WriteVerboseLine("code begin")
        $syncHash.Window.Dispatcher.Invoke([action]{
            $syncHash.DurationTextBox.IsEnabled = $false
            $syncHash.btnStart.IsEnabled = $false
        })

        $Shell = New-Object -ComObject wscript.shell
        $DurationTimespan = [timespan]::FromMinutes($Duration)

        $StopWatch = New-Object System.Diagnostics.Stopwatch
        $StopWatch.Start()

        #$synchash.Host.UI.WriteVerboseLine("start stopwatch")
        $synchash.Flag = $true
        $i = 1
        Do {
            $synchash.StopwatchTimeElapsed = $StopWatch.Elapsed
            $syncHash.CountdownIterations = $i

            If ($StopWatch.Elapsed.TotalMinutes -ge $DurationTimespan.TotalMinutes) {
                
                $Shell.SendKeys("{$($synchash.WakieKey)}")
                Start-Sleep -Milliseconds 500
                $Shell.SendKeys("{$($synchash.WakieKey)}")
                
                #Send-Keys -Key $syncHash.WakieKey
                $syncHash.Flag = $false
                $StopWatch.Restart()
                $i++
            }

            Start-Sleep -Milliseconds 50
        } Until ($syncHash.Flag -eq $false -and $syncHash.CountdownIterations -eq $syncHash.TotalRuns)
        $StopWatch.Stop()
        #$synchash.Host.UI.WriteVerboseLine("stop stopwatch")

        $syncHash.Window.Dispatcher.Invoke([action]{
            $syncHash.DurationTextBox.IsEnabled = $true
            $syncHash.btnStart.IsEnabled = $true
        })
        #$synchash.Host.UI.WriteVerboseLine("code end")
    }

    $PSInstance = [powershell]::Create().AddScript($code)
    $PSInstance.runspace = $Runspace
    #$job = $PSInstance.BeginInvoke()
    [Void]$PSInstance.BeginInvoke()
}