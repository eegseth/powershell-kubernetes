Function Write-Log
{
  <#
  .SYNOPSIS
    Write messages in CMTrace.exe compatible format.
  .EXAMPLE
    Write-Log -Message "Installing patch MS15-031" -Source 'Add-Patch'
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][AllowEmptyCollection()][string[]]$Message,
    [Parameter(Mandatory=$false,Position=1)][ValidateRange(1,3)][int16]$Severity = 1,
    [Parameter(Mandatory=$false,Position=2)][ValidateNotNull()][string]$Source = '',
    [Parameter(Mandatory=$false,Position=3)][ValidateNotNullorEmpty()][string]$ScriptSection = 'Deploy',
    [Parameter(Mandatory=$false,Position=6)][switch]$PassThru = $false,
    [Parameter(Mandatory=$false,Position=7)][hashtable]$CmdletBoundParameters
  )

  ## Get the name of this function
  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        
  ## Logging Variables
  #  Log file date/time
  [string]$LogTime = (Get-Date -Format 'HH:mm:ss.fff').ToString()
  [string]$LogDate = (Get-Date -Format 'yyyy-MM-dd').ToString()
  #  Check if the script section is defined
  [boolean]$ScriptSectionDefined = [boolean](-not [string]::IsNullOrEmpty($ScriptSection))
  #  Get the file name of the source script
  Try {
    If ($script:MyInvocation.Value.ScriptName) {
      [string]$ScriptSource = Split-Path -Path $script:MyInvocation.Value.ScriptName -Leaf -ErrorAction 'Stop'
    }
    Else {
      [string]$ScriptSource = Split-Path -Path $script:MyInvocation.MyCommand.Definition -Leaf -ErrorAction 'Stop'
    }
  }
  Catch {
    $ScriptSource = ''
  }

  ForEach ($Msg in $Message)
  {
    ## If the message is not $null or empty, create the log entry
    [string]$LegacyTextLogLine = ''
    If ($Msg) {

      [string]$LegacyMsg = "[$LogDate $LogTime]"
      If ($ScriptSectionDefined) { [string]$LegacyMsg += " [$ScriptSection]" }
      If ($Source) {
        Switch ($Severity) {
          3 { [string]$LegacyTextLogLine = ('{0} [{1}] [Error] :: {2} {3}' -f $LegacyMsg, $Source, $Msg, (resolve-error)) }
          2 { [string]$LegacyTextLogLine = ('{0} [{1}] [Warning] :: {2}' -f $LegacyMsg, $Source, $Msg) }
          1 { [string]$LegacyTextLogLine = ('{0} [{1}] [Info] :: {2}' -f $LegacyMsg, $Source, $Msg) }
        }
      }
      Else {
        Switch ($Severity) {
          3 { [string]$LegacyTextLogLine = ('{0} [Error] :: {1} {2}' -f $LegacyMsg, $Msg, (resolve-error)) }
          2 { [string]$LegacyTextLogLine = ('{0} [Warning] :: {2}' -f $LegacyMsg, $Source, $Msg) }
          1 { [string]$LegacyTextLogLine = ('{0} [Info] :: {2}' -f $LegacyMsg, $Source, $Msg) }
        }
      }
    }
    
    if($CmdletBoundParameters)
    {
      [string]$CmdletBoundParameters = $CmdletBoundParameters | Format-Table -Property @{ Label = 'Parameter'; Expression = { "[-$($_.Key)]" } }, @{ Label = 'Value'; Expression = { $_.Value }; Alignment = 'Left' } -AutoSize -Wrap | Out-String
      [string]$LogLine = $LegacyTextLogLine +"`n$CmdletBoundParameters"
    }
    else
    {
      [string]$LogLine = $LegacyTextLogLine
    }
    
    Write-Output $LogLine

    }
}