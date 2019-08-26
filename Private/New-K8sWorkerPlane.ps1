function New-K8sWorkerPlane {
  <#
  .SYNOPSIS
    Bootstraps the kubernetes worker nodes
  .EXAMPLE
    New-K8sWorkerPlane -WorkerNodeCount 3 -CriCtlDownloadUrl 'https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.14.0/crictl-v1.14.0-linux-amd64.tar.gz' -RunScDownloadUrl 'https://storage.googleapis.com/kubernetes-the-hard-way/runsc-50c283b9f56bb7200938d9e207355f05f79f0d17' -RunCDownloadUrl 'https://github.com/opencontainers/runc/releases/download/v1.0.0-rc5/runc.amd64' -CniDownloadUrl 'https://github.com/containernetworking/plugins/releases/download/v0.8.1/cni-plugins-amd64-v0.8.1.tgz' -ContainerDDownloadUrl 'https://github.com/containerd/containerd/releases/download/v1.2.7/containerd-1.2.7.linux-amd64.tar.gz' -K8sCtlDownloadUrl 'https://storage.googleapis.com/kubernetes-release/release/v1.14.4/bin/linux/amd64/kubectl' -K8sProxyDownloadUrl 'https://storage.googleapis.com/kubernetes-release/release/v1.14.4/bin/linux/amd64/kube-proxy' -KubeletDownloadUrl 'https://storage.googleapis.com/kubernetes-release/release/v1.14.4/bin/linux/amd64/kubelet' -RunScVersion '50c283b9f56bb7200938d9e207355f05f79f0d17' -K8sVersionMajor 'v1.14.0' -CniVersion 'v0.8.1' -ContainerDVersion '1.2.7'
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$resourceGroup,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$WorkerNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$CriCtlDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$RunScDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$RunCDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$CniDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$ContainerDDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$K8sCtlDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$K8sProxyDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$KubeletDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$RunScVersion,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$K8sVersionMajor,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$CniVersion,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ContainerDVersion,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$clusterName
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message 'Bootstrapping the kubernetes worker nodes' -Source $CmdletName -Severity 1 -ScriptSection 'Installation - k8s worker nodes'

  try
  {
    for ($i=0; $i -lt $WorkerNodeCount; $i++){

      if(!((az vm show --show-details -g $resourceGroup -n "$clusterName-worker-$i" | select-string 'podCidr') -match '\d{2,3}\.(\d{1,3}\.){2}\d{1,3}/\d{1,2}'))
      {
        Throw 'Failed to fetch IP range for pods from Azure tag on VM'
      }
      $podcidr = $Matches[0]

      $sshCommands = @"
wget -q --https-only --timestamping $criCtlDownloadURL $runScDownloadURL $runCDownloadURL $cniDownloadURL $containerdDownloadURL $K8sCtlDownloadUrl $K8sProxyDownloadUrl $kubeletDownloadURL;
sudo mkdir -p /etc/cni/net.d /opt/cni/bin /var/lib/kubelet /var/lib/kube-proxy /var/lib/kubernetes;
sudo mkdir -p /var/run/kubernetes;
sudo mkdir -p /etc/kubernetes;
sudo mv runsc-$runScVersion runsc;
sudo mv runc.amd64 runc;
chmod +x kubectl kube-proxy kubelet runc runsc
sudo mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/;
sudo tar -xvf crictl-$k8sversionMajor-linux-amd64.tar.gz -C /usr/local/bin/;
sudo tar -xvf cni-plugins-linux-amd64-$cniVersion.tgz -C /opt/cni/bin/;
sudo tar -xvf containerd-$containerdVersion.linux-amd64.tar.gz -C /;
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf;
{
    \"cniVersion\": \"0.3.1\",
    \"name\": \"bridge\",
    \"type\": \"bridge\",
    \"bridge\": \"cnio0\",
    \"isGateway\": true,
    \"ipMasq\": true,
    \"ipam\": {
        \"type\": \"host-local\",
        \"ranges\": [
          [{\"subnet\": \"$podcidr\"}]
        ],
        \"routes\": [{\"dst\": \"0.0.0.0/0\"}]
    }
}
EOF
cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf;
{
    \"cniVersion\": \"0.3.1\",
    \"type\": \"loopback\"
}
EOF
sudo mkdir -p /etc/containerd/;
cat << EOF | sudo tee /etc/containerd/config.toml;
[plugins]
  [plugins.cri.containerd]
    snapshotter = \"overlayfs\"
    [plugins.cri.containerd.default_runtime]
      runtime_type = \"io.containerd.runtime.v1.linux\"
      runtime_engine = \"/usr/local/bin/runc\"
      runtime_root = \"\"
    [plugins.cri.containerd.untrusted_workload_runtime]
      runtime_type = \"io.containerd.runtime.v1.linux\"
      runtime_engine = \"/usr/local/bin/runsc\"
      runtime_root = \"/run/containerd/runsc\"
    [plugins.cri.containerd.gvisor]
      runtime_type = \"io.containerd.runtime.v1.linux\"
      runtime_engine = \"/usr/local/bin/runsc\"
      runtime_root = \"/run/containerd/runsc\"
EOF
cat <<EOF | sudo tee /etc/systemd/system/containerd.service;
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
sudo cp `${HOSTNAME}-key.pem `${HOSTNAME}.pem /var/lib/kubelet/;
sudo cp `${HOSTNAME}-key.pem `${HOSTNAME}.pem /etc/ssl/;
sudo cp `${HOSTNAME}-key.pem `${HOSTNAME}.pem /etc/ssl/certs/;
sudo cp `${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig;
sudo mv `${HOSTNAME}.kubeconfig /etc/kubernetes/kubeconfig;
sudo cp ca.pem /var/lib/kubernetes/;
sudo cp ca.pem /etc/ssl/;
sudo mv ca.pem /etc/ssl/certs;
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml;
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: \"/var/lib/kubernetes/ca.pem\"
authorization:
  mode: Webhook
clusterDomain: \"cluster.local\"
clusterDNS:
  - \"10.32.0.10\"
podCIDR: \"$podcidr\"
resolvConf: \"/run/systemd/resolve/resolv.conf\"
runtimeRequestTimeout: \"15m\"
tlsCertFile: \"/var/lib/kubelet/`${HOSTNAME}.pem\"
tlsPrivateKeyFile: \"/var/lib/kubelet/`${HOSTNAME}-key.pem\"
EOF
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service;
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig;
cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml;
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: \"/var/lib/kube-proxy/kubeconfig\"
mode: \"iptables\"
clusterCIDR: \"10.200.0.0/16\"
EOF
cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service;
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload;
sudo systemctl enable containerd kubelet kube-proxy;
sudo systemctl start containerd kubelet kube-proxy;
"@

      #The behaviour of line endings on cross-platform gives me nightmares! Just standardize it ffs!
      (get-variable -name sshCommands -ValueOnly).Replace("`r`n","`n") | Set-Variable -Name sshCommands

      ssh -o StrictHostKeyChecking=no $clusterName-worker-$i $sshCommands
      if($LASTEXITCODE)
      {
        Throw 'Worker plane bootstrap error!'
      }
    }

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to bootstrap the kubernetes worker nodes.' -Source $CmdletName -Severity 3 -ScriptSection 'Installation - k8s worker nodes'
    Break
  }
  
}