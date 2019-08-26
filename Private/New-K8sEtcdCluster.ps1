function New-K8sEtcdCluster {
  <#
  .SYNOPSIS
    Bootstraps the ETCD cluster for kubernetes
  .EXAMPLE
    New-K8sEtcdCluster -ControllerNodeCount 3 -ResourceGroup 'kube' -EtcdDownloadUrl 'https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz' -EtcdVersion 'v3.3.9'
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$ControllerNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ResourceGroup,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$EtcdDownloadUrl,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$EtcdVersion,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$clusterName
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message 'Bootstrapping the etcd cluster' -Source $CmdletName -Severity 1 -ScriptSection 'Installation - etcd'

  try
  {
    for ($i=0; $i -lt $ControllerNodeCount; $i++)
    {
      if(!([string](az vm show --show-details -g $resourceGroup -n ('{0}-controller-{1}' -f $clusterName, $i) | select-string privateIps) -match '\d{2,3}\.(\d{1,3}\.){2}\d{1,3}'))
      {
        Throw 'Failed to fetch IP from Azure'
      }
      if($LASTEXITCODE)
      {
        Throw 'Failed to fetch IP from Azure'
      }
      [string]$intip = $matches[0]
      $initialcluster += ('{0}-controller-{1}=https://{2}:2380,' -f $clusterName, $i, $intip)
      $initialclusterIp += ('https://{0}:2379,' -f $intip)
    }

    $initialcluster=$initialcluster.Trim(',')
    $initialclusterIp=$initialclusterIp.Trim(',')

    for ($i=0; $i -lt $ControllerNodeCount; $i++)
    {
      if(!([string](az vm show --show-details -g $resourceGroup -n ('{0}-controller-{1}' -f $clusterName, $i) | select-string privateIps) -match '\d{2,3}\.(\d{1,3}\.){2}\d{1,3}'))
      {
        Throw 'Failed to fetch IP from Azure'
      }
      if($LASTEXITCODE)
      {
        Throw 'Failed to fetch IP from Azure'
      }
      [string]$intip = $matches[0]

      $intip2380=$intip+":2380"
      $intip2379=$intip+":2379"

      $sshCommands = @"
ETCD_NAME=`$(hostname -s);
wget -q --https-only --timestamping $etcdDownloadURL;
tar -xvf etcd-$etcdVersion-linux-amd64.tar.gz;
sudo mv etcd-$etcdVersion-linux-amd64/etcd* /usr/local/bin/;
sudo mkdir -p /etc/etcd /var/lib/etcd;
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/;
cat <<EOF | sudo tee /etc/systemd/system/etcd.service;
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name `${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://$intip2380 \\
  --listen-peer-urls https://$intip2380 \\
  --listen-client-urls https://$intip2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://$intip2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster $initialcluster \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload;
sudo systemctl enable etcd;
sudo systemctl start etcd;
"@

      #The behaviour of line endings on cross-platform gives me nightmares! Just standardize it ffs!
      (get-variable -name sshCommands -ValueOnly).Replace("`r`n","`n") | Set-Variable -Name sshCommands
    
      ssh -o StrictHostKeyChecking=no $clusterName-controller-$i $sshCommands
      if($LASTEXITCODE)
      {
        Throw 'ETCD cluster bootstrap error!'
      }
    }

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to bootstrap the etcd cluster.' -Source $CmdletName -Severity 3 -ScriptSection 'Installation - etcd'
    Break
  }
  
}