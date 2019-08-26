function Get-K8sClientTools {
  <#
  .SYNOPSIS
    Fetches the required client tools for generating the kubernetes cluster from zeh interwebz
  .EXAMPLE
    Get-K8sClientTools -Directory
  #>
  [CmdletBinding()]
  Param ()

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters

  Write-Log -Message 'Downloading the client tools (cfssl, cfssljson, kubectl)' -Source $CmdletName -Severity 1 -ScriptSection 'Prerequisites - client tools' 

  try
  {
    if(!(test-path ('{0}\cfssl' -f $env:ProgramFiles)))
    {
      Write-Log -Message ('Path {0}\cfssl not found, creating it.' -f $env:ProgramFiles) -Source $CmdletName -Severity 1 -ScriptSection 'Prerequisites - client tools' 
      New-Item -ItemType Directory -Path $env:ProgramFiles -Name 'cfssl' -ErrorAction Stop
    }
    if(!(test-path ('{0}\kubectl' -f $env:ProgramFiles)))
    {
      Write-Log -Message ('Path {0}\kubectl not found, creating it.' -f $env:ProgramFiles) -Source $CmdletName -Severity 1 -ScriptSection 'Prerequisites - client tools' 
      New-Item -ItemType Directory -Path $env:ProgramFiles -Name 'kubectl' -ErrorAction Stop
    }

    Invoke-WebRequest -Uri $cfsslDownloadURL -OutFile ('{0}\cfssl\cfssl.exe' -f $env:ProgramFiles)
    if($LASTEXITCODE)
    {
      Throw 'Client tools download error!'
    }
    Invoke-WebRequest -Uri $cfssljsonDownloadURL -OutFile ('{0}\cfssl\cfssljson.exe' -f $env:ProgramFiles)
    if($LASTEXITCODE)
    {
      Throw 'Client tools download error!'
    }
    Invoke-WebRequest -Uri $kubectlWindowsDownloadURL -OutFile ('{0}\kubectl\kubectl.exe' -f $env:ProgramFiles)
    if($LASTEXITCODE)
    {
      Throw 'Client tools download error!'
    }

    if((Test-Path ('{0}\kubectl\kubectl.exe' -f $env:ProgramFiles)) -and (Test-Path ('{0}\cfssl\cfssljson.exe' -f $env:ProgramFiles)) -and (Test-Path ('{0}\cfssl\cfssl.exe' -f $env:ProgramFiles)))
    {
      Write-Log -Message 'Client tools sucessfully fetched' -Source $CmdletName -Severity 1 -ScriptSection 'Prerequisites - client tools' 
    }
    else
    {
      Throw 'Failed to fetch client tools'
    }

    Write-Log -Message 'Adding the client tools to the PATH variable' -Source $CmdletName -Severity 1 -ScriptSection 'Prerequisites - client tools' 
    $env:PATH += (';{0}\cfssl' -f $env:ProgramFiles)
    $env:PATH += (';{0}\kubectl' -f $env:ProgramFiles)

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to fetch the client tools!' -Source $CmdletName -Severity 3 -ScriptSection 'Prerequisites - client tools' 
    Break
  }
  
}