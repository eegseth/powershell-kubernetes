#Requires -RunAsAdministrator

foreach ($file in (get-childitem private\))
{
. $file.FullName
}

foreach ($file in (get-childitem public\))
{
. $file.FullName
}

Export-ModuleMember -Function 'New-K8sCluster'