resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = "learning"
    lab         = "one-pod-azure"
    managed_by  = "terraform"
  }
}

resource "azurerm_kubernetes_cluster" "lab" {
  name                = var.cluster_name
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  dns_prefix          = var.dns_prefix
  sku_tier            = "Free"

  default_node_pool {
    name                         = "system"
    node_count                   = 1
    vm_size                      = var.node_vm_size
    os_disk_size_gb              = 30
    type                         = "VirtualMachineScaleSets"
    only_critical_addons_enabled = false

    upgrade_settings {
      max_surge = "10%"
    }

    tags = {
      environment = "learning"
      lab         = "one-pod-azure"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  role_based_access_control_enabled = true

  tags = {
    environment = "learning"
    lab         = "one-pod-azure"
    managed_by  = "terraform"
  }
}

