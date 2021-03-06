<#  
.SYNOPSIS  
    This script gets all necessary information for diagnostic of a SharePoint farm.
      
.DESCRIPTION  
    This script uses the SharePoint 2010 Management Shell to collect information about a farm configuration. The script should be run in 
    SharePoint 2010 Management Shell. No error handling is included in this version
      
.NOTES  
    File Name  : Get-SPConfig.ps1  
    Author     : Henrik A. Halmstrand - Sharepointrevealed.com
    Email      : henrik.halmstrand@gmail.com
    Requires   : PowerShell Version 2.0 and SharePoint 2010 Management Shell
    Version    : 1.0

.LINK  
    This script posted to:  
        http://Sharepointrevealed.com

.EXAMPLE  
    PS [C:\] .\Get-SPConfig.ps1 
      
#>  
  
##  
# Start of Script  
##  

# Variable Declaration

$SpFarmName       = " "
$SpFarmStatus     = " "
$SpFarmVersion    = " "
$SpDate           = " "
$SpLogDir         = " "
$SpLogInterval    = " "
$SpErrorReporting = " "
$SpMaxLogEnabled  = " "
$SpFarmSolution   = " "
$SpServer         = " "
$SpServerCount    = " "
$EmailFrom        = " "     
$EmailTo          = " "
$SmtpServer       = " "
$FreeSpace        = " "

$SpFarmName       = (Get-SPFarm).name
$SpFarmStatus     = (Get-SpFarm).Status
$SpFarmVersion    = (Get-SpFarm).Version
$SpFarmSolution   = Get-SPSolution
$SpLogDir         = (Get-SPDiagnosticconfig).loglocation
$SpLogInterval    = (Get-SPDiagnosticconfig).LogCutInterval * (Get-SPDiagnosticconfig).ScriptErrorReportingDelay
$SpErrorReporting = (Get-SPDiagnosticconfig).ErrorreportingEnabled
$SpLogDay         = (Get-SPDiagnosticConfig).DaysToKeepLogs
$SpMaxLogSize     = (Get-SPDiagnosticConfig).LogDiskSpaceUsageGB
$SpMaxLogEnabled  = (Get-SPDiagnosticConfig).LogMaxDiskSpaceUsageEnabled
$logtime          = [DateTime]::Now.AddHours(-24)
$DBVar            = Get-Spdatabase
$CountVar         = $DBVar.Count
$DBParent         = $DBVar[0].parent.typename
$DBServer         = $DBVar[0].server.name

# Constant Declaration

$FilePath         = "C:\temp\SPConfig\SPConfig.txt"
$CSVSysPath       = "C:\temp\SPConfig\Errors In SysLog.csv"
$CSVAppPath       = "C:\temp\SPConfig\Errors In AppLog.csv"
$HotFixPath1       = "C:\temp\SPConfig\Hotfix Information.txt"
$HotFixPath2       = "C:\temp\SPConfig\Hotfix Information.html"
$InstalledAppPath = "C:\temp\SPConfig\Installed Applications.txt"
$CSVProcessPath   = "C:\temp\SPConfig\Running Processes.txt"
$Directory        = "C:\temp\SPConfig"
$ZipFilePath      = "C:\temp\SPConfig.zip"
$PingPath         = "C:\temp\SPConfig\Ping farm servers.txt"
$ScanPath         = "C:\temp\SPConfig\Port Scan of localhost.txt"
$ServicesPath     = "C:\temp\SPConfig\Running Services.txt"
$WebFilePath      = "C:\temp\SPConfig\IIS server Configuration.txt"
$DBFilePath       = "C:\temp\SPConfig\Database server Configuration.txt"
$SPLogPath        = "C:\temp\SPConfig\SharePoint Unexpected Errors.txt"
$NewLine          = "*******************************************************************************************************************************"

# Importing PowerShell Modules
import-module WebAdministration

# Function SEND-ZIP
# http://www.energizedtech.com/2010/06/powershell-send-files-to-a-com.html
function global:SEND-ZIP ($zipfilename, $filename) { 
 
$zipHeader=[char]80 + [char]75 + [char]5 + [char]6 + [char]0 + `
[char]0 + [char]0 + [char]0 + [char]0 + [char]0 + [char]0 + [char]0 + `
[char]0 + [char]0 + [char]0 + [char]0 + [char]0 + [char]0 + [char]0 + [char]0 + [char]0 + [char]0 

# 
# Check to see if the Zip file exists, if not create a blank one 
# 
If ( (TEST-PATH $zipfilename) -eq $FALSE ) { Add-Content $zipfilename -value $zipHeader } 

# 
$ExplorerShell=NEW-OBJECT -comobject 'Shell.Application' 

# 
# Send whatever file / Folder is specified in $filename to the Zipped folder $zipfilename 
# 
$SendToZip=$ExplorerShell.Namespace($zipfilename.tostring()).CopyHere($filename.ToString()) 

}

