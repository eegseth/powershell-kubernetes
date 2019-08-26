function New-K8sControlPlane {
  <#
  .SYNOPSIS
    Bootstraps the kubernetes control plane
  .EXAMPLE
    New-K8sControlPlane -ControllerNodeCount 3 -K8sApiDownloadUrl 'https://storage.googleapis.com/kubernetes-release/release/v1.14.4/bin/linux/amd64/kube-apiserver' -K8sControllerDownloadUrl 'https://storage.googleapis.com/kubernetes-release/release/v1.14.4/bin/linux/amd64/kube-controller-manager' -K8sSchedulerDownloadUrl 'https://storage.googleapis.com/kubernetes-release/release/v1.14.4/bin/linux/amd64/kube-scheduler' -K8sCtlDownloadUrl 'https://storage.googleapis.com/kubernetes-release/release/v1.14.4/bin/linux/amd64/kubectl'
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$ControllerNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$K8sApiDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$K8sControllerDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$K8sSchedulerDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$K8sCtlDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ClusterName
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message 'Bootstrapping the kubernetes control plane' -Source $CmdletName -Severity 1 -ScriptSection 'Installation - k8s control plane'

  try
  {

    for ($i=0; $i -lt $ControllerNodeCount; $i++)
    {
      if(!((az vm show --show-details -g $resourceGroup -n ('{0}-controller-{1}' -f $clusterName, $i) | select-string privateIps) -match '\d{2,3}\.(\d{1,3}\.){2}\d{1,3}'))
      {
        Throw 'Failed to fetch IP from Azure'
      }
      if($LASTEXITCODE)
      {
        Throw 'Failed to fetch IP from Azure'
      }
      $intip = $matches[0]
      $initialclusterIp += ('https://{0}:2379,' -f $intip)
    }
    $initialclusterIp=$initialclusterIp.Trim(',')

    for ($i=0; $i -lt $ControllerNodeCount; $i++)
    {
      if(!((az vm show --show-details -g $resourceGroup -n ('{0}-controller-{1}' -f $clusterName, $i) | select-string privateIps) -match '\d{2,3}\.(\d{1,3}\.){2}\d{1,3}'))
      {
        Throw 'Failed to fetch IP from Azure'
      }
      if($LASTEXITCODE)
      {
        Throw 'Failed to fetch IP from Azure'
      }
      $intip = $matches[0]

      $sshCommands = @"
sudo mkdir -p /etc/kubernetes/config;
wget -q --https-only --timestamping $K8sApiDownloadUrl $K8sControllerDownloadUrl $K8sSchedulerDownloadUrl $K8sCtlDownloadUrl;
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl;
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/;
sudo mkdir -p /var/lib/kubernetes/;
sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem encryption-config.yaml /var/lib/kubernetes/;
cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service;
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=$intip \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=$initialclusterIp \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/;
cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service;
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5
  
[Install]
WantedBy=multi-user.target
EOF
sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/;
cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml;
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: \"/var/lib/kubernetes/kube-scheduler.kubeconfig\"
leaderElection:
  leaderElect: true
EOF
cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service;
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload;
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler;
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler;
sleep 10;
sudo apt-get install -y nginx;
cat > kubernetes.default.svc.cluster.local <<EOF;
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF
sudo mv kubernetes.default.svc.cluster.local /etc/nginx/sites-available/kubernetes.default.svc.cluster.local;
sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/;
sudo systemctl restart nginx;
sudo systemctl enable nginx;
"@

      #The behaviour of line endings on cross-platform gives me nightmares! Just standardize it ffs!
      (get-variable -name sshCommands -ValueOnly).Replace("`r`n","`n") | Set-Variable -Name sshCommands

      ssh -o StrictHostKeyChecking=no $clusterName-controller-$i $sshCommands
      if($LASTEXITCODE)
      {
        Throw 'Controlplane bootstrap error!'
      }
    }

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to bootstrap the kubernetes control plane' -Source $CmdletName -Severity 3 -ScriptSection 'Installation - k8s control plane'
    Break
  }

}