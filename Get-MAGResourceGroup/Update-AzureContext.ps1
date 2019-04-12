   [CmdletBinding()]
    Param()

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
            $menuPrompt = "/" * (95)
            $menuPrompt += "`n`r////`n`r//// $Title`n`r////`n`r"
            $menuPrompt += "/" * (95)
            $menuPrompt += "`n`n"
        }
        ElseIf ($Style -eq "Mini") {
            #$menuPrompt = "`n"
            $menuPrompt = "\" * (80)
            $menuPrompt += "`n\\\\  $Title`n"
            $menuPrompt += "\" * (80)
            $menuPrompt += "`n"
        }
        ElseIf ($Style -eq "Info") {
            #$menuPrompt = "`n"
            $menuPrompt = "-" * (80)
            $menuPrompt += "`n-- $Title`n"
            $menuPrompt += "-" * (80)
        }
    
        #add the menu
        $menuPrompt+=$menu
    
        [System.Console]::ForegroundColor = $Color
        If ($DisplayOnly) {Write-Host $menuPrompt}
        Else {Read-Host -Prompt $menuprompt}
        [system.console]::ResetColor()
    }

    Write-Verbose "Getting Azure Subscriptions..."
    $Subs = Get-AzureRmSubscription | % {$_.Name}
    Write-Verbose ("Found {0} Azure Subscriptions" -f $Subs.Count)
    $SubSelection = (@"
"@)
    $SubRange = 1..($Subs.Count)
    For ($i = 1; $i -lt $Subs.Count;$i++) {$SubSelection += " [$i] $($Subs[$i])`n"}
    $SubSelection += "`n Please select a Subscription"

    Do{$SubChoice = Show-Menu -Title "Select an Azure Subscription" -Menu $SubSelection -Style Mini -Color Cyan}
    While (($SubRange -notcontains $SubChoice) -OR (-NOT $SubChoice.GetType().Name -eq "Int32"))
    
    Write-Verbose ("Updating Azure Subscription to: {0}" -f $Subs[$SubChoice])
    Select-AzureRmSubscription -Subscription $Subs[$SubChoice]