function New-K8sPodNetworkRoute {
  <#
  .SYNOPSIS
    Provisions the pod network route table in azure so pods can have nice conversations ;)
  .EXAMPLE
    New-K8sPodNetworkRoute -ResourceGroup 'kube' -ClusterName 'k8s' -WorkerNodeCount 3
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ResourceGroup,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ClusterName,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$WorkerNodeCount
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message 'Provisioning the Pod network routes' -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'

  try
  {
    az network route-table create --resource-group $resourceGroup --name $clusterName-rt
    if($LASTEXITCODE)
    {
      Throw 'Failed to create route table'
    }
    for ($i=0; $i -lt $WorkerNodeCount; $i++)
    {
      az network route-table route create --resource-group $resourceGroup --name $clusterName-route-10-200-$i-0-24 --route-table-name $clusterName-rt --next-hop-type VirtualAppliance --next-hop-ip-address 10.240.0.2$i --address-prefix 10.200.$i.0/24
      if($LASTEXITCODE)
      {
        Throw 'Failed to create route table route'
      }
    }
    az network vnet subnet update --resource-group $resourceGroup --vnet-name $clusterName-vnet --name $clusterName-subnet --route-table $clusterName-rt  
    if($LASTEXITCODE)
    {
      Throw 'Failed to update subnet with route table'
    }

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to provision pod network routes.' -Source $CmdletName -Severity 3 -ScriptSection 'Provisioning'
    Break
  }

}