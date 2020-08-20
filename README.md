# CreateUser365

This repo includes:
- ***CreateUser365 -*** user initiative creation and more with 365 outlook including mails (Supposing E license purchased and assigned to a group)
- ***BulkUser -*** Quick asynchronous user creation based on SQL query. 
- ***DSA -*** Nice GUI representing alike DSA.msc console from the on-premise based on grid view feature in Powershell and based on user Hirachy in a flat AAD.


## How to use
### CreateUser365
1. Clone to a folder
2. Fill required data in script
```powershell
#region Input from user
Set-Variable -Name domain            -Value "" -Option AllScope
Set-Variable -Name LICENSE_OFFICE365 -Value "" -Option AllScope
Set-Variable -Name LICENSE_EMSE3     -Value "" -Option AllScope
```
3. Fill the Excel template in user information: https://1drv.ms/x/s!AkZyvbMPcBA_gRkE85dPazE1vxv4
4. Run with the path of the excel, example: CreateUser365.ps1 c:\temp\Project Users.xlsx

### BulkUser
1. Clone to a folder
2. Fill required data in script
```powershell
Set-Variable -Name domain         -Value ""  -Option AllScope
Set-Variable -Name areacode	  -Value ""  -Option AllScope
Set-Variable -Name Logfile        -Value "." -Option AllScope
Set-Variable -Name UsageLocation  -Value ""  -Option AllScope
```
3. Fill required data query from SQL
```sql
$Params = @{
   'ServerInstance' = '';
   'Database' = '';
   'Username' = '';
   'Password' = '';
   'Query' = '';
}
```
4. Run.

### DSA
1. Clone to a folder
2. Run
