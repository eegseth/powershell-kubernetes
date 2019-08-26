# powershell-kubernetes
Automated deployment of a kubernetes cluster in Azure using Powershell

Missing cloud provider integration.

Based on https://github.com/kelseyhightower/kubernetes-the-hard-way


## Howto:
1. Import module:
```
import-module .\k8s.psm1
```
2. Run command (have a look inside for parameters needed):
```
New-K8sCluster
```
