function Deploy-K8sDashboard {
  <#
  .SYNOPSIS
    Sets up and configures access to the kubernetes dashboard
  .EXAMPLE
    Deploy-K8sDashboard
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][URI]$K8sDashboardDownloadURL,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$ConfigFilesDirectory
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message 'Deploying the kubernetes dashboard' -Source $CmdletName -Severity 1 -ScriptSection 'Configuration - kubernetes dashboard'

  try
  {
    kubectl apply -f $K8sDashboardDownloadURL
    if($LASTEXITCODE)
    {
      throw 'Failed to deploy the kubernetes dashboard'
    }
  }
  catch
  {
    Write-Log -Message 'Failed to deploy the kubernetes dashboard' -Source $CmdletName -Severity 2 -ScriptSection 'Configuration - kubernetes dashboard'
    Return 1
  }

  $dashboardConfig = @"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
"@

  try
  {
    $dashboardConfig | kubectl apply -f -
    if($LASTEXITCODE)
    {
      throw 'Failed to create the admin user for kubernetes dashboard'
    }
  }
  catch
  {
    Write-Log -Message 'Failed to create the admin user for kubernetes dashboard | The dashboard wont be operational' -Source $CmdletName -Severity 2 -ScriptSection 'Configuration - kubernetes dashboard'
    Return 1
  }
  

  try
  {
    $userToken = (((kubectl -n kube-system describe secret $(((kubectl -n kube-system get secret | select-string 'admin-user') -Split(' '))[0]) | select-string 'token:') -split(':'))[1]).Trim()
    if($LASTEXITCODE -or !($userToken))
    {
      throw 'Failed to fetch the user token for the admin user to be granted access to the kubernetes dashboard | The dashboard wont be operational'
    }
  }
  catch
  {
    Write-Log -Message 'Failed to fetch the user token for the admin user to be granted access to the kubernetes dashboard | The dashboard wont be operational' -Source $CmdletName -Severity 2 -ScriptSection 'Configuration - kubernetes dashboard'
    Return 1
  }

  try
  {
    $kubeConfigPath = join-path -Path $ConfigFilesDirectory -ChildPath 'config' -ErrorAction Stop

    $kubeConfig = @"
    token: $userToken
"@

    $kubeConfig | Out-File $kubeConfigPath -Append -Force -ErrorAction Stop
  }
  catch
  {
    Write-Log -Message "Failed to append the user token to the kubernetes client config at $kubeConfigPath | The dashboard wont be operational" -Source $CmdletName -Severity 2 -ScriptSection 'Configuration - kubernetes dashboard'
    Return 1
  }

  Write-Log -Message 'Kubernetes dashboard is deployed and configured for access with configfile' -Source $CmdletName -Severity 1 -ScriptSection 'Configuration - kubernetes dashboard'
  Write-Log -Message "Use command 'kubectl proxy' and then open browser and navigate to http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/login" -Source $CmdletName -Severity 1 -ScriptSection 'Configuration - kubernetes dashboard'

  Return 0
  
}