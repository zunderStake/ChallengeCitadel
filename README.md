# ChallengeCitadel
## Challenge 1

To achieve the points that we are asked to modify the value.yaml of the chart to include the necessary restrictions, we should add the following lines to the end of our value.yaml

```
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app
      	  operator: In
      	   values:
      	   - ping
        topologyKey: kubernetes.io/hostname
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
      	- key: app
        	  operator: In
        	  values:
        	  -  ping
          topologyKey: topology.kubernetes.io/zone

tolerations:
- key: "grupo"
  operator: "Equal"
  value: "back"
  effect: "NoSchedule"
```

Now we will explain each of the labels:
- Isolate specific groups of nodes: For this we will use “tolerations”, previously we should have marked with “taint” the nodes whose group we do not want to use in the deployment... I have called it and created a taint “group” whose value is “back ”.
- Ensure that a pod is not scheduled on a node that already has a pod of the same type: The “requiredDuringSchedulingIgnoredDuringExecution” option of “podAntiAffinity” has been used to ensure that these rules have to be met in the scheduling but do not affect the execution. In this section we simply check that there is no pod whose “app” key matches “ping” on the same node using “topologyKey: kubernetes.io/hostname”.
- Deploy pods in different availability zones: We will use “podAffinityTerm” to achieve this configuration, with the “labelSelector” we apply this configuration only to those objects that contain the “app” key with the value “ping” and then we apply “topologyKey: topology. kubernetes.io/zone”.


## Challenge 2

This would be our “main.tf” of the module to import from “reference.azurecr.io” to “instance.azurecr.io”
```
#Declaration of variables
variable "acr_server" {}
variable "acr_server_subscription" {}
variable "source_acr_client_id" {}
variable "source_acr_client_secret" {}
variable "source_acr_server" {}
variable "charts" {
  type = list(object({
	chart_name   	= string
	chart_namespace  = string
	chart_repository = string
	chart_version	= string
	values       	= list(object({
  	name  = string
  	value = string
	}))
	sensitive_values = list(object({
  	name  = string
  	value = string
	}))
  }))
}
#Resource to import from “reference.azurecr.io”
resource "null_resource" "import_charts" {
  count = length(var.charts)
  #with “local-exec” we guarantee that it executes the commands locally
  provisioner "local-exec" {
	command = <<-EOT
  	# Use Azure CLI to authenticate and copy the Helm chart
  	az acr login --name ${var.source_acr_server} --username ${var.source_acr_client_id} --password ${var.source_acr_client_secret}
  	az acr import --name ${var.acr_server} --source ${var.source_acr_server}/${var.charts[count.index].chart_name}:${var.charts[count.index].chart_version} --subscription ${var.acr_server_subscription}
	EOT
  }

  triggers = {
	chart_version = var.charts[count.index].chart_version
  }
}
#Resource to install the helms in the repository “instance.azurecr.io”
resource "helm_release" "chart_release" {
  count = length(var.charts)
 
  name      	= var.charts[count.index].chart_name
  namespace 	= var.charts[count.index].chart_namespace
  repository	= var.charts[count.index].chart_repository
  chart     	= var.charts[count.index].chart_name
  version   	= var.charts[count.index].chart_version
  set {
	name  = var.charts[count.index].values.name
	value = var.charts[count.index].values.value
  }
  set_sensitive {
	name  = var.charts[count.index].sensitive_values.name
	value = var.charts[count.index].sensitive_values.value
  }
  depends_on = [null_resource.import_charts]
}
```

## Challenge 3

For this we must take into account certain aspects such as that in our repository we must have access to:

-The helm files.

-The terraform files.

-AZURE credentials.

-The Helm repository credentials.


```
name: Deploy Helm Chart to AKS

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v2
      #Configuration Helm
      - name: Setup Helm
        uses: azure/setup-helm@v1

      #Verification chart of Helm
      - name: Lint Helm Chart
        run: helm lint ./helm-charts/ping/

      #package Chart
      - name: Package Helm Chart
        run: helm package ./helm-charts/ping/ -d ./helm-charts/

      #Login to Azure
      - name: Login to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      #Upload chart Helm to ACR
      - name: Push Helm Chart to ACR
        run: |
          export HELM_EXPERIMENTAL_OCI=1
          helm chart save ./helm-charts/ping/ reference.azurecr.io/mychart:v1.0.0
          helm chart push reference.azurecr.io/mychart:v1.0.0

      #Configuration of Terraform
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1

      #Init of Terraform
      - name: Initialize Terraform
        run: terraform init

      #Apply of Terraform
      - name: Apply Terraform
        run: terraform apply -auto-approve

      #logout Azure
      - name: Logout from Azure
        run: az logout

```
