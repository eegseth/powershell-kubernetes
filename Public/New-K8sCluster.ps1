function New-K8sCluster
{
  <#
  .SYNOPSIS
    Create a new kubernetes cluster in Azure
  .EXAMPLE
    New-k8scluster
  #>
  [CmdletBinding()]
  Param (
    #Azure parameters
    [Parameter()][ValidateNotNullorEmpty()][String]$resourceGroup = 'kube',
    [Parameter()][ValidateNotNullorEmpty()][String]$AzureSubscription = 'MSDN Platforms',
    [Parameter()][ValidateNotNullorEmpty()][String]$AzureRegion = 'NorthEurope',
    [Parameter()][ValidateNotNullorEmpty()][String]$AzAdSecret = 'SuperSecretSecret',

    #Kubernetes cluster settings
    [Parameter()][ValidateNotNullorEmpty()][String]$clusterName = 'k8s',
    [Parameter()][ValidateNotNullorEmpty()][String]$controllerNodes = 3,
    [Parameter()][ValidateNotNullorEmpty()][String]$workerNodes = 3,

    #VM parameters
    [Parameter()][ValidateNotNullorEmpty()][String]$controllerSize = 'Standard_B2s',
    [Parameter()][ValidateNotNullorEmpty()][String]$workerSize = 'Standard_B2s',
    [Parameter()][ValidateNotNullorEmpty()][String]$controllerDataDiskSize = 200,
    [Parameter()][ValidateNotNullorEmpty()][String]$workerDataDiskSize = 200,
    [Parameter()][ValidateNotNullorEmpty()][String]$ubuntuVersion = 'Canonical:UbuntuServer:18.04-LTS:latest',
    [Parameter()][ValidateNotNullorEmpty()][String]$adminUsername = 'k8sadm',
    [Parameter()][ValidateNotNullorEmpty()][String]$adminSSHPublicKeyPath = 'C:\Users\eegseth\.ssh\id_rsa.pub',
    [Parameter()][ValidateNotNullorEmpty()][String]$timezone = 'Europe/Oslo',

    #Client parameters
    [Parameter()][ValidateNotNullorEmpty()][String]$ConfigFilesDirectory = ('{0}\.kube' -f $env:USERPROFILE),
    [Parameter()][ValidateNotNullorEmpty()][System.Boolean]$downloadClientTools = $false,

    #Version parameters
    [Parameter()][ValidateNotNullorEmpty()][String]$dockerVersion = '18.06.2~ce~3-0~ubuntu',
    [Parameter()][ValidateNotNullorEmpty()][String]$k8sversion = 'v1.14.4',
    [Parameter()][ValidateNotNullorEmpty()][String]$k8sversionMajor = 'v1.14.0',
    [Parameter()][ValidateNotNullorEmpty()][String]$cniVersion = 'v0.8.1',
    [Parameter()][ValidateNotNullorEmpty()][String]$containerdVersion = '1.2.7',
    [Parameter()][ValidateNotNullorEmpty()][String]$etcdVersion = 'v3.3.9',
    [Parameter()][ValidateNotNullorEmpty()][String]$cfsslVersion = 'R1.2',
    [Parameter()][ValidateNotNullorEmpty()][String]$runCVersion = 'v1.0.0-rc5',
    [Parameter()][ValidateNotNullorEmpty()][String]$runScVersion = '50c283b9f56bb7200938d9e207355f05f79f0d17',

    #Download URL parameters
    [Parameter()][ValidateNotNullorEmpty()][URI]$cfsslDownloadURL = "https://pkg.cfssl.org/$cfsslVersion/cfssl_windows-amd64.exe",
    [Parameter()][ValidateNotNullorEmpty()][URI]$cfssljsonDownloadURL = "https://pkg.cfssl.org/$cfsslVersion/cfssljson_windows-amd64.exe",
    [Parameter()][ValidateNotNullorEmpty()][URI]$kubectlWindowsDownloadURL = "https://storage.googleapis.com/kubernetes-release/release/$k8sversion/bin/windows/amd64/kubectl.exe",
    [Parameter()][ValidateNotNullorEmpty()][URI]$etcdDownloadURL = "https://github.com/coreos/etcd/releases/download/$etcdVersion/etcd-$etcdVersion-linux-amd64.tar.gz",
    [Parameter()][ValidateNotNullorEmpty()][URI]$kubeApiDownloadURL = "https://storage.googleapis.com/kubernetes-release/release/$k8sversion/bin/linux/amd64/kube-apiserver",
    [Parameter()][ValidateNotNullorEmpty()][URI]$kubeControllerDownloadURL = "https://storage.googleapis.com/kubernetes-release/release/$k8sversion/bin/linux/amd64/kube-controller-manager",
    [Parameter()][ValidateNotNullorEmpty()][URI]$kubeSchedulerDownloadURL = "https://storage.googleapis.com/kubernetes-release/release/$k8sversion/bin/linux/amd64/kube-scheduler",
    [Parameter()][ValidateNotNullorEmpty()][URI]$kubectlUnixDownloadURL = "https://storage.googleapis.com/kubernetes-release/release/$k8sversion/bin/linux/amd64/kubectl",
    [Parameter()][ValidateNotNullorEmpty()][URI]$criCtlDownloadURL = "https://github.com/kubernetes-sigs/cri-tools/releases/download/$k8sversionMajor/crictl-$k8sversionMajor-linux-amd64.tar.gz",
    [Parameter()][ValidateNotNullorEmpty()][URI]$runScDownloadURL = "https://storage.googleapis.com/kubernetes-the-hard-way/runsc-$runScVersion",
    [Parameter()][ValidateNotNullorEmpty()][URI]$runCDownloadURL = "https://github.com/opencontainers/runc/releases/download/$runCVersion/runc.amd64",
    [Parameter()][ValidateNotNullorEmpty()][URI]$cniDownloadURL = "https://github.com/containernetworking/plugins/releases/download/$cniVersion/cni-plugins-linux-amd64-$cniVersion.tgz",
    [Parameter()][ValidateNotNullorEmpty()][URI]$containerdDownloadURL = "https://github.com/containerd/containerd/releases/download/v$containerdVersion/containerd-$containerdVersion.linux-amd64.tar.gz",
    [Parameter()][ValidateNotNullorEmpty()][URI]$kubeProxyDownloadURL = "https://storage.googleapis.com/kubernetes-release/release/$k8sversion/bin/linux/amd64/kube-proxy",
    [Parameter()][ValidateNotNullorEmpty()][URI]$kubeletDownloadURL = "https://storage.googleapis.com/kubernetes-release/release/$k8sversion/bin/linux/amd64/kubelet",
    [Parameter()][ValidateNotNullorEmpty()][URI]$coreDnsYamlURL = 'https://storage.googleapis.com/kubernetes-the-hard-way/coredns.yaml',
    [Parameter()][ValidateNotNullorEmpty()][URI]$K8sDashboardDownloadURL = 'https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml'
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message 'Starting the generation of a kubernetes cluster in Azure' -Source $CmdletName -Severity 1 -ScriptSection 'Initialization'

  Set-K8sWorkingDir -Directory $ConfigFilesDirectory
  
  if($downloadClientTools)
  {
    Get-K8sClientTools
  }

  Select-K8sAzureAccount -subscription $AzureSubscription -region $AzureRegion

  New-K8sAzureResources -ResourceGroup $resourceGroup -Location $AzureRegion -ClusterName $clusterName -WorkerNodeCount $workerNodes -WorkerNodeSize $workerSize -WorkerDataDiskSize $workerDataDiskSize -ControlNodeCount $controllerNodes -ControlNodeSize $controllerSize -ControlDataDiskSize $controllerDataDiskSize -OS $ubuntuVersion -AdminUser $adminUsername -AdminSSHKey $adminSSHPublicKeyPath

  New-K8sSshClientConfig -NodeType 'worker' -ResourceGroup $resourceGroup -AdminUser $adminUsername -NodeCount $workerNodes -ClusterName $clusterName
  New-K8sSshClientConfig -NodeType 'controller' -ResourceGroup $resourceGroup -AdminUser $adminUsername -NodeCount $controllerNodes -ClusterName $clusterName

  Install-K8sPrerequisites -DockerVersion $dockerVersion -TimeZone $timezone -NodeType 'controller' -NodeCount $controllerNodes -ClusterName $clusterName
  Install-K8sPrerequisites -DockerVersion $dockerVersion -TimeZone $timezone -NodeType 'worker' -NodeCount $workerNodes -ClusterName $clusterName

  Build-K8sCertificates -ResourceGroup $resourceGroup -WorkerNodeCount $workerNodes -ControllerNodeCount $controllerNodes -clusterName $clusterName
  Deploy-K8sCertificates -WorkerNodeCount $workerNodes -ControllerNodeCount $controllerNodes -ClusterName $clusterName
  
  Build-K8sConfigFiles -WorkerNodeCount $workerNodes -ClusterName $clusterName -ResourceGroup $resourceGroup
  Deploy-K8sConfigFiles -WorkerNodeCount $workerNodes -ControllerNodeCount $controllerNodes -ClusterName $clusterName

  New-K8sEtcdEncryptionConfig
  Deploy-K8sEtcdEncryptionConfig -ControllerNodeCount $controllerNodes -ClusterName $clusterName

  New-K8sEtcdCluster -ControllerNodeCount $controllerNodes -ResourceGroup $resourceGroup -EtcdDownloadUrl $etcdDownloadURL -EtcdVersion $etcdVersion -ClusterName $clusterName

  New-K8sControlPlane -ControllerNodeCount $controllerNodes -K8sApiDownloadUrl $kubeApiDownloadURL -K8sControllerDownloadUrl $kubeControllerDownloadURL -K8sSchedulerDownloadUrl $kubeSchedulerDownloadURL -K8sCtlDownloadUrl $kubeCtlUnixDownloadURL -ClusterName $clusterName
  
  Deploy-K8sRbacConfig -ClusterName $clusterName

  New-K8sWorkerPlane -resourceGroup $resourceGroup -WorkerNodeCount $workerNodes -CriCtlDownloadUrl $criCtlDownloadURL -RunScDownloadUrl $runScDownloadURL -RunCDownloadUrl $runCDownloadURL -CniDownloadUrl $cniDownloadURL -ContainerDDownloadUrl $containerdDownloadURL -K8sCtlDownloadUrl $kubectlUnixDownloadURL -K8sProxyDownloadUrl $kubeProxyDownloadURL -KubeletDownloadUrl $kubeletDownloadURL -RunScVersion $runScVersion -K8sVersionMajor $k8sversionMajor -CniVersion $cniVersion -ContainerDVersion $containerdVersion -clusterName $clusterName

  Set-K8sKubeCtlConfig -ClusterName $clusterName -ResourceGroup $resourceGroup

  New-K8sPodNetworkRoute -ResourceGroup $resourceGroup -ClusterName $clusterName -WorkerNodeCount $workerNodes

  Deploy-K8sDnsClusterAddOn -CoreDnsYamlUrl $coreDnsYamlURL

  Deploy-K8sDashboard -K8sDashboardDownloadURL $K8sDashboardDownloadURL -ConfigFilesDirectory $ConfigFilesDirectory

  Write-Log -Message 'The kubernetes cluster is ready! :D' -Source $CmdletName -Severity 1 -ScriptSection 'Initialization'

}