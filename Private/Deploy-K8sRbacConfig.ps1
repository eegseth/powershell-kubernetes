function Deploy-K8sRbacConfig {
  <#
  .SYNOPSIS
    Sets up rbac in the kubernees cluster
  .EXAMPLE
    Deploy-K8sRbacConfig
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$clusterName
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message 'Setting up RBAC' -Source $CmdletName -Severity 1 -ScriptSection 'Installation - k8s control plane'

  $sshCommands = @"
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -;
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: \"true\"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - \"\"
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - \"*\"
EOF
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -;
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: \"\"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
"@

  try
  {
    #The behaviour of line endings on cross-platform gives me nightmares! Just standardize it ffs!
    (get-variable -name sshCommands -ValueOnly).Replace("`r`n","`n") | Set-Variable -Name sshCommands

    ssh -o StrictHostKeyChecking=no $clusterName-controller-0 $sshCommands

    if($LASTEXITCODE)
    {
      Throw 'Kubernetes RBAC setup error!'
    }

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to set up RBAC' -Source $CmdletName -Severity 3 -ScriptSection 'Installation - k8s control plane'
    Break
  }
  
}