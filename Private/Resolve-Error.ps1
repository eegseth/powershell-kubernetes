Function Resolve-Error 
{
  <#
  .SYNOPSIS
    Enumerate error record details.
  .EXAMPLE
    Resolve-Error
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$false,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [AllowEmptyCollection()]
    [array]$ErrorRecord,
    [Parameter(Mandatory=$false,Position=1)]
    [ValidateNotNullorEmpty()]
    [string[]]$Property = ('Message','InnerException','FullyQualifiedErrorId','ScriptStackTrace','PositionMessage'),
    [Parameter(Mandatory=$false,Position=2)]
    [switch]$GetErrorRecord = $true,
    [Parameter(Mandatory=$false,Position=3)]
    [switch]$GetErrorInvocation = $true,
    [Parameter(Mandatory=$false,Position=4)]
    [switch]$GetErrorException = $true,
    [Parameter(Mandatory=$false,Position=5)]
    [switch]$GetErrorInnerException = $true
  )
  
  Begin {
    ## If function was called without specifying an error record, then choose the latest error that occurred
    If (-not $ErrorRecord) {
      If ($global:Error.Count -eq 0) {
        #Write-Warning -Message "The `$Error collection is empty"
        Return
      }
      Else {
        [array]$ErrorRecord = $global:Error[0]
      }
    }
    
    ## Allows selecting and filtering the properties on the error object if they exist
    [scriptblock]$SelectProperty = {
      Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        $InputObject,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string[]]$Property
      )
      
      [string[]]$ObjectProperty = $InputObject | Get-Member -MemberType '*Property' | Select-Object -ExpandProperty 'Name'
      ForEach ($Prop in $Property) {
        If ($Prop -eq '*') {
          [string[]]$PropertySelection = $ObjectProperty
          Break
        }
        ElseIf ($ObjectProperty -contains $Prop) {
          [string[]]$PropertySelection += $Prop
        }
      }
      Write-Output -InputObject $PropertySelection
    }
    
    #  Initialize variables to avoid error if 'Set-StrictMode' is set
    $LogErrorRecordMsg = $null
    $LogErrorInvocationMsg = $null
    $LogErrorExceptionMsg = $null
    $LogErrorMessageTmp = $null
    $LogInnerMessage = $null
  }
  Process {
    If (-not $ErrorRecord) { Return }
    ForEach ($ErrRecord in $ErrorRecord) {
      ## Capture Error Record
      If ($GetErrorRecord) {
        [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord -Property $Property
        $LogErrorRecordMsg = $ErrRecord | Select-Object -Property $SelectedProperties
      }
      
      ## Error Invocation Information
      If ($GetErrorInvocation) {
        If ($ErrRecord.InvocationInfo) {
          [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord.InvocationInfo -Property $Property
          $LogErrorInvocationMsg = $ErrRecord.InvocationInfo | Select-Object -Property $SelectedProperties
        }
      }
      
      ## Capture Error Exception
      If ($GetErrorException) {
        If ($ErrRecord.Exception) {
          [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord.Exception -Property $Property
          $LogErrorExceptionMsg = $ErrRecord.Exception | Select-Object -Property $SelectedProperties
        }
      }
      
      ## Display properties in the correct order
      If ($Property -eq '*') {
        #  If all properties were chosen for display, then arrange them in the order the error object displays them by default.
        If ($LogErrorRecordMsg) { [array]$LogErrorMessageTmp += $LogErrorRecordMsg }
        If ($LogErrorInvocationMsg) { [array]$LogErrorMessageTmp += $LogErrorInvocationMsg }
        If ($LogErrorExceptionMsg) { [array]$LogErrorMessageTmp += $LogErrorExceptionMsg }
      }
      Else {
        #  Display selected properties in our custom order
        If ($LogErrorExceptionMsg) { [array]$LogErrorMessageTmp += $LogErrorExceptionMsg }
        If ($LogErrorRecordMsg) { [array]$LogErrorMessageTmp += $LogErrorRecordMsg }
        If ($LogErrorInvocationMsg) { [array]$LogErrorMessageTmp += $LogErrorInvocationMsg }
      }
      
      If ($LogErrorMessageTmp) {
        $LogErrorMessage = 'Error Record:'
        $LogErrorMessage += "`n-------------"
        $LogErrorMsg = $LogErrorMessageTmp | Format-List | Out-String
        $LogErrorMessage += $LogErrorMsg
      }
      
      ## Capture Error Inner Exception(s)
      If ($GetErrorInnerException) {
        If ($ErrRecord.Exception -and $ErrRecord.Exception.InnerException) {
          $LogInnerMessage = 'Error Inner Exception(s):'
          $LogInnerMessage += "`n-------------------------"
          
          $ErrorInnerException = $ErrRecord.Exception.InnerException
          $Count = 0
          
          While ($ErrorInnerException) {
            [string]$InnerExceptionSeperator = '~' * 40
            
            [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrorInnerException -Property $Property
            $LogErrorInnerExceptionMsg = $ErrorInnerException | Select-Object -Property $SelectedProperties | Format-List | Out-String
            
            If ($Count -gt 0) { $LogInnerMessage += $InnerExceptionSeperator }
            $LogInnerMessage += $LogErrorInnerExceptionMsg
            
            $Count++
            $ErrorInnerException = $ErrorInnerException.InnerException
          }
        }
      }
      
      If ($LogErrorMessage) { $Output = $LogErrorMessage }
      If ($LogInnerMessage) { $Output += $LogInnerMessage }
      
      Write-Output -InputObject $Output
      
      If (Test-Path -LiteralPath 'variable:Output') { Clear-Variable -Name 'Output' }
      If (Test-Path -LiteralPath 'variable:LogErrorMessage') { Clear-Variable -Name 'LogErrorMessage' }
      If (Test-Path -LiteralPath 'variable:LogInnerMessage') { Clear-Variable -Name 'LogInnerMessage' }
      If (Test-Path -LiteralPath 'variable:LogErrorMessageTmp') { Clear-Variable -Name 'LogErrorMessageTmp' }
    }
  }
  End {
  }
}