function Deploy-K8sDnsClusterAddOn {
  <#
  .SYNOPSIS
    Provisions the pod network route table in azure so pods can have nice conversations ;)
  .EXAMPLE
    Deploy-K8sDnsClusterAddOn -CoreDnsYamlUrl 'https://storage.googleapis.com/kubernetes-the-hard-way/coredns.yaml'
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$CoreDnsYamlUrl
  )
  
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message 'Deploying the DNS Cluster add-on (coredns)' -Source $CmdletName -Severity 1 -ScriptSection 'DNSConfiguration'

  try
  {
    kubectl apply -f $coreDnsYamlURL
    if($LASTEXITCODE)
    {
      Throw 'DNS cluster addon setup error!'
    }

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to deploy DNS cluster addon (coredns)' -Source $CmdletName -Severity 3 -ScriptSection 'DNSConfiguration'
    Break
  }
}