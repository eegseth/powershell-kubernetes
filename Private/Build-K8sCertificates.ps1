function Build-K8sCertificates {
  <#
  .SYNOPSIS
    Generates the required certificates for the kubernetes cluster. Requires CloudFlare's ssl tools. (cfssl and cfssljson)
  .EXAMPLE
    Build-K8sCertificates -ResourceGroup 'kube' -ControllerNodeCount 3 -WorkerNodeCount 3 -clusterName 'k8s'
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ResourceGroup,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$ControllerNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][int]$WorkerNodeCount,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$clusterName
  )
  
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message "Generating certificates for the kubernetes cluster" -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'

  #CA
  Write-Log -Message "Setting up and configuring certificates for CA" -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'
  $caconfig = @"
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
"@

  $cacsr = @"
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NO",
      "L": "Trondheim",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Trondelag"
    }
  ]
}
"@

  try
  {
    $caconfig | out-file ca-config.json -Force -Encoding utf8
    $cacsr | out-file ca-csr.json -Force -Encoding utf8
    
    cfssl gencert -initca ca-csr.json | cfssljson -bare ca

    if($LASTEXITCODE)
    {
      Throw 'Certificate generation error!'
    }

  }catch
  {
    Write-Log -Message 'Failed to generate CA certificates.' -Source $CmdletName -Severity 3 -ScriptSection 'Certificates'
    Break
  }


  #Client admin
  Write-Log -Message 'Setting up and configuring certificates for client admin' -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'
  $admincsr = @"
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NO",
      "L": "Trondheim",
      "O": "system:masters",
      "OU": "Kubernetes",
      "ST": "Trondelag"
    }
  ]
}
"@

  try
  {
    $admincsr | out-file admin-csr.json -Force -Encoding utf8

    cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -profile="kubernetes" "admin-csr.json" | cfssljson -bare admin

    if($LASTEXITCODE)
    {
      Throw 'Certificate generation error!'
    }

  }catch
  {
    Write-Log -Message 'Failed to generate admin certificates.' -Source $CmdletName -Severity 3 -ScriptSection 'Certificates'
    Break
  }

  #Kubelet client
  Write-Log -Message 'Setting up and configuring certificates for kubelet client' -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'
  for ($i=0; $i -lt $WorkerNodeCount; $i++)
  {
    $instance = ('{0}-worker-{1}' -f $clusterName, $i)
    $kubeletcsr = @"
{
  "CN": "system:node:$instance",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NO",
      "L": "Trondheim",
      "O": "system:nodes",
      "OU": "Kubernetes",
      "ST": "Trondelag"
    }
  ]
}
"@

    try
    {
      $kubeletcsr | out-file ('{0}-worker-{1}-csr.json' -f $clusterName, $i) -Force -Encoding utf8
      if(!([string](az vm show --show-details -g $resourceGroup -n $instance | select-string publicIps) -match '\d{2,3}\.(\d{1,3}\.){2}\d{1,3}'))
      {
        Throw 'Failed to fetch IP from Azure'
      }
      if($LASTEXITCODE)
      {
        Throw 'Failed to fetch IP from Azure'
      }
      [string]$external_ip = $matches[0]

      if(!([string](az vm show --show-details -g $resourceGroup -n $instance | select-string privateIps) -match '\d{2,3}\.(\d{1,3}\.){2}\d{1,3}'))
      {
        Throw 'Failed to fetch IP from Azure'
      }
      if($LASTEXITCODE)
      {
        Throw 'Failed to fetch IP from Azure'
      }
      [string]$internal_ip = $matches[0]

      cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -hostname="$instance,$external_ip,$internal_ip" -profile="kubernetes" "$instance-csr.json" | cfssljson -bare $instance

      if($LASTEXITCODE)
      {
        Throw 'Certificate generation error!'
      }
      
    }catch
    {
      Write-Log -Message 'Failed to generate kubelet certificates' -Source $CmdletName -Severity 3 -ScriptSection 'Certificates'
      Break
    }
    
  }

  #Controller manager client
  Write-Log -Message 'Setting up and configuring certificates for controller manager client' -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'
  $controllermanagercsr = @"
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NO",
      "L": "Trondheim",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes",
      "ST": "Trondelag"
    }
  ]
}
"@

  try
  {
    $controllermanagercsr | out-file 'kube-controller-manager-csr.json' -Force -Encoding utf8

    cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -profile="kubernetes" "kube-controller-manager-csr.json" | cfssljson -bare kube-controller-manager  

    if($LASTEXITCODE)
    {
      Throw 'Certificate generation error!'
    }

  }catch
  {
    Write-Log -Message 'Failed to generate controllermanager certificates.' -Source $CmdletName -Severity 3 -ScriptSection 'Certificates'
    Break
  }

  #Kube proxy client
  Write-Log -Message 'Setting up and configuring certificates for kube proxy client' -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'
  $kubeproxycsr = @"
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NO",
      "L": "Trondheim",
      "O": "system:node-proxier",
      "OU": "Kubernetes",
      "ST": "Trondelag"
    }
  ]
}
"@

  try
  {
    $kubeproxycsr | out-file 'kube-proxy-csr.json' -Force -Encoding utf8

    cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -profile="kubernetes" "kube-proxy-csr.json" | cfssljson -bare kube-proxy  

    if($LASTEXITCODE)
    {
      Throw 'Certificate generation error!'
    }

  }catch
  {
    Write-Log -Message 'Failed to generate kubeproxy certificates.' -Source $CmdletName -Severity 3 -ScriptSection 'Certificates'
    Break
  }

  #Scheduler client
  Write-Log -Message 'Setting up and configuring certificates for scheduler client' -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'
  $schedulercsr = @"
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NO",
      "L": "Trondheim",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes",
      "ST": "Trondelag"
    }
  ]
}
"@

  try
  {
    $schedulercsr | out-file 'kube-scheduler-csr.json' -Force -Encoding utf8

    cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -profile="kubernetes" "kube-scheduler-csr.json" | cfssljson -bare kube-scheduler

    if($LASTEXITCODE)
    {
      Throw 'Certificate generation error!'
    }

  }catch
  {
    Write-Log -Message 'Failed to generate kube scheduler certificates.' -Source $CmdletName -Severity 3 -ScriptSection 'Certificates'
    Break
  }

  #API server
  Write-Log -Message 'Setting up and configuring certificates for API server' -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'
  $apiservercsr = @"
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NO",
      "L": "Trondheim",
      "O": "Kubernetes",
      "OU": "Kubernetes",
      "ST": "Trondelag"
    }
  ]
}
"@

  try
  {
    $apiservercsr | out-file 'kubernetes-csr.json' -Force -Encoding utf8

    if(!([string](az network public-ip show -g $resourceGroup -n $clusterName-ip | select-string ipAddress) -match '\d{2,3}\.(\d{1,3}\.){2}\d{1,3}'))
    {
      Throw 'Failed to fetch IP from Azure'
    }
    if($LASTEXITCODE)
    {
      Throw 'Failed to fetch IP from Azure'
    }
    [string]$ip = $matches[0]

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
      [string]$ips += $matches[0]+","
    }

    $hostnamescert = ('{0}10.32.0.1,{1},127.0.0.1,kubernetes.default' -f $ips, $ip)

    cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -hostname="$hostnamescert" -profile="kubernetes" "kubernetes-csr.json" | cfssljson -bare kubernetes

    if($LASTEXITCODE)
    {
      Throw 'Certificate generation error!'
    }
    
  }catch
  {
    Write-Log -Message 'Failed to generate API server certificates.' -Source $CmdletName -Severity 3 -ScriptSection 'Certificates'
    Break
  }

  #Service account key pair
  Write-Log -Message 'Setting up and configuring certificates for service account key pair' -Source $CmdletName -Severity 1 -ScriptSection 'Certificates'
  $serviceaccountcsr = @"
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NO",
      "L": "Trondheim",
      "O": "Kubernetes",
      "OU": "Kubernetes",
      "ST": "Trondelag"
    }
  ]
}
"@

  try
  {
    $serviceaccountcsr | out-file 'service-account-csr.json' -Force -Encoding utf8

    cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -profile="kubernetes" "service-account-csr.json" | cfssljson -bare service-account

    if($LASTEXITCODE)
    {
      Throw 'Certificate generation error!'
    }

  }catch
  {
    Write-Log -Message 'Failed to generate service account config and certificates.' -Source $CmdletName -Severity 3 -ScriptSection 'Certificates'
    Break
  }

  Return 0
  
}