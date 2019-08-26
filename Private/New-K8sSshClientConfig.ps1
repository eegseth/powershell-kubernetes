function New-K8sSshClientConfig {
  <#
  .SYNOPSIS
    Creates/updates ~/.ssh/id_rsa  with the ip, username and hostname of the generated azure vm's
  .EXAMPLE
    New-K8sSshClientConfig -NodeType 'worker'  -ResourceGroup 'kube' -adminUsername 'k8sadmin' -NodeCount 3
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidatePattern("^worker$|^controller$")][String]$NodeType,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ResourceGroup,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$adminUsername,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$NodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$clusterName
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message "Configuring SSH settings on this client" -Source $CmdletName -Severity 1 -ScriptSection 'Configuration - client'

  try
  {
    for ($i=0; $i -lt $NodeCount; $i++)
    {
      if(!([string](az vm show --show-details -g $resourceGroup -n ('{0}-{1}-{2}' -f $clusterName, $NodeType, $i) | select-string publicIps) -match '\d{2,3}\.(\d{1,3}\.){2}\d{1,3}'))
      {
        Throw 'Failed to fetch IP from Azure'
      }
      if($LASTEXITCODE)
      {
        Throw 'Failed to fetch IP from Azure'
      }
      [string]$ip = $matches[0]
      Write-Log -Message ('Appending host {0}-{1}-{2} with ip {3} and username {4} to {5}\.ssh\config' -f $clusterName, $NodeType, $i, $ip, $adminUsername, $home) -Source $CmdletName -Severity 1 -ScriptSection 'Configuration - client'
      $toFile = @"

Host $clusterName-$NodeType-$i
User $adminUsername
HostName $ip
IdentityFile ~/.ssh/id_rsa
ServerAliveInterval 120

"@
    
      $toFile | out-file "$home\.ssh\config" -Append -Force
    }

    Return 0

  }
  catch
  {
    Write-Log -Message "Failed to configure SSH settings on this client" -Source $CmdletName -Severity 3 -ScriptSection 'Configuration - client'
    Break
  }
}