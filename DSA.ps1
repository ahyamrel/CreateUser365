<#
Created By: Mariel Borodkin
Created Date: 28/9/2019

.PARAMETER 
None. Params required should be added in script

.EXAMPLE
.\dsa.ps1
#>

# Params required from user
$allConventions = "All-","Test-", "Cloud-", "Proj-", "SharedMailbox-"

#region Variables

$ErrorActionPreference = "continue"

<# Constant Variables #>
# Action colors
Set-Variable -Name COLOR_ERROR         -Value red      -Option Constant
Set-Variable -Name COLOR_WARNING       -Value yellow   -Option Constant
Set-Variable -Name COLOR_SUCCESS       -Value green    -Option Constant
Set-Variable -Name COLOR_MESSAGE       -Value darkblue -Option Constant

# Exit code
Set-Variable -Name EXIT_ERROR          -Value 1        -Option Constant
Set-Variable -name EXIT_UNAUTHORIZED   -Value 5        -Option Constant
Set-Variable -Name EXIT_USER_LEFT      -Value 6        -Option Constant
Set-Variable -Name EXIT_NO_MODULE      -Value 7        -Option Constant

$ErrorActionPreference = "stop"
Clear-Host
#endregion .. Variables

#region Prerequisites   
if ($null -eq (Get-Module -ListAvailable -Name AzureAD)) {
    try {
        Install-Module AzureAD -Confirm:$False -Force
    } catch {
        Write-Host "Prompting admin allow to install module" -ForegroundColor $COLOR_MESSAGE
        Start-Process powershell.exe -Verb Runas -ArgumentList "-Command {Install-Module AzureAD -Confirm:$False -Force}"
    } finally {
        if (($null -eq (Get-Module -ListAvailable -Name AzureAD))) {
           
            Write-Host "** ERROR: You need to install modules before you continue.. Exiting script ERROR CODE $($EXIT_NO_MODULE)" -ForegroundColor $COLOR_ERROR
            exit ($EXIT_NO_MODULE)
        }
    }
}

Write-Host "Prompting authentication for AD User." -ForegroundColor $COLOR_MESSAGE
Connect-AzureAD
        
#endregion .. Prerequisites    

# Initiation of all conventions
$convDirectory = @{}
$allConventions | ForEach-Object {
    $obj = Get-AzureADGroup -All $true -SearchString "$_"
    $convDirectory.Add($_, $obj)
}

#region Display GridView
# Display of the first graph
$convChoice = $convDirectory.Keys | Sort-Object | Out-GridView -Title "DSA - Organization Conventions" -OutputMode Single

while ($convChoice) {
    if ($convDirectory.item($convChoice)) {
        $groupId = $convDirectory.item($convChoice) | Select-Object DisplayName, Description, ObjectID| Out-GridView -Title "DSA Convention: $($convChoice)" -OutputMode Single
        while ($groupID) {
            Clear-Host
            $ADGroup = Get-AzureADGroupMember -ObjectId $groupID.ObjectID
            if ($ADGroup) {
                $ADGroup | Select-Object -Property displayname, mailnickname, Mail| Out-GridView -Title "Group: $($groupID.displayname) - Count: $($ADGroup.Count)" -PassThru
            } else {
                Write-Host "Group: $($groupID.displayname) is empty" -ForegroundColor Yellow
            }
            
            $groupID = $convDirectory.item($convChoice) | Out-GridView -Title "DSA - $($convChoice)" -OutputMode Single
        }

        $convChoice = $convDirectory.Keys |  Out-GridView -Title "DSA - Organization Conventions" -OutputMode Single
    } else {
        $convChoice = $convDirectory.Keys |  Out-GridView -Title "DSA - $($convChoice) was not found" -OutputMode Single
    }
}

#endregion Display GridView