# Function Scan-Port
# http://blog.sapien.com/index.php/2009/05/12/a-powershell-port-scan/
Function Scan-Port {
     Param([string]$computername=$env:computername,
              [array]$ports=@("21","22","23","25","80","389","443","1433","3389")) 
               
              #turn off error pipeline    
              $ErrorActionPreference = "SilentlyContinue"    
              
              #set values for Write-Progress  
              $activity="Port Scan"  
              $status="Scanning $computername"  
              $i=0           
                           
              
              foreach ($port in $ports){
              $i++        
              # Write-Progress -Activity $activity -status $status -currentoperation "port $port" -percentcomplete (($i/$ports.count)*100)               
              
              #create empty custom object        
              $obj=New-Object PSObject        
              $obj | Add-Member -MemberType Noteproperty -name "Computername" -value $computername.ToUpper()        
              $obj | Add-Member -MemberType Noteproperty -name "Port" -value $port                
              
              $tcp=New-Object System.Net.Sockets.TcpClient($computername, $port)                
              if ($tcp.client.connected) {             
                    $obj | Add-Member -MemberType Noteproperty -name "PortOpen" -value $True            
                    $obj | Add-Member -MemberType Noteproperty -name "TTL" -value $($tcp.client.ttl)                        
                    [string]$rep=$tcp.client.RemoteEndPoint            
                    [string]$ip=$rep.substring(0,$rep.indexof(":"))                        
                    $obj | Add-Member -MemberType Noteproperty -name "RemoteIP" -value $ip             
                    }        
               else {
                    #            Write-Warning "$computername not open on port: $port"
                    $obj | Add-Member -MemberType Noteproperty -name "PortOpen" -value $False            
                    $obj | Add-Member -MemberType Noteproperty -name "TTL" -value -1            
                    $obj | Add-Member -MemberType Noteproperty -name "RemoteIP" -value $Null         
                    }  #end Else                     
              
              write $obj | Out-File -FilePath $ScanPath -append            
              
              #disconnect the socket connection            
              $tcp.client.disconnect($False)         
              
              } #end foreach                
              #dispose and disconnect 
                     
              $tcp.close()         
              Write-Progress -Activity $activity -status "Complete" -Completed        
              
              } #end function

    
    
# Getting System Information
$SpDate = Get-Date

Clear-Host

# Timer for Phase 1 # 
for ($i=1; $i -le 100; $i++)
{

start-sleep -Milliseconds 100
write-progress -activity "Phase 1" -status "Processing information:" -percentcomplete (($i/100)*100)
}

# Create the $Directory #
new-item -path C:\temp -name spconfig -itemType Directory | Out-Null

# Removes the $ZipFilePath if exists # 
If ( (TEST-PATH $ZipFilePath) -eq $True ) { Remove-item $ZipFilePath -recurse } 

# Getting Diagnostic information
"$NewLine" | Out-File -filepath $FilePath

"SharePoint Farm Diagnostics" | Out-File -filepath $FilePath -append     

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

"The date is: $SpDate" | Out-File -filepath $FilePath -append

"* General Information *" | Out-File -filepath $FilePath -append

$SpFarmStatus = (Get-SPFarm).Status
$SpFarmDB = (Get-SPFarm).Name

# Displaying farm status #
"The farm is: $SpFarmStatus" | Out-File -filepath $FilePath -append
"The farm configuration database is: $SpFarmDB" | Out-File -filepath $FilePath -append

# Displaying servers in farm #
"Servers in farm:" | Out-File -filepath $FilePath -append
(Get-SpFarm).Servers | Format-List name, Role, Id | Out-File -filepath $FilePath -append

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Get farm Diagnostic settings #
Get-SPDiagnosticConfig | Format-List | Out-File -filepath $FilePath -append

# Displaying Service Applications in farm #
"Service Application in farm:" | Out-File -filepath $FilePath -append
Get-SPServiceApplication | Format-Table displayname, Status, Id, ServiceApplicationProxyGroup | Out-File -filepath $FilePath -append

