# You have to configure the AD Domain and optional a OU you'd like to search for computers:
$SearchBases = @(
    "OU=Servers,OU=Users and Computers,DC=YOURDOMAIN,DC=YOURTLD"
    "CN=Computers,DC=YOURDOMAIN,DC=YOURTLD"
)

# You can optionally exclude computers you don't want to show in the list:
$excludeComputer = @(
    "any1.excluded.computer"
    "any2.excluded.computer"
)

# if enabled it writes the output into $env:TEMP\Computers_WO_Agent.txt
$writeInFile = $false
if ($writeInFile) {"Computers without Agent,Operating System,Description,Scanned Organizational Unit" > $env:TEMP\Computers_WO_Agent.txt}

Import-Module ActiveDirectory

$Agents = Get-SCOMAgent
$Agents += Get-SCOMManagementServer

ForEach ($Agent in $Agents) {
    $AgentName = $Agent.PrincipalName.ToString()
    [array]$AgentList = $AgentList + $AgentName + ','
}

Function Get-AdComputersWithoutAgent { 
    param([parameter(Mandatory=$true)]$SearchDC,[parameter(Mandatory=$true)]$SearchBase)
    $AdComputers = Get-ADComputer -Filter {OperatingSystem -Like "*Server*" -And servicePrincipalName -notlike "*MSClusterVirtualServer*"} -Server $SearchDC -SearchBase $SearchBase -Property DNSHostName,OperatingSystem,Enabled,DistinguishedName,Description,servicePrincipalName
    ForEach ($Computer in $AdComputers) {
        If ($Computer.Enabled -eq $true) {
            If ($excludeComputer -notcontains $Computer.DNSHostName) {
                $InstallStatus = $AgentList -contains $Computer.DNSHostName 
                If ($InstallStatus -eq $false) {
                    if ($writeInFile) {
                        $Computer.DNSHostName + "," + $Computer.OperatingSystem + "," + $Computer.Description + "," >> $env:TEMP\Computers_WO_Agent.txt
                    } else {
                        $dataObject = $ScriptContext.CreateInstance("xsd://foo!bar/baz")
                        $dataObject["Id"] = [String]($Computer.DNSHostName)
                        $dataObject["Computers without Agent"] = [String]($Computer.DNSHostName)
                        $dataObject["Operating System"] = [String]($Computer.OperatingSystem)
                        $dataObject["Description"] = [String]($Computer.Description)
                        $dataObject["Scanned Organizational Unit"] = [String]($SearchBase)
                        #$dataObject["Distinguished Name"] = [String]($Computer.DistinguishedName)
                        $ScriptContext.ReturnCollection.Add($dataObject)
                    }
                }
            }
        }
    }
}

ForEach ($SearchBase in $SearchBases) {
    Get-AdComputersWithoutAgent -SearchDC $env:LOGONSERVER.ToString().Replace("\", "") -SearchBase $SearchBase
}

if ($writeInFile) {$env:TEMP\Computers_WO_Agent.txt | Out-GridView}