function New-K8sAzureResources {
  <#
  .SYNOPSIS
    Creates the desired azure resources needed for the kubernetes cluster. 
    Creates vnets, nsg, lb, vms etc.
  .EXAMPLE
    New-K8sAzureResources -ResourceGroup 'k8s' -Location 'NorthEurope' -ClusterName 'kube' -WorkerNodeCount 3 -WorkerNodeSize 'Standard_B2s' -WorkerDataDiskSize 200 -ControlNodeCount 3 -ControlNodeSize 'Standard_B2s' -ControlDataDiskSize 200 -OS 'Canonical:UbuntuServer:18.04-LTS:latest' -AdminUser 'k8sadm'-AdminSSHKey ''C:\Users\you\.ssh\id_rsa.pub'
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ResourceGroup,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$Location,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ClusterName,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$WorkerNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$WorkerNodeSize,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$WorkerDataDiskSize,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$ControlNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ControlNodeSize,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$ControlDataDiskSize,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$OS,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$AdminUser,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$AdminSSHKey
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters

  Write-Log -Message "Starting the creation of Azure compute resources" -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'

  try
  {
    Write-Log -Message "Creating resource group $resourceGroup in location $Location" -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
    az group create --name $resourceGroup --location $Location
    if($LASTEXITCODE)
    {
      Throw 'Failed to create ResourceGroup'
    }

    Write-Log -Message "Creating VNET $clustername-vnet" -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
    az network vnet create --resource-group $resourceGroup --name $clusterName-vnet --address-prefixes 10.240.0.0/16 --subnet-name $clusterName-subnet --subnet-prefixes 10.240.0.0/24
    if($LASTEXITCODE)
    {
      Throw 'Failed to create VNET'
    }

    Write-Log -Message "Creating NSG $clusterName-nsg" -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
    az network nsg create --resource-group $resourceGroup --name $clusterName-nsg
    if($LASTEXITCODE)
    {
      Throw 'Failed to create NSG'
    }

    Write-Log -Message "Creating NSG rule K8s" -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
    az network nsg rule create --resource-group $resourceGroup --nsg-name $clusterName-nsg --name K8s --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-port-ranges 22 6443
    if($LASTEXITCODE)
    {
      Throw 'Failed to create NSG Rule'
    }
    
    Write-Log -Message "Creating public IP $clustername-ip" -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
    az network public-ip create --name $clusterName-ip --resource-group $resourceGroup --allocation-method Static
    if($LASTEXITCODE)
    {
      Throw 'Failed to create public IP'
    }

    Write-Log -Message "Creating LB $clustername-lb" -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
    az network lb create --name $clusterName-lb --resource-group $resourceGroup --backend-pool-name $clusterName-lb-pool --public-ip-address $clusterName-ip
    if($LASTEXITCODE)
    {
      Throw 'Failed to create LB'
    }

    Write-Log -Message "Creating LB probe $clusterName-lb-probe" -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
    az network lb probe create --lb-name $clusterName-lb --resource-group $resourceGroup --name $clusterName-lb-probe --port 80 --protocol tcp
    if($LASTEXITCODE)
    {
      Throw 'Failed to create LB Probe'
    }

    Write-Log -Message "Creating LB rule $clusterName-lb-rule" -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
    az network lb rule create --resource-group $resourceGroup --lb-name $clusterName-lb --name $clusterName-lb-rule --protocol tcp --frontend-port 6443 --backend-port 6443 --backend-pool-name $clusterName-lb-pool --probe-name $clusterName-lb-probe
    if($LASTEXITCODE)
    {
      Throw 'Failed to create LB Rule'
    }

    for ($i=0; $i -lt $ControlNodeCount; $i++)
    {
      Write-Log -Message ('Creating public IP {0}-controller-{1}-ip' -f $clusterName, $i) -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
      az network public-ip create --name ('{0}-controller-{1}-ip' -f $clusterName, $i) --resource-group $resourceGroup --allocation-method Static
      if($LASTEXITCODE)
      {
        Throw 'Failed to create public IP'
      }

    }
    
    for ($i=0; $i -lt $ControlNodeCount; $i++)
    {
      Write-Log -Message ('Creating NIC {0}-controller-{1}-nic' -f $clusterName, $i) -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
      az network nic create --resource-group $resourceGroup --name ('{0}-controller-{1}-nic' -f $clusterName, $i) --vnet-name $clusterName-vnet --subnet $clusterName-subnet --network-security-group $clusterName-nsg --public-ip-address ('{0}-controller-{1}-ip' -f $clusterName, $i) --private-ip-address ('10.240.0.1{0}' -f $i) --lb-name $clusterName-lb --lb-address-pools $clusterName-lb-pool --ip-forwarding true
      if($LASTEXITCODE)
      {
        Throw 'Failed to create NIC'
      }
    }
    
    Write-Log -Message "Creating VM Availability set $clusterName-as" -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
    az vm availability-set create --name $clusterName-as -g $resourceGroup
    if($LASTEXITCODE)
    {
      Throw 'Failed to create VM Availability set'
    }
    
    for ($i=0; $i -lt $ControlNodeCount; $i++)
    {
      Write-Log -Message ('Creating VM {0}-controller-{1}' -f $clusterName, $i) -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
      az vm create --name ('{0}-controller-{1}' -f $clusterName, $i) --resource-group $resourceGroup --availability-set $clusterName-as --no-wait --nics ('{0}-controller-{1}-nic' -f $clusterName, $i) --image $OS --admin-username $AdminUser --ssh-key-values $AdminSSHKey --size $ControlNodeSize --data-disk-sizes-gb $ControlDataDiskSize
      if($LASTEXITCODE)
      {
        Throw 'Failed to create VM'
      }
    }
    
    for ($i=0; $i -lt $WorkerNodeCount; $i++)
    {
      Write-Log -Message ('Creating public IP {0}-worker-{1}-ip' -f $clusterName, $i) -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
      az network public-ip create --name ('{0}-worker-{1}-ip' -f $clusterName, $i) --resource-group $resourceGroup --allocation-method Static
      if($LASTEXITCODE)
      {
        Throw 'Failed to create public IP'
      }
    }
    
    for ($i=0; $i -lt $WorkerNodeCount; $i++)
    {
      Write-Log -Message ('Creating NIC {0}-worker-{1}-nic' -f $clusterName, $i) -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
      az network nic create --resource-group $resourceGroup --name ('{0}-worker-{1}-nic' -f $clusterName, $i) --vnet-name $clusterName-vnet --subnet $clusterName-subnet --network-security-group $clusterName-nsg --public-ip ('{0}-worker-{1}-ip' -f $clusterName, $i) --private-ip-address ('10.240.0.2{0}' -f $i) --ip-forwarding true --tags ('podCidr=10.200.{0}.0/24' -f $i)
      if($LASTEXITCODE)
      {
        Throw 'Failed to create NIC'
      }
    }
    
    for ($i=0; $i -lt $WorkerNodeCount; $i++)
    {
      Write-Log -Message ('Creating VM {0}-worker-{1}' -f $clusterName, $i) -Source $CmdletName -Severity 1 -ScriptSection 'Provisioning'
      az vm create --name ('{0}-worker-{1}' -f $clusterName, $i) --resource-group $resourceGroup --nics ('{0}-worker-{1}-nic' -f $clusterName, $i) --image $OS --admin-username $AdminUser --ssh-key-values $AdminSSHKey --size $WorkerNodeSize --data-disk-sizes-gb $WorkerDataDiskSize --tags ('podCidr=10.200.{0}.0/24' -f $i)
      if($LASTEXITCODE)
      {
        Throw 'Failed to create VM'
      }
    }

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to create compute resources in Azure. If something was generated, it will remain, no cleanup will be done.' -Source $CmdletName -Severity 3 -ScriptSection 'Provisioning'
    Break
  }
  
}