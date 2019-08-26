function Deploy-K8sConfigFiles {
  <#
  .SYNOPSIS
    Generate the required config files for the kubernetes cluster.
  .EXAMPLE
    Deploy-K8sConfigFiles -WorkerNodeCount 3 -ControllerNodeCount 3
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$WorkerNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$ControllerNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$clusterName
  )
  
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message "Deploying kubernetes config files" -Source $CmdletName -Severity 1 -ScriptSection 'Kubeconfig'

  #Distribute kubeconfig files
  Write-Log -Message 'Distributing the config files to the nodes' -Source $CmdletName -Severity 1 -ScriptSection 'Kubeconfig'
  try
  {
    for ($i=0; $i -lt $WorkerNodeCount; $i++)
    {
      scp -o StrictHostKeyChecking=no ('{0}-worker-{1}.kubeconfig' -f $clusterName, $i) kube-proxy.kubeconfig ('{0}-worker-{1}:~/' -f $clusterName, $i)
      if($LASTEXITCODE)
      {
        Throw 'Config file distribution error!'
      }
    }
    for ($i=0; $i -lt $ControllerNodeCount; $i++)
    {
      scp -o StrictHostKeyChecking=no admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ('{0}-controller-{1}:~/' -f $clusterName, $i)
      if($LASTEXITCODE)
      {
        Throw 'Config file distribution error!'
      }
    }

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to distribute kubeconfig files.' -Source $CmdletName -Severity 3 -ScriptSection 'Kubeconfig'
    Break
  }

}