# Displaying Content Databases #
"Content Databases" | Out-File -filepath $FilePath -append
Get-SPContentDatabase | Format-list -property Name, Type, Id, Sites, CurrentSiteCount | Out-File -filepath $FilePath -append

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Getting installed Solutions in farm #
"Installed Farm Solution" | Out-File -filepath $FilePath -append
If ($SpFarmSolution = " ") {
    "No solution is installed" | Out-File -filepath $FilePath -append }
Else {
    "Installed Solution: $SpFarmSolution" | Out-File -filepath $FilePath -append }

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Displaying installed products #
Get-SPProduct | Format-List | Out-File -filepath $FilePath -append
    
"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Displaying Installed Web Application Features#
"Installed Web Application Features:" | Out-File -filepath $FilePath -append

# Displaying Installed Web Application Features at Web application level #
Get-SPFeature  -Limit ALL | Where-Object {$_.Scope -eq "WebApplication"} | Sort-Object DisplayName | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append
"Installed Farm Features:" | Out-File -filepath $FilePath -append

# Displaying Installed Web Application Features at farm level #
Get-SPFeature  -Limit ALL | Where-Object {$_.Scope -eq "Farm"} | Sort-Object DisplayName | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Displaying Installed Web Application Features at site level #
"Installed Site Features:" | Out-File -filepath $FilePath -append
Get-SPFeature  -Limit ALL | Where-Object {$_.Scope -eq "Site"} | Sort-Object DisplayName | Out-File -filepath $FilePath -append

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Displaying Error reporting status #
"* Error Handling *" | Out-File -filepath $FilePath -append
If ($SpErrorReporting.Equals($False)) {
    "Error reporting is Off" | Out-File -filepath $FilePath -append}
Else {
    "Error reporting is On" | Out-File -filepath $FilePath -append}

"Errorlogs location: $SpLogDir" | Out-File -filepath $FilePath -append
"Keep Logs for: $SpLogDay days" | Out-File -filepath $FilePath -append
"Max log size in GB: $SpMaxLogSize" | Out-File -filepath $FilePath -append
"MaxLogSizeEnabled: $SpMaxLogEnabled" | Out-File -filepath $FilePath -append

# Check if max log size is configured #
If ($SpMaxLogEnabled.Equals($False)) {
    "Max size is not set" | Out-File -filepath $FilePath -append }
Else {
    "Max log size is set" | Out-File -filepath $FilePath -append }

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Displaying Al# ternate Access Mapping
"Alternate Access Mapping" | Out-File -filepath $FilePath -append
(get-spfarm).AlternateUrlCollections | Out-File -filepath $FilePath -append

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Displaying Managed Accounts #
"Managed Accounts" | Out-File -filepath $FilePath -append
Get-SPManagedAccount | Out-File -filepath $FilePath -append

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Displaying Site Administrators #
Get-SpSiteAdministration | Select -property Url, OwnerLoginName, @{Name="Storage";Expression={$_.Quota.StorageMaximumLevel}} | Out-File -filepath $FilePath -append

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Displaying Site Administrators #
"Timer Job Definitions" | Out-File -filepath $FilePath -append
Get-SPWebApplication | Get-SPTimerJob -WebApplication {$_.Url} | Select Name, DisplayName, Schedule, Status, LastRunTime | Sort-Object Schedule | Out-File -filepath $FilePath -append

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Displaying Designer Settings #
"Designer Settings" | Out-File -filepath $FilePath -append
Get-SPWebapplication | Get-SPDesignerSettings -webapplication {$_.Url} | Out-File -filepath $FilePath -append

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append


# Displaying Unexpected Errors # 
"Unexpected Errors" | Out-File -filepath $SPLogPath
Get-SPLogEvent -MinimumLevel Unexpected  | Out-File -filepath $SPLogPath -append

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Displaying a list of all .dll files under HIV14 and total number # 
$Files = gci "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14\ISAPI\" -recurse | Where {$_.extension -eq ".dll"}
Clear-Host
$Files | Format-List Name, CreationTime, Length, VersionInfo | Out-File -filepath $FilePath -append
"Number of .dll-files:", $Files.Count | Out-File -filepath $FilePath -append

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Displaying UI Culture # 
get-uiculture | Out-File -filepath $FilePath -append
(get-uiculture).calendar | Out-File -filepath $FilePath -append
(get-uiculture).numberformat | Out-File -filepath $FilePath -append

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

Clear-Host

