function Deploy-K8sEtcdEncryptionConfig {
  <#
  .SYNOPSIS
    Deploys the data encryption config for etcd.
  .EXAMPLE
    Deploy-K8sEtcdEncryptionConfig -ControllerNodeCount 3
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$ControllerNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$clusterName
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message 'Deploying encryption config for encrypting secrets in etcd' -Source $CmdletName -Severity 1 -ScriptSection 'ETCD - Configuration'
  
  try
  {  
    #distribute encryption config
    for ($i=0; $i -lt $ControllerNodeCount; $i++)
    {
      scp -o StrictHostKeyChecking=no encryption-config.yaml ('{0}-controller-{1}:~/' -f $clusterName, $i)
      if($LASTEXITCODE)
      {
        Throw 'ETCD encryption config distribution error!'
      }
    }

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to distribute the encryption config.' -Source $CmdletName -Severity 3 -ScriptSection 'ETCD - Configuration'
    Break
  }

}