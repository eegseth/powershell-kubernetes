function Build-K8sConfigFiles {
  <#
  .SYNOPSIS
    Generate the required config files for the kubernetes cluster.
  .EXAMPLE
    Build-K8sConfigFiles -WorkerNodeCount 3 -ClusterName 'kube'
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$WorkerNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ClusterName,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$resourceGroup
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message "Generating kubernetes config files" -Source $CmdletName -Severity 1 -ScriptSection 'Kubeconfig'

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

    #Worker nodes kubeconfig
    for ($i=0; $i -lt $WorkerNodeCount; $i++){
      Write-Log -Message "Generating kubeconfig for worker node $clusterName-worker-$i" -Source $CmdletName -Severity 1 -ScriptSection 'Kubeconfig'
      kubectl config set-cluster "$clusterName" --certificate-authority="ca.pem" --embed-certs="true" --server="https://$ip" --kubeconfig="$clusterName-worker-$i.kubeconfig"
      if($LASTEXITCODE)
      {
        Throw 'Kubeconfig generation error!'
      }
      kubectl config set-credentials "system:node:$clusterName-worker-$i" --client-certificate="$clusterName-worker-$i.pem" --client-key="$clusterName-worker-$i-key.pem" --embed-certs="true" --kubeconfig="$clusterName-worker-$i.kubeconfig"
      if($LASTEXITCODE)
      {
        Throw 'Kubeconfig generation error!'
      }
      kubectl config set-context default --cluster="$clusterName" --user="system:node:$clusterName-worker-$i" --kubeconfig="$clusterName-worker-$i.kubeconfig"
      if($LASTEXITCODE)
      {
        Throw 'Kubeconfig generation error!'
      }
      kubectl config use-context default --kubeconfig="$clusterName-worker-$i.kubeconfig"
      if($LASTEXITCODE)
      {
        Throw 'Kubeconfig generation error!'
      }
    }

    #kube-proxy kubeconfig
    Write-Log -Message "Generating kubeconfig for kubeproxy" -Source $CmdletName -Severity 1 -ScriptSection 'Kubeconfig'
    kubectl config set-cluster "$clusterName" --certificate-authority="ca.pem" --embed-certs="true" --server="https://$ip" --kubeconfig="kube-proxy.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config set-credentials "system:kube-proxy" --client-certificate="kube-proxy.pem" --client-key="kube-proxy-key.pem" --embed-certs="true" --kubeconfig="kube-proxy.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config set-context default --cluster="$clusterName" --user="system:kube-proxy" --kubeconfig="kube-proxy.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config use-context default --kubeconfig="kube-proxy.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }

    #kube-controller-manager kubeconfig
    Write-Log -Message "Generating kubeconfig for controller-manager" -Source $CmdletName -Severity 1 -ScriptSection 'Kubeconfig'
    kubectl config set-cluster "$clusterName" --certificate-authority="ca.pem" --embed-certs="true" --server="https://127.0.0.1:6443" --kubeconfig="kube-controller-manager.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config set-credentials "system:kube-controller-manager" --client-certificate="kube-controller-manager.pem" --client-key="kube-controller-manager-key.pem" --embed-certs="true" --kubeconfig="kube-controller-manager.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config set-context default --cluster="$clusterName" --user="system:kube-controller-manager" --kubeconfig="kube-controller-manager.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config use-context default --kubeconfig="kube-controller-manager.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }

    #kube-scheduler kubeconfig
    Write-Log -Message "Generating kubeconfig for kube-scheduler" -Source $CmdletName -Severity 1 -ScriptSection 'Kubeconfig'
    kubectl config set-cluster "$clusterName" --certificate-authority="ca.pem" --embed-certs="true" --server="https://127.0.0.1:6443" --kubeconfig="kube-scheduler.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config set-credentials "system:kube-scheduler" --client-certificate="kube-scheduler.pem" --client-key="kube-scheduler-key.pem" --embed-certs="true" --kubeconfig="kube-scheduler.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config set-context default --cluster="$clusterName" --user="system:kube-scheduler" --kubeconfig="kube-scheduler.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config use-context default --kubeconfig="kube-scheduler.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }

    #kube admin kubeconfig
    Write-Log -Message "Generating kubeconfig for kubeadmin" -Source $CmdletName -Severity 1 -ScriptSection 'Kubeconfig'
    kubectl config set-cluster "$clusterName" --certificate-authority="ca.pem" --embed-certs="true" --server="https://127.0.0.1:6443" --kubeconfig="admin.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config set-credentials "admin" --client-certificate="admin.pem" --client-key="admin-key.pem" --embed-certs="true" --kubeconfig="admin.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config set-context default --cluster="$clusterName" --user="admin" --kubeconfig="admin.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }
    kubectl config use-context default --kubeconfig="admin.kubeconfig"
    if($LASTEXITCODE)
    {
      Throw 'Kubeconfig generation error!'
    }

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to generate kubeconfig files.' -Source $CmdletName -Severity 3 -ScriptSection 'Kubeconfig'
    Break
  }
  
}