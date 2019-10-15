<#
Created By: Mariel Borodkin
Created Date: 10/8/2019

.SYNOPSIS
    Creates 365 Users from Excel table
.DESCRIPTION
    Script running and configuring the AD, Office and Exchange mail.
.PARAMETER XLSXFilePath
    -XLSXFilePath "<EXCELPATH>" #Enter the path of the Excel file containing users to create
.EXAMPLE
    CreateUser365.ps1 c:\temp\Project Users.xlsx
    OR
    CreateUser365.ps1 "c:\temp\Project Users.xlsx"
.LINK
    Forums: 
    Git:            https://github.com/ahyamrel/CreateUser365
    Excel Template: https://1drv.ms/x/s!AkZyvbMPcBA_gRkE85dPazE1vxv4
#>

#region Param
param(
    [Parameter(Mandatory,Position=0)]
    [ValidateScript({
        $path = $_.Replace('"',"")
        if (-Not (Test-Path $path)) {
            throw "File not found"
        }
        elseif (-Not ($path.split(".") -eq "xlsx") ){
            throw "File is not an Excel file (.xlsx)"
        } else {
            return ($true)
        }
    })]
    [string]$XLSXFilePath
)

$XLSXFilePath = $XLSXFilePath.Replace('"',"")

#endregion Param

#region Input from user
Set-Variable -Name domain            -Value "" -Option AllScope
Set-Variable -Name LICENSE_OFFICE365 -Value "" -Option AllScope
Set-Variable -Name LICENSE_EMSE3     -Value "" -Option AllScope

#region Functions

<# Function to write logs and outputs to console #>
Function LogWrite{
   Param (
        [Parameter(Mandatory=$true)][string]$logstring,
        [string]$color,
        [bool]$bWriteToLog
   )
   if ($color) {
        Write-Host $logstring -ForegroundColor $color
   } else {
        Write-Host $logstring
   }

   if ($bWriteToLog) {
        $logstring | Out-File -FilePath $Logfile -Append -Force
   }
}

