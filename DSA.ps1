<#
Created By: Mariel Borodkin
Created Date: 28/9/2019

.SYNOPSIS
    Display GUI representing the organization hierarchy.
.DESCRIPTION
    Script going over the inserted conventions, pulling all groups relevant to them
    and returning the membership of each group.
.EXAMPLE
.\dsa.ps1
.LINK
    Forums: 
    Git:        https://github.com/ahyamrel/CreateUser365
#>

<# Conventions - Required from user
    All-      Group represents Department, for example HR.
    Licenses- Group represents all licensed members, for example Office365.
    Proj-     Group represents a specific Project group (can mix different All- groups).
    Rule-     Group represents rules/policies applied for specific members, for example Conditional Accesses.
    Test-     Group represents users for tests on before implement on all. Good as pre-prod tests.
    Intune-   Group represents devices/users relevant to Intune, for example Intune-Android.
    Cloud-    Group represents users from other clouds 
#>
$allConventions = "All-", "Licenses-", "Proj-", "Rule-", "Test-", "Cloud-",  "Intune-"

<# ^ CHANGE CONVENTIONS BASED ON YOUR ORGANIZATION ^ #>

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
        Install-Module AzureAD -Force
    } catch {
        Read-Host -Prompt "Module missing. Prompting admin permission request to run: `
        Install-Module AzureAD -Force `
        press ENTER to continue"
        Start-Process powershell.exe -Verb Runas -ArgumentList "Install-Module AzureAD -Force"
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
$convChoice = $convDirectory.Keys | Sort-Object | Out-GridView -Title "DSA - Organization Conventions" -OutputMode Single

while ($convChoice) {
    if ($convDirectory.item($convChoice)) {
        $groupId = $convDirectory.item($convChoice) | Select-Object DisplayName, Description, ObjectID| Out-GridView -Title "DSA Convention: $($convChoice)" -OutputMode Single
        while ($groupID) {
            Clear-Host
            $ADGroup = Get-AzureADGroupMember -ObjectId $groupID.ObjectID -All $true
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

#endregion .. Display GridView