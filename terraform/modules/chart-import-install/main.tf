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
