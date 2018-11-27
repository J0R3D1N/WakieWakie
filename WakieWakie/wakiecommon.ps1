Function Send-Keys {
    [CmdletBinding()]
    Param ([ValidateSet("CAPSLOCK","NUMLOCK","SCROLLLOCK")]$Key)
    
    $Shell = New-Object -ComObject wscript.shell
    $Shell.SendKeys("{$Key}")
    Start-Sleep -Milliseconds 1999
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

Function Update-CountdownTimer {
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
    $job = $PSInstance.BeginInvoke()
}