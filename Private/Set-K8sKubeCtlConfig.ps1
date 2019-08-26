function Set-K8sKubeCtlConfig {
  <#
  .SYNOPSIS
    Bootstraps the kubernetes worker nodes
  .EXAMPLE
    Set-K8sKubeCtlConfig -ClusterName 'k8s' -ResourceGroup 'k8s'
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ClusterName,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$resourceGroup
  )
  
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message 'Configuring kubectl' -Source $CmdletName -Severity 1 -ScriptSection 'Kubeconfig'
  
  try
  {

    if(!([string](az network public-ip show -g $resourceGroup -n $clusterName-ip | select-string ipAddress) -match '\d{2,3}\.(\d{1,3}\.){2}\d{1,3}'))
    {
      Throw 'Failed to IP from Azure'
    }
    if($LASTEXITCODE)
    {
      Throw 'Failed to IP from Azure'
    }
    [string]$ip = $matches[0]

    $ip=$ip+":6443"

    kubectl config set-cluster "$clusterName" --certificate-authority="ca.pem" --embed-certs="true" --server="https://$ip"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config set-credentials "admin" --client-certificate="admin.pem" --client-key="admin-key.pem"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config set-context "$clusterName" --cluster="$clusterName" --user="admin"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config use-context "$clusterName"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to configure kubectl.' -Source $CmdletName -Severity 3 -ScriptSection 'Kubeconfig'
    Break
  }

}