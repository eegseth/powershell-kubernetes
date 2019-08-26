function New-K8sEtcdEncryptionConfig {
  <#
  .SYNOPSIS
    Generate data encryption config and key for etcd.
  .EXAMPLE
    New-K8sEtcdEncryptionConfig
  #>
  [CmdletBinding()]
  Param ()

  [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
  Write-Log -Message 'Function invoked, parameters: ' -Source ${CmdletName} -CmdletBoundParameters $PSBoundParameters
  Write-Log -Message 'Generating encryption key for encrypting secrets in etcd' -Source $CmdletName -Severity 1 -ScriptSection 'Configuration -etcd'
  
  try
  {
    $AESKey = New-Object Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($AESKey)
    $encryption_key = [Convert]::ToBase64String($AESkey)

    #encryption config
    $encryptionconfig = @"
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: $encryption_key
      - identity: {}
"@

    $encryptionconfig | out-file 'encryption-config.yaml' -Encoding utf8 -force -ErrorAction Stop

    Return 0

  }catch
  {
    Write-Log -Message 'Failed to generate the encryption config.' -Source $CmdletName -Severity 3 -ScriptSection 'Configuration - etcd'
    Break
  }
}