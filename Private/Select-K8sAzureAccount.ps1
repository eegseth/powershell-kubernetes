function Select-K8sAzureAccount {
  <#
  .SYNOPSIS
    Verifies and if needed, selects the correct azure account/subscription
  .EXAMPLE
    Select-K8sAzureAccount -subscription 'MSDN' -region 'NorthEurope'
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$subscription,
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$region
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters

  Write-Log -Message "Logging in to azure / selecting the correct subscription ($subscription)" -Source $CmdletName -Severity 1 -ScriptSection 'Prerequisites'

  try
  {
    if ((((az account list --all) | convertfrom-json).name) -notcontains $subscription)
    {
      az login
    }
    az account set --subscription $subscription
    az configure --default region=$region

    if ((((az account list --all) | convertfrom-json).name) -notcontains $subscription)
    {
      Throw 'Failed to set Azure subscription'
    }

    Return 0

  }catch
  {
    Write-Log -Message "Failed to log in to Azure/select subscription in Azure. Tried to use $subscription" -Source $CmdletName -Severity 3 -ScriptSection 'Prerequisites'
    Break
  }
}