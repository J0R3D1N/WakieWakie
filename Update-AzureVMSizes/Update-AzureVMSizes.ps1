Function Update-AzureVMSize {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact="Low")]
    Param()
    BEGIN {
        try {
            $Error.Clear()
            Function Get-FileNameDialog {
                Param (
                    $InitialDirectory,
                    [ValidateSet("CSV","TXT")]
                    $FileType
                )
                [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
                $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
                $OpenFileDialog.initialDirectory = $InitialDirectory
                If ($FileType -eq "CSV") {$OpenFileDialog.filter = "CSV files (*.csv)| *.csv| All files (*.*)| *.*"}
                ElseIf ($FileType -eq "TXT") {$OpenFileDialog.filter = "Text files (*.txt)| *.txt| All files (*.*)| *.*"}
                Else {$OpenFileDialog.filter = "CSV files (*.csv)| *.csv| Text files (*.txt)| *.txt| All files (*.*)| *.*"}
                $OpenFileDialog.ShowDialog() | Out-Null
                $File = $OpenFileDialog.filename
                Return $File
            }
           Function Show-Menu {
                Param(
                    [string]$Menu,
                    [string]$Title = $(Throw [System.Management.Automation.PSArgumentNullException]::new("Title")),
                    [switch]$ClearScreen,
                    [Switch]$DisplayOnly,
                    [ValidateSet("Full","Mini","Info")]
                    $Style = "Full",
                    [ValidateSet("White","Cyan","Magenta","Yellow","Green","Red","Gray","DarkGray")]
                    $Color = "Gray"
                )
                if ($ClearScreen) {[System.Console]::Clear()}
    
                If ($Style -eq "Full") {
                    #build the menu prompt
                    $menuPrompt = "`n"
                    $menuPrompt = "/" * (95)
                    $menuPrompt += "`n`r////`n`r//// $Title`n`r////`n`r"
                    $menuPrompt += "/" * (95)
                    $menuPrompt += "`n`n"
                }
                ElseIf ($Style -eq "Mini") {
                    $menuPrompt = "`n"
                    $menuPrompt = "\" * (80)
                    $menuPrompt += "`n\\\\  $Title`n"
                    $menuPrompt += "\" * (80)
                    $menuPrompt += "`n"
                }
                ElseIf ($Style -eq "Info") {
                    $menuPrompt = "`n"
                    $menuPrompt = "-" * (80)
                    $menuPrompt += "`n-- $Title`n"
                    $menuPrompt += "-" * (80)
                }
    
                #add the menu
                $menuPrompt+=$menu
    
                [System.Console]::ForegroundColor = $Color
                If ($DisplayOnly) {Write-Host $menuPrompt}
                Else {Read-Host -Prompt $menuprompt}
                [System.Console]::ResetColor()
            }
            Function Get-PSJobStatus {
                Param(
                    [Int]$RefreshInterval = 5,
                    [Int]$RequiredJobs,
                    [Int]$MaximumJobs = $RequiredJobs
               )
                While (@(Get-Job -State "Running").Count -ne 0) {
                Clear-Host
                $JobsHashtable = Get-Job | Select Name,State | Group State -AsHashTable -AsString
                $CurrentJobs = (Get-Job | Measure).Count
                $RunningJobs = $JobsHashtable["Running"].Count
                $CompletedJobs = $JobsHashtable["Completed"].Count
                $FailedJobs = $JobsHashtable["Failed"].Count
                $BlockedJobs = $JobsHashtable["Blocked"].Count
                $JobsLeftInCurrent = $CurrentJobs - ($CompletedJobs + $RunningJobs + $FailedJobs + $BlockedJobs)
                $RemainingJobs = $RequiredJobs - $CurrentJobs
                [System.Collections.Arraylist]$RunningJobStatus = @()
                
                $Status = ("{0} OF {1} JOBS CREATED - MAXIMUM JOBS SET TO {2}" -f $CurrentJobs,$RequiredJobs,$MaximumJobs)
                Show-Menu -Title "All Background Jobs have been submitted!" -DisplayOnly -Style Mini -Color White
                Show-Menu -Title $Status -DisplayOnly -Style Info -Color Yellow

                Write-Host " >>" -NoNewline; Write-Host " $RemainingJobs " -NoNewline -ForegroundColor DarkGray; Write-Host "Jobs Remaining" -ForegroundColor DarkGray
                Write-Host " >>" -NoNewline; Write-host " $CurrentJobs " -NoNewline -ForegroundColor White; Write-Host "Total Jobs Created" -ForegroundColor White
                Write-Host " >>" -NoNewline; Write-Host " $RunningJobs " -NoNewline -ForegroundColor Cyan; Write-Host "Jobs In Progress" -ForegroundColor Cyan
                Write-Host " >>" -NoNewline; Write-Host " $CompletedJobs " -NoNewline -ForegroundColor Green; Write-Host "Jobs Completed" -ForegroundColor Green
                Write-Host " >>" -NoNewline; Write-Host " $BlockedJobs " -NoNewline -ForegroundColor Yellow; Write-Host "Jobs Blocked" -ForegroundColor Yellow
                Write-Host " >>" -NoNewline; Write-Host " $FailedJobs " -NoNewline -ForegroundColor Red; Write-Host "Jobs Failed" -ForegroundColor Red

                $Jobs = Get-Job | Group-Object State -AsHashTable -AsString
                foreach ($Job in $Jobs["Running"]) {
                    $JobName = $Job.Name
                    $JobDuration = ($Job.PSBeginTime - (Get-Date)).Negate()
                                         
                    $objJob = [PSCustomObject][Ordered]@{
                        JobName = ("{0}    " -f $JobName)
                        ElapsedTime = ("{0:N0}.{1:N0}:{2:N0}:{3:N0}" -f $JobDuration.Days,$JobDuration.Hours,$JobDuration.Minutes,$JobDuration.Seconds)
                        JobStatus = "Virtual Machine Resize in Progress"
                    }
                    [Void]$RunningJobStatus.Add($objJob)
                }

                If ($RunningJobStatus) {
                    Show-Menu -Title "Job Status" -DisplayOnly -Style Info -Color Cyan
                    $RunningJobStatus | Sort 'JobName' -Descending | Format-Table -AutoSize | Out-Host
                }
                Else {Show-Menu -Title "Waiting for Jobs to Start" -DisplayOnly -Style Info -Color Gray}

                Write-Host "`n`rNext refresh in " -NoNewline
                Write-Host $RefreshInterval -ForegroundColor Magenta -NoNewline
                Write-Host " Seconds"
                Start-Sleep -Seconds $RefreshInterval
            }
        } 
            Function Get-PSJobReport {
                [CmdletBinding()]
                Param()
                [System.Collections.ArrayList]$CompletedJobStatus = @()
                Foreach ($Job in @(Get-Job -State Completed)) {
                    $JobDuration = $Job.PSEndTime -$Job.PSBeginTime
                    $JobResults = ("{0}: {1}" -f $Job.Command,$Job.Output.StatusCode)
                                                                     
                    $objJob = [PSCustomObject][Ordered]@{
                        JobName = ("{0}    " -f $Job.Name)
                        ElapsedTime = ("{0:N0}.{1:N0}:{2:N0}:{3:N0}" -f $JobDuration.Days,$JobDuration.Hours,$JobDuration.Minutes,$JobDuration.Seconds)
                        CompletedTimeStamp = $Job.PSEndTime
                        JobStatus = $Job.StatusMessage
                        JobResults = $JobResults
                    }

                    [Void]$CompletedJobStatus.Add($objJob)
                }
                Return $CompletedJobStatus
            }
            
            Show-Menu -Title "Function:  Update-AzureVMSize" -ClearScreen -DisplayOnly -Style Full -Color White

            Write-Verbose ("Opening File Dialog for CSV file selection...")
            $Importfile = Get-FileNameDialog -FileType CSV
            $VMResizeGroups = Import-Csv $Importfile | Group-Object Group -AsHashTable -AsString
        }
        catch {$PSCmdlet.ThrowTerminatingError($PSItem)}        
    }
    PROCESS {
        try {
            Do {
                $Groups = $VMResizeGroups.Keys | Sort | % {$_}
                Write-Verbose ("Found {0} Resize Groups" -f $VMResizeGroups.Keys.Count)
                $GroupSelection = (@"
`n
"@)
                $GroupRange = 0..($Groups.Count - 1)
                For ($i = 0; $i -lt $Groups.Count; $i++) {
                    $Key = $Groups[$i]
                    $GroupSelection += (" [{0}] VM Resize Group {1} (VMs: {2})`n" -f $i,$Groups[$i],$VMResizeGroups["$key"].Count)
                }
                $GroupSelection += " [C] Cancel`n"
                $GroupSelection += "`n Please select a VM Resize Group"
    
                Do {$GroupChoice = Show-Menu -Title "Select a VM Resize Group" -Menu $GroupSelection -Style Mini -Color Cyan}
                Until (($GroupRange -contains $GroupChoice -OR $GroupRange -eq $GroupChoice) -OR ($GroupChoice.ToUpper() -eq "C"))
    
                If ($GroupChoice.ToUpper() -eq "C") {
                    Write-Warning "User cancelled the operation!"
                    Break
                }
                
                Write-Verbose ("Current VM Resize Group Selected: Group {0}" -f $Groups[$GroupChoice])
    
                If ($PSCmdlet.ShouldProcess(("{0} Virtual Machines in Group {1}" -f $VMResizeGroups["$($Groups[$GroupChoice])"].Count,$Groups[$GroupChoice]))) {
                    Write-Verbose ("Clearing Previous PS Jobs")
                    Get-Job PSJob-* | Remove-Job -Confirm:$false
                    Foreach ($VM in $VMResizeGroups["$($Groups[$GroupChoice])"]) {
                        Write-Verbose ("Connecting to the Virtual Machines Azure Subscription")
                        Select-AzureRmSubscription -Subscription $VM.Subscription -Confirm:$false -Debug:$false | Out-Null
                        Write-Verbose ("[{0}] - Getting VM Properties" -f $VM.Name)
                        $AzureVM = Get-AzureRmVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -Debug:$false
                        Write-Debug "check"
                        If ($AzureVM.HardwareProfile.VmSize -eq $VM.Size) {
                            $AzureVM.HardwareProfile.VmSize = $VM.TargetSize
                            Write-Verbose ("[{0}] - Starting VM Resize (Current: {1} | Target: {2})" -f $VM.Name,$VM.size,$VM.TargetSize)
                            $InitialJob = Update-AzureRmVM -VM $AzureVM -ResourceGroupName $VM.ResourceGroupName -AsJob
                            $InitialJob.Name = ("PSJob-{0}" -f $VM.Name)
                        }
                        Else {Write-Warning ("[{0}] - VM matches the Target Size ({1})" -f $VM.Name,$VM.TargetSize)}
                    }
    
                    If (@(Get-Job).Count -gt 0) {
                        Read-Host "Press any key to monitor the background jobs"
    
                        Get-PSJobStatus -RefreshInterval 5 -RequiredJobs $VMResizeGroups["$($Groups[$GroupChoice])"].Count
    
                        Get-PSJobReport | Format-Table -AutoSize
                    }
                    
                    $VMResizeGroups.Remove("$($Groups[$GroupChoice])")
                    If ($VMResizeGroups.Keys.Count -gt 0) {
                        Read-Host "Press any key to perform resize operation on another group"
                    }
                    
                }
                Else {Write-Warning "User cancelled the operation!"}    
            }
            Until ($VMResizeGroups.Keys.Count -eq 0)  
        }
        catch {$PSCmdlet.ThrowTerminatingError($PSItem)}
    }
}