# Getting all Errors in Eventlogs for last 24 hours. Can be configured by changing $logtime"
Get-EventLog -LogName System -EntryType Error -After $logtime | select eventid, machinename, entrytype, source, message, timegenerated `
| Export-Csv $CSVSysPath -NoTypeInformation

Get-EventLog -LogName Application -EntryType Error -After $logtime | select eventid, machinename, entrytype, source, message, timegenerated | Export-Csv $CSVAppPath -NoTypeInformation

# Getting all processes sorted by CPU-time"
get-process -ComputerName . | Select-object ProcessName, Id, CPU, VM, WS, PM | Sort-Object -Descending CPU | Out-File -FilePath $CSVProcessPath

# Getting SharePoint services and the account they run under"
Get-WmiObject Win32_Service -Computer . | Where {$_.Description -match "SharePoint"} | Sort-Object Started -Descending `
| Format-Table Name, StartMode, Started, StartName, ProcessID, PathName -Auto | Out-File -FilePath $ServicesPath

"$NewLine" | Out-File -filepath $ServicesPath -append
"$NewLine" | Out-File -filepath $ServicesPath -append

# Getting IIS services and the account they run under"
Get-WmiObject Win32_Service -Computer . | Where {$_.Description -match "IIS"} | Sort-Object Started -Descending `
| Format-Table Name, StartMode, Started, StartName, ProcessID, PathName -Auto | Out-File -FilePath $ServicesPath -append

"$NewLine" | Out-File -filepath $ServicesPath -append
"$NewLine" | Out-File -filepath $ServicesPath -append

# Getting web-related services and the account they run under"
Get-WmiObject Win32_Service -Computer . | Where {$_.Description -match "WEB"} | Sort-Object Started -Descending `
| Format-Table Name, StartMode, Started, StartName, ProcessID, PathName -Auto | Out-File -FilePath $ServicesPath -append

"$NewLine" | Out-File -filepath $ServicesPath -append
"$NewLine" | Out-File -filepath $ServicesPath -append

# Getting all services and the account they run under"
Get-WmiObject Win32_Service -Computer . | Sort-Object Started -Descending `
| Format-Table Name, StartMode, Started, StartName, ProcessID, PathName -Auto | Out-File -FilePath $ServicesPath -append

"$NewLine" | Out-File -filepath $FilePath -append
"$NewLine" | Out-File -filepath $FilePath -append

# Collect Ping information and pinging all hosts in the farm #
"$NewLine" | Out-File -filepath $PingPath
$SpServer = Get-SPserver
$SpServerCount = $SpServer.count
for ($c=0; $c -le $SpServerCount-1 ; $c++)
{
test-connection $SpServer[$c].name | Out-File -filepath $PingPath -append
"$NewLine" | Out-File -filepath $PingPath -append
}


# Collect Hotfix Information
$i = Get-HotFix
$i | Select InstalledOn, HotFixID, Description | Sort-Object InstalledOn | Out-File -FilePath $HotFixPath1

$HFCount = $i.Count
"       " | Out-file $HotFixPath2 -append

For ($r=0; $r -le $HFCount-1; $r++)
{
"<a target=_blank href=`"http://support.microsoft.com/kb/$($i[$r].HotFixId )`">$($i[$r].HotFixId)</a>" | Out-file $HotFixPath2 -append
}

# Collect Installed Software
Get-ChildItem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall | ForEach-Object{Get-ItemProperty $_.PSPath} | Select-Object DisplayVersion, InstallDate, ModifyPath, Publisher, UninstallString, Language, DisplayName | Out-File -FilePath $InstalledAppPath

# Scan Ports, scans the localhost #
"$NewLine" | Out-File -filepath $ScanPath
Scan-Port
"Required information has been collected"

# Display all IIS sites and their status #
"$NewLine" | Out-File -filepath $WebFilePath
Get-website | select id, Name, state, physicalpath, applicationpool | format-list  | Out-File -filepath $WebFilePath -append

# Display all Application Pools and their status #
Get-WebAppPoolState | select itemxpath, Value | Format-Table -auto | Out-File -filepath $WebFilePath -append

# Display all bindings#
"$NewLine" | Out-File -filepath $WebFilePath -append
Get-WebBinding | select itemxpath, bindinginformation, protocol | format-List | Out-File -filepath $WebFilePath -append

"$NewLine" | Out-File -filepath $WebFilePath -append

# Displaying ApplicationPool # 
"SharePoint Application Pools"  | Out-File -filepath $WebFilePath -append
Get-SPServiceApplicationPool | Select Name, Id, ProcessAccountName, Status | format-table -auto | Out-File -filepath $WebFilePath -append
"$NewLine" | Out-File -filepath $WebFilePath -append

