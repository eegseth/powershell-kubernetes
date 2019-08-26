function Install-K8sPrerequisites {
  <#
  .SYNOPSIS
    Installs and configures the required prerequisites on the VM's
  .EXAMPLE
    Install-K8sPrerequisites -DockerVersion '18.06.2~ce~3-0~ubuntu' -TimeZone 'Europe/Oslo' -NodeType  'worker' -NodeCount 3
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$DockerVersion,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$TimeZone,
    [Parameter(Mandatory=$true)][ValidatePattern("^worker$|^controller$")][String]$NodeType,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$NodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$clusterName
  )
  
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message "Installing and configuring prerequisites on the VMs" -Source $CmdletName -Severity 1 -ScriptSection 'Prerequisites - VM'

  try{
  $sshCommands = @"
sudo apt-get update;
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common socat conntrack ipset;
sudo swapoff -a;
sudo systemctl daemon-reload;
sudo timedatectl set-timezone $timezone;
"@

  #The behaviour of line endings on cross-platform gives me nightmares! Just standardize it ffs!
  (get-variable -name sshCommands -ValueOnly).Replace("`r`n","`n") | Set-Variable -Name sshCommands
    
  for ($i=0; $i -lt $NodeCount; $i++)
  {
    Write-Log -Message ('Installing and configuring prerequisites on the VM {0}-{1}-{2}' -f $clusterName, $NodeType, $i) -Source $CmdletName -Severity 1 -ScriptSection 'Prerequisites - VM'
    ssh -o StrictHostKeyChecking=no ('{0}-{1}-{2}' -f $clusterName, $NodeType, $i) $sshCommands
    if($LASTEXITCODE)
    {
      Throw 'Prerequisites installation error!'
    }
  }

  Return 0

  }catch
  {
    Write-Log -Message 'Failed to install and set up prereqs on the nodes' -Source $CmdletName -Severity 3 -ScriptSection 'Prerequisites - VM'
    Break
  }

}