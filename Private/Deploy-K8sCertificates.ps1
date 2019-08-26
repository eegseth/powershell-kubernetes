function Deploy-K8sCertificates {
  <#
  .SYNOPSIS
    Deploys the required certificates for the kubernetes cluster.
  .EXAMPLE
    Deploy-K8sCertificates -WorkerNodeCount 3 -ControllerNodeCount 3
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$WorkerNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$ControllerNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$clusterName
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message "Deploying certificates for the kubernetes cluster" -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'
  
  #Distribute the certificates
  Write-Log -Message 'Distributing the certificates to the nodes' -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'
  try
  {
    for ($i=0; $i -lt $WorkerNodeCount; $i++)
    {
      Write-Log -Message ('Distributing certificates to node {0}-worker-{1}' -f $clusterName, $i) -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'
      scp -o StrictHostKeyChecking=no ca.pem $clusterName-worker-$i-key.pem $clusterName-worker-$i.pem ('{0}-worker-{1}:~/' -f $clusterName, $i)
      if($LASTEXITCODE)
      {
        Throw 'Certificate distribution error!'
      }
    }
    
    for ($i=0; $i -lt $ControllerNodeCount; $i++)
    {
      Write-Log -Message ('Distributing certificates to node {0}-controller-{1}' -f $clusterName, $i) -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'
      scp -o StrictHostKeyChecking=no ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem ('{0}-controller-{1}:~/' -f $clusterName, $i)
      if($LASTEXITCODE)
      {
        Throw 'Certificate distribution error!'
      }
    }  

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to distribute certificates to nodes.' -Source $CmdletName -Severity 3 -ScriptSection 'Certificates'
    Break
  }
}