# Displaying all SharePoint databases #

"Total number of SharePoint databases are: $CountVar"  | Out-File -filepath $DBFilePath 
"Database server is: $DBServer"  | Out-File -filepath $DBFilePath -append
"Database parent is: $DBParent" | Out-File -filepath $DBFilePath -append

$FreeSpace | Out-File -filepath $DBFilePath -append

for ($f=0; $f -le $CountVar ; $f++)
{

"Name: $($DBVar[$f].name)", "DB Guid: $($DBVar[$f].Id.Guid)", "Status: $($DBVar[$f].Status)", "Size: $($DBVar[$f].DiskSizeRequired)", "Schema Version: $($DBVar[$f].Schemaversionxml)", "Connection String: $($DBVar[$f].databaseconnectionstring)"`
| Out-File -filepath $DBFilePath -append

$FreeSpace | Out-File -filepath $DBFilePath -append

}

# Getting information about all databases #
"$NewLine" | Out-File -filepath $DBFilePath -append
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "$DBServer"
$DBCount = $s.databases.count
"Total number of all databases: $DBCount" | Out-File -filepath $DBFilePath -append 
"Free disk space on volume: $($s.databases[0].logfiles[0].VolumeFreeSpace)" | Out-File -filepath $DBFilePath -append
for ($t=0; $t -le $DBCount-1;  $t++) 
{
    "Name: $($s.Databases[$t].name)", "Owner: $($s.databases[$t].owner)", "Recovery Model: $($s.databases[$t].RecoveryModel)", "Read-Only: $($s.databases[$t].Readonly)",`
    "Mirrored: $($s.databases[$t].mirroringstatus)", "File path: $($s.databases[$t].PrimaryFilePath)", "Collation: $($s.databases[$t].collation)",`
    "Compatibilty Level: $($s.databases[$t].CompatibilityLevel)", "Users: $($s.databases[$t].Users)", "Primary File path: $($s.databases[11].primaryFilePath)",`
    "Transaction Log: $($s.databases[$t].logfiles[$t].FileName)", "Last Backup Date: $($s.databases[$t].lastbackupdate)",`
    "Last Diffrential Backup: $($s.databases[$t].LastDifferentialBackupDate)", "Last Transaktionslog Backup: $($s.databases[$t].LastLogBackupDate)" | Out-File -filepath $DBFilePath -append
    $FreeSpace | Out-File -filepath $DBFilePath -append
}

# !!!! Don't put any code after this section !!! #

# Timer for phase 2 #
for ($i=1; $i -le 100; $i++)
{
start-sleep -Milliseconds 10

write-progress -activity "Phase 2" -status "Collecting SharePoint Farm Diagnostics:" -percentcomplete (($i/100)*100)
}
Write-Host "Diagnostic information has been collected"

start-sleep -Milliseconds 100

# Timer for phase 3 #
for ($i=1; $i -le 100; $i++)
{
start-sleep -Milliseconds 100
write-progress -activity "Phase 3" -status "Compressing and Zipping files into SPConfig.zip:" -percentcomplete (($i/100)*100)
}
SEND-ZIP $ZipFilePath $Directory
Write-Host "Diagnostic files have been compressed and zipped"

# Timer for phase 4 #
for ($i=1; $i -le 50; $i++)
{

start-sleep -Milliseconds 20
write-progress -activity "Phase 4" -status "Removing $Directory $Directory:" -percentcomplete (($i/100)*100)
}

# Removing $Directory #
Remove-Item $Directory -recurse
Write-Host "Diagnostic Directory $Directory has been removed"

# Getting the smtp server and the reply-address #
$cawebapp = Get-SPwebApplication -includecentraladministration | where {$_.IsAdministrationWebApplication}
$EmailFrom = $cawebapp.OutboundMailReplyToAddress;
$Smtp = $cawebapp.OutboundMailServiceInstance;
$SmtpServer = $Smtp.server.name;

# Getting input about recievers email-address and sending an email with the attachement #
$EmailTo = read-host -prompt ‘Provide the reciever email adress: (Press ctrl+c to abort) ’

send-mailmessage -to "User <$EmailTo>" -from "Admin <$EmailFrom>" -subject "SPConfig file" -body "Sending the SPConfig file." `
-Attachment $ZipFilePath -priority High -dno onSuccess, onFailure -smtpServer $SmtpServer
Write-Host "An email has been sent to $EmailTo with attachment $ZipFilePath"



