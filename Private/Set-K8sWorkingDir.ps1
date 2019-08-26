function Set-K8sWorkingDir {
  <#
  .SYNOPSIS
    Creates the kubernetes config dir and pops into it
  .EXAMPLE
    Set-K8sWorkingDir -Directory C:\Users\you\k8s
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][String]$Directory
  )

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters

  if(!(test-path $Directory))
  {
    Write-Log -Message 'Generating config files directory' -Source $CmdletName -Severity 1 -ScriptSection 'Prerequisites' 
    try
    {
      new-item -ItemType Directory -Path $Directory -ErrorAction Stop
    }catch
    {
      Write-Log -Message "Failed to create folder $Directory" -Source $CmdletName -Severity 3 -ScriptSection 'Prerequisites' 
      Break
    }
  }

  Write-Log -Message "Popping into the config files directory at $Directory" -Source $CmdletName -Severity 1 -ScriptSection 'Prerequisites' 
  set-location -Path $Directory
  Return 0
  
}