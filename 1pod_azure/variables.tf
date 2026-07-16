variable "subscription_id" {
  description = "Azure subscription ID. setup.sh obtains it from the active Azure CLI account."
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Azure region in which to create the lab."
  type        = string
  default     = "westus3"
}

variable "resource_group_name" {
  description = "Resource group containing the AKS lab."
  type        = string
  default     = "one-pod-azure-lab-rg"
}

variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
  default     = "one-pod-azure-lab"
}

variable "dns_prefix" {
  description = "DNS prefix used by AKS."
  type        = string
  default     = "onepodazurelab"
}

variable "node_vm_size" {
  description = "Azure VM size for the cluster's single system node. Must be an AKS-supported, non-B-series SKU with at least 4 vCPUs and 4 GiB of memory."
  type        = string
  default     = "Standard_D4as_v5"

  validation {
    condition     = !startswith(var.node_vm_size, "Standard_B")
    error_message = "AKS does not support B-series VMs in a system node pool."
  }
}

variable "namespace" {
  description = "Kubernetes namespace for the Hello World server."
  type        = string
  default     = "hello-world"
}

variable "nginx_image" {
  description = "Pinned NGINX image used by the Hello World Pod."
  type        = string
  default     = "nginx:1.27-alpine"
}