<# Function to pompt Input box #>
Function InputBox {
    param(

        # Messagebox title
        [Parameter(Mandatory,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $title,

        # Messagebox message
        [Parameter(Mandatory,Position=1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $msg
    )

    [void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
    $text = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)

    return ($text)
}

<# Function to promt Yes or No box #>
Function YesNoBox {
    param(

        # Messagebox title
        [Parameter(Mandatory,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $title,

        # Messagebox message
        [Parameter(Mandatory,Position=1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $msg
    )

    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    $result = [System.Windows.Forms.MessageBox]::Show($msg , $title , 4)
    if ($result -eq 'Yes') {
        return 1
    } else {
        return 0
    }
}

<# Function to Check LicenseGroup existence #>
Function GetLicenseGroup {
    param(
        # Messagebox title
        [Parameter(Mandatory,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $GroupName
    )

    $LICENSE_OFFICE = ""
    while (-not $LICENSE_OFFICE) {
        $LICENSE_OFFICE = InputBox -title "$($Groupname) license inherit Group Name or ObjectID" -msg "Enter Group name or ObjectID:"
        $group = Get-AzureADGroup -SearchString $LICENSE_OFFICE

        if (-not $group) { $group = Get-AzureADGroup -ObjectId $LICENSE_OFFICE } 

        if ($group.count -ne 1) {
            LogWrite -logstring "Group $($LICENSE_OFFICE) was not found or found one than one group. Please check yourself." -color $COLOR_MESSAGE -bWriteToLog $false
            $LICENSE_OFFICE = ""
        } else {
            $LICENSE_OFFICE = $group.objectid
        }
    }

    return ($LICENSE_OFFICE)
}

<# Function to Authenticate for user settings #>
Function Authenticate {
    try {
        $tempvar = Get-AzureADTenantDetail 
    } catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] {
        if ((YesNoBox -title "MFA Authentication" -msg "Is your script running account using MFA for authentication?") -eq 0) {
            Write-Host "Insert your credentials`
            1. Azure Active Directory `
            2. Office 365 service `
            3. Exchange Online powershell" -ForegroundColor $COLOR_WARNING
            $UserCredential = Get-Credential
            try {
                Connect-AzureAD -Credential $UserCredential
                Connect-MsolService -Credential $UserCredential
                $a= New-ExoPSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential
                Import-PSSession $a -AllowClobber
            } catch {
                LogWrite -logstring "** ERROR: Authentication failed due to wrong password/MFA requirements - Existing script ERROR CODE $($EXIT_UNAUTHORIZED)" -color $COLOR_ERROR -bWriteToLog $true
            }
        } else { # Case user has MFA and need to insert credentials by his own
            Clear-Host
            Write-Host "Bring your MFA device on! Authentication manually for the following services: `
            1. Azure Active Directory `
            2. Office 365 service `
            3. Exchange Online powershell" -ForegroundColor Yellow
            Connect-AzureAD
            Connect-MsolService
            $a= New-ExoPSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/
            Import-PSSession $a -ErrorAction SilentlyContinue
        }
    }

    if (($null -eq (Get-AzureADCurrentSessionInfo)) -or ($null -eq (Get-PSSession | Where-Object {$_.ConfigurationName -eq "Microsoft.Exchange" -and $_.State -eq "Opened"}))) {
        LogWrite -logstring "** ERROR: Authentication for services failed - Existing script ERROR CODE $($EXIT_UNAUTHORIZED)" -color $COLOR_ERROR -bWriteToLog $true
        exit ($EXIT_UNAUTHORIZED)
    }
    
} 

#endregion .. Functions

#region Variables

<# Global Variables #>

# Logfile
$date = (get-date -Format o).split('.')[0]
$date = $date.Replace('T',' ')
$date = $date.Replace(':','-')

Set-Variable -Name userPath       -Value $XLSXFilePath                                      -Option AllScope
Set-Variable -Name Logfile        -Value "$($env:USERPROFILE)\365 Create\Time $($date).txt" -Option AllScope
Set-Variable -Name USAGE_LOCATION -Value IL                                                 -Option AllScope

<# Constant Variables #>
$ErrorActionPreference = "continue"

Set-Variable -Name LOG_SPLIT           -Value "*****************************************************************************" -Option Constant

# Error codes
Set-Variable -Name EXIT_SUCCESS        -Value 0        -Option Constant
Set-Variable -Name EXIT_ERROR          -Value 1        -Option Constant
Set-Variable -Name EXIT_PATH_NOT_FOUND -Value 2        -Option Constant
Set-Variable -Name EXIT_NO_INTERNET    -Value 4        -Option Constant
Set-Variable -name EXIT_UNAUTHORIZED   -Value 5        -Option Constant
Set-Variable -Name EXIT_USER_LEFT      -Value 6        -Option Constant
Set-Variable -Name EXIT_NO_MODULE      -Value 7        -Option Constant

# Action colors
Set-Variable -Name COLOR_ERROR         -Value red      -Option Constant
Set-Variable -Name COLOR_WARNING       -Value yellow   -Option Constant
Set-Variable -Name COLOR_SUCCESS       -Value green    -Option Constant
Set-Variable -Name COLOR_MESSAGE       -Value darkblue -Option Constant

$ErrorActionPreference = "stop"
New-Item $logFile -ItemType file -Force -InformationAction SilentlyContinue
Clear-Host
#endregion .. Variables

#region Log file init
LogWrite -logstring $LOG_SPLIT -color $COLOR_MESSAGE -bWriteToLog $true
LogWrite -logstring "Logfile location: $($Logfile)" -color $COLOR_MESSAGE -bWriteToLog $true
LogWrite -logstring "Started Processing at [$($date)]" -color $COLOR_MESSAGE -bWriteToLog $true
LogWrite -logstring "$($LOG_SPLIT)" -color $COLOR_MESSAGE -bWriteToLog $true
#endregion .. Log file init

#region Prerequisites

    #region Internet Connectivity
if (!(Test-Connection 8.8.8.8 -Count 3 -ErrorAction SilentlyContinue)) {
    LogWrite -logstring "ERROR: Internet connection required for script - Exiting script ERROR CODE $($EXIT_NO_INTERNET)" -color $COLOR_MESSAGE -bWriteToLog $true
    exit ($EXIT_NO_INTERNET)
}
    #endregion .. Internet Connectivity

    #region Modules installation
if (($null -eq (Get-Module -ListAvailable -Name AzureAD)) -or ($null -eq (Get-Module -ListAvailable -Name MSOnline)) -or ($null -eq (Get-Module -ListAvailable -Name PSExcel)) -or ($null -eq (Get-Module -ListAvailable -Name Microsoft.Exchange.Management.ExoPowershellModule))) {
    try {
        Install-Module AzureAD -Confirm:$False -Force
        Install-Module MSOnline -Confirm:$False -Force
        Install-Module PSExcel -Confirm:$False -Force
        Install-Module -Name Microsoft.Exchange.Management.ExoPowershellModule
    } catch {
        Write-Host "Approve running the following commands in evaluated Powershell Cmdlet: `
        Install-Module AzureAD -Confirm:$False -Force `
        Install-Module MSOnline -Confirm:$False -Force `
        Install-Module PSExcel -Confirm:$False -Force `
        Install-Module -Name Microsoft.Exchange.Management.ExoPowershellModule" -ForegroundColor $COLOR_WARNING
        Start-Process powershell.exe -Verb Runas -ArgumentList "Install-Module AzureAD -Force;Install-Module MSOnline -Force; Install-Module PSExcel -Force; Install-Module -Name Microsoft.Exchange.Management.ExoPowershellModule -Force"
        Read-Host "Press Enter AFTER the admin console installed modules required as admin"
    } finally {
        Import-Module PSExcel
        if (($null -eq (Get-Module -ListAvailable -Name AzureAD)) -or ($null -eq (Get-Module -ListAvailable -Name MSOnline)) -or ($null -eq (Get-Module -ListAvailable -Name PSExcel))) {
            LogWrite -logstring "** ERROR: You need to install modules before you continue.. Exiting script ERROR CODE $($EXIT_NO_MODULE)" -color $COLOR_ERROR -bWriteToLog $true
            exit ($EXIT_NO_MODULE)
        }
    }
}
    #endregion .. Modules installation

    #region Check fields of data
if (-not ($domain -and $LICENSE_OFFICE365 -and $LICENSE_EMSE3)) {
    $msg = "One of following fields are missing:`nDomain:$($domain)`nOffice:$($LICENSE_OFFICE365)`nEMS:$($LICENSE_EMSE3)`nWould you like to fill them manually?`n (No to add them in script for permanent use)"

    if ((YesNoBox -title "Not all required fields are filled" -msg $msg) -eq 1) {
        Authenticate
        LogWrite -logstring "Fill the required fields of your organization before continue" -color $COLOR_WARNING -bWriteToLog $false
        
        while (-Not $domain) {
            $domain = InputBox -title "Domain name input" -msg "Enter domain name(Example:@microsoft.com):"
            if ($domain -notlike "@*") {
                LogWrite -logstring "Domain $($domain) is not valid. Please make it @domain.domain" -color $COLOR_MESSAGE -bWriteToLog $false
                $domain = ""
            }
        }

        if (-not $LICENSE_OFFICE365) {$LICENSE_OFFICE365 = GetLicenseGroup -GroupName "Office 365"}
        
        if (-not $LICENSE_EMSE3) {$LICENSE_EMSE3 = GetLicenseGroup -GroupName "EMS"}
    } else {
        LogWrite -logstring "User has left to fill the missing fields" -color $COLOR_MESSAGE -bWriteToLog $false
        exit($EXIT_USER_LEFT)
    }
}
    #endregion .. Check fields of data
#endregion .. Prerequisites

    #region Check open excel 
    $excelProcess = Get-Process -Name *excel*
    if ($null -ne $excelProcess) {
        $excelProcess = $excelProcess | Select-Object MainWindowTitle
        # Add if for if name found
        $fileName = $userPath.Split('\')[-1]
        if ($excelProcess -like "*$($fileName)*") {
            YesNoBox -title "Validate opened Excel files" -msg "Excel you're running your script on is open, please close before continue: $($filename)"
        }
    }
    #endregion .. Check open excel 

#region Data - Skipping first line representing the header
$Users = Import-XLSX $userPath
$badUsers = $Users | Where-Object {($_.id -ne $null) -and (($_.First_Name -eq $null -or $_.Last_Name -eq $null) -or ($_.areacode -eq $null -or $_.phone -eq $null) -or ($_.All_Group -eq $null))}
if ($badUsers) {
    LogWrite -logstring "Removing the following users for empty required cells (First/Last name, Areacode/Phone or All Group)" -color $COLOR_WARNING -bWriteToLog $true
    $badUsers | ForEach-Object {
        LogWrite -logstring $_.id -color $COLOR_WARNING -bWriteToLog $true
    }
}
$Users = $Users | Where-Object {($_.id -ne $null) -and ($_.First_Name -ne $null -or $_.Last_Name -ne $null) -and ($_.areacode -ne $null -and $_.phone -ne $null) -and ($_.All_Group -ne $null)}
#endregion .. Data insert

#region Approvals before starting
    #region Users approve
Write-Host "The following steps are required: `
* Approve the table to insert by properties (OK to continue)" -ForegroundColor $COLOR_MESSAGE
$approve = $users | Out-GridView -Title Approval -PassThru
if ($null -eq $approve) {
    LogWrite -logstring "** FAILED: Didn't approve the table, please modify the fields before running - Exist Error $($EXIT_USER_LEFT)" -color $COLOR_ERROR -bWriteToLog $true
    exit ($EXIT_USER_LEFT)
} else {
    Write-Host "Approved table fields" -ForegroundColor $COLOR_SUCCESS
}
    #endregion .. Users approve

#endregion .. Approvals before starting

Authenticate

#region Setting MFA to users
Write-Host "Setting up MFA object.. " -ForegroundColor $COLOR_WARNING
$auth = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
$auth.RelyingParty = "*"
$auth.State = "Enabled"
$auth.RememberDevicesNotIssuedBefore = (Get-Date)
#endregion .. Setting MFA to users

#region Create Users
$AllGroups = Get-AzureADGroup -All $true
LogWrite -logstring "------------------------ User creation configuration set ------------------------------" -color $COLOR_MESSAGE -bWriteToLog $true

# Run on each user in Excel
foreach ($User in $Users)
{
    #region User Properties
    $upnName = $User.id -replace '\s',''
    $UPN = $upnName + $domain
    $fullname = $user.First_Name + " " + $user.Last_Name

    if (($null -ne $user.areacode) -and ($null -ne $user.phone)) {
        $phone = "+$($user.areacode) $($user.phone)"
    } else {
        $phone = $null
    }
    
    $AllGroup = ($AllGroups | Where-Object {$_.DisplayName -like "*$($user.All_Group)*"}).ObjectId
    #endregion .. User Properties
    
    #region Create Groups
    if ($null -eq $AllGroup -and ($null -ne $user.All_Group)) {
        New-AzureADGroup -DisplayName $user.All_Group -Description "All group $($User.All_Group)" -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
        LogWrite -logstring "Created All group: $($user.All_Group)" -color $COLOR_MESSAGE -bWriteToLog $true
        Start-Sleep -Seconds 5
        $AllGroups = Get-AzureADGroup -All $true
        $AllGroup = ($AllGroups | Where-Object {$_.DisplayName -like "$($user.All_Group)"}).ObjectId
    }

    if (($null -ne $user.proj) -and ($user.proj -ne "proj-")) {
        $ProjGroup = ($AllGroups | Where-Object {$_.DisplayName -like "*$($user.proj)*"}).ObjectId
        New-AzureADGroup -DisplayName $user.Proj -Description "Proj group $($user.Proj)" -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
        LogWrite -logstring "Created Project group: $($user.Proj)" -color $COLOR_MESSAGE -bWriteToLog $true
        Start-Sleep -Seconds 5
        $AllGroups = Get-AzureADGroup -All $true
        $ProjGroup = ($AllGroups | Where-Object {$_.DisplayName -like "$($user.proj)"}).ObjectId
        Start-Sleep -Seconds 1
        Add-MsolGroupMember -GroupMemberObjectId $msolUser.ObjectId -GroupObjectId $ProjGroup -ErrorAction SilentlyContinue
    } 

    #endregion .. Create Groups

    #region Set user

    # Create new user only if not already created
    if (-Not (Get-MsolUser -UserPrincipalName $UPN -ErrorAction Ignore)) {
        $tempvar = New-MsolUser -UserPrincipalName $UPN -DisplayName $fullname -FirstName $user.First_Name -LastName $user.Last_Name -PhoneNumber $phone -MobilePhone $phone -AlternateEmailAddresses $altermail -UsageLocation $USAGE_LOCATION
        Start-Sleep 20
        LogWrite -logstring " New User: ID: $($upnName) $($User.First_name) $($User.Last_Name)" -color $COLOR_MESSAGE -bWriteToLog $true
    } else {
        LogWrite -logstring "Already created: ID: $($upnName) $($User.First_name) $($User.Last_Name)" -color $COLOR_MESSAGE -bWriteToLog $true
    }

    # Mechanism to wait if the creation in 365 after AAD takes a little longer than 
    try {
        $msolUser = Get-MsolUser -UserPrincipalName $UPN
    } catch {
        Start-Sleep 10
        $msolUser = Get-MsolUser -UserPrincipalName $UPN
    }
    
    #endregion .. Set user

    #region Define other user
    if ($User.MFA -like "*yes*") {
        Set-MsolUser -UserPrincipalName $UPN -StrongAuthenticationRequirements $auth
    }
    
    if ($User.OFFICE -like "*yes*") {
        Add-MsolGroupMember -GroupMemberObjectId $msolUser.ObjectId -GroupObjectId $LICENSE_OFFICE365 -ErrorAction SilentlyContinue
    }

    if ($User.EMS -like "*yes*") {
        Add-MsolGroupMember -GroupMemberObjectId $msolUser.ObjectId -GroupObjectId $LICENSE_EMSE3 -ErrorAction SilentlyContinue
    }
    
    Add-MsolGroupMember -GroupMemberObjectId $msolUser.ObjectId -GroupObjectId $AllGroup -ErrorAction SilentlyContinue
    #endregion .. Define on fields
	
}
#endregion .. Create Users

# Maximal wait time required before creating mail
Start-Sleep -Seconds 30

#region Change Primary mail

# Validate Exchange connection is still going.
if ($null -eq (Get-PSSession | Where-Object {$_.ConfigurationName -eq "Microsoft.Exchange" -and $_.State -eq "Opened"})) {
    LogWrite -logstring "Connection with Exchange online has been lost, authenticate again" -color $COLOR_WARNING -bWriteToLog $false
    Remove-PSSession $a
    $a= New-ExoPSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/
    Import-PSSession $a -ErrorAction SilentlyContinue
}

LogWrite -logstring "----------------------- Primary Mailbox configuration set -----------------------------" -color $COLOR_MESSAGE -bWriteToLog $true

foreach ($User in $Users) {
    $id = $User.id -replace '\s',''
    $altermail = $User.First_Name.split(" ")[0] + $User.Last_Name + $domain
    $altermail = $altermail -replace '\s',''
    
    try {
        Set-Mailbox -Identity "$id" -EmailAddresses "SMTP:$altermail"
        LogWrite -logstring " SUCCESFULLY: Mail Configured: $($id)" -color $COLOR_SUCCESS -bWriteToLog $true
    } catch {
        LogWrite -logstring " FAILED: Mail Configuration: $($id) - $ErrorMessage" -color $COLOR_WARNING -bWriteToLog $true
    }
}
#endregion .. Change Primary mail
Remove-PSSession $a
Start-Process $Logfile
