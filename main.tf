terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.62.1"
    }
  }
}


provider "azurerm" {
  subscription_id = "411a6b8b-78eb-47c4-80c7-666ab59a7020"
  client_id       = "d8028c02-3e42-40d0-bb8b-79407e2b9180"
  client_secret   = "00N8Q~giYNlgBgn1nsivHhxwIKekzWuGHdU1laNO"
  tenant_id       = "d032994e-e52c-4d44-bc79-9fd88e88ad02"
  features {}

}

####################### Resource Grorup ###########################
resource "azurerm_resource_group" "cub_roshan_rg" {
  name     = "Cub-Roshan-RG"
  location = "Central India"
}

########################### VNET1 ################################
resource "azurerm_virtual_network" "vnet1" {
  name                = "VNET-1"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.cub_roshan_rg.location
  resource_group_name = azurerm_resource_group.cub_roshan_rg.name
}

########################### SUBNET1 ################################
resource "azurerm_subnet" "subnet1" {
  name                 = "subnet-1"
  resource_group_name  = azurerm_resource_group.cub_roshan_rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.1.1.0/24"]
}

########################### INTERFACE & IP ################################


resource "azurerm_public_ip" "Vm_Public_Ip" {
  name                = "VM-public-ip"
  location            = azurerm_resource_group.cub_roshan_rg.location
  resource_group_name = azurerm_resource_group.cub_roshan_rg.name
  allocation_method   = "Static" 
  sku                 = "Standard" 
}


resource "azurerm_network_interface" "test-int" {
  name                = "VM-NIC"
  location            = azurerm_resource_group.cub_roshan_rg.location
  resource_group_name = azurerm_resource_group.cub_roshan_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.Vm_Public_Ip.id
  }

}


########################### Availability Set ################################

resource "azurerm_availability_set" "availability_set" {
  name                = "AV-SET"
  resource_group_name = azurerm_resource_group.cub_roshan_rg.name
  location            = azurerm_resource_group.cub_roshan_rg.location
}

########################### Virtual Machine ################################

resource "azurerm_linux_virtual_machine" "vm1" {
  name                                = "vm1"
  resource_group_name                 = azurerm_resource_group.cub_roshan_rg.name
  location                            = azurerm_resource_group.cub_roshan_rg.location
  size                                = "Standard_D2_v2"
  admin_username                      = "adminuser"
  admin_password                      = "Cubastion$$123"
  disable_password_authentication    = false
  network_interface_ids               = [azurerm_network_interface.test-int.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

}
resource "azurerm_network_security_group" "TestSecurityGroup1" {
  name                = "TestSecurityGroup1"
  location            = azurerm_resource_group.cub_roshan_rg.location
  resource_group_name = azurerm_resource_group.cub_roshan_rg.name

  security_rule {
    name                       = "port_80"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
    security_rule {
    name                       = "port_22"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "test-assosciation" {
  subnet_id                 = azurerm_subnet.subnet1.id
  network_security_group_id = azurerm_network_security_group.TestSecurityGroup1.id
  depends_on = [
    azurerm_network_security_group.TestSecurityGroup1
  ]
}

########################### Storage Account ################################

resource "azurerm_storage_account" "sa" {
  name                     = "cubstorageaccount001"
  resource_group_name      = azurerm_resource_group.cub_roshan_rg.name
  location                 = azurerm_resource_group.cub_roshan_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_private_endpoint" "pe" {
  name                = "test-endpoint"
  location            = azurerm_resource_group.cub_roshan_rg.location
  resource_group_name = azurerm_resource_group.cub_roshan_rg.name
  subnet_id           = azurerm_subnet.subnet1.id

  private_service_connection {
    name                           = "test-privateserviceconnection"
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "test-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns.id]
  }
}

resource "azurerm_private_dns_zone" "private_dns" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.cub_roshan_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_link" {
  name                  = "private_dns_link"
  resource_group_name   = azurerm_resource_group.cub_roshan_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.private_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet1.id
}

resource "azurerm_storage_share" "share1" {
  name                 = "fileshare1"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 5
}

resource "azurerm_storage_share" "share2" {
  name                 = "fileshare2"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 5
}

output "storage_account_id" {
  value = azurerm_storage_account.sa.id
}


resource "azurerm_container_registry" "acr" {
  name                = "cubcontainerRegistry1"
  resource_group_name = azurerm_resource_group.cub_roshan_rg.name
  location            = azurerm_resource_group.cub_roshan_rg.location
  sku                 = "Standard"
  admin_enabled       = false

}


########################### VNET2 ################################
resource "azurerm_virtual_network" "vnet2" {
  name                = "VNET-2"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.cub_roshan_rg.location
  resource_group_name = azurerm_resource_group.cub_roshan_rg.name
}


resource "azurerm_subnet" "aks-subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.cub_roshan_rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.2.1.0/24"] 
}

resource "azurerm_subnet" "gw-subnet" {
  name                 = "gw-subnet"
  resource_group_name  = azurerm_resource_group.cub_roshan_rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.2.2.0/24"]
}


###########################  Peering from VNET-1 to VNET-2 #################################
resource "azurerm_virtual_network_peering" "vnet1_to_vnet2" {
  name                         = "vnet1-to-vnet2"
  resource_group_name          = azurerm_resource_group.cub_roshan_rg.name
  virtual_network_name         = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id     = azurerm_virtual_network.vnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

###########################  Peering from VNET-2 to VNET-1 #################################
resource "azurerm_virtual_network_peering" "vnet2_to_vnet1" {
  name                         = "vnet2-to-vnet1"
  resource_group_name          = azurerm_resource_group.cub_roshan_rg.name
  virtual_network_name         = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id     = azurerm_virtual_network.vnet1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

########################### kubernetes cluster #################################

resource "azurerm_kubernetes_cluster" "dev-k8s-cluster" {
  name                = "k8s-cluster-001"
  resource_group_name = azurerm_resource_group.cub_roshan_rg.name
  location            = azurerm_resource_group.cub_roshan_rg.location
  dns_prefix          = "k8s-cluster-dns"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
    vnet_subnet_id  = azurerm_subnet.aks-subnet.id
  }


  network_profile {
    network_plugin    = "azure"
  }

  identity {
    type = "SystemAssigned"
  }

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.app-gateway.id
  }

  role_based_access_control_enabled = true
  private_cluster_enabled           = true

  depends_on = [
    azurerm_application_gateway.app-gateway
  ]
}

resource "azurerm_public_ip" "gw_ip" {
  name                = "gateway-public-ip"
  location            = azurerm_resource_group.cub_roshan_rg.location
  resource_group_name = azurerm_resource_group.cub_roshan_rg.name
  allocation_method   = "Static" 
  sku                 = "Standard" 
}


########################### application gateway #################################
resource "azurerm_application_gateway" "app-gateway" {
  name                = "App-gateway"
  resource_group_name = azurerm_resource_group.cub_roshan_rg.name
  location            = azurerm_resource_group.cub_roshan_rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "proj-gateway-ip-config"
    subnet_id = azurerm_subnet.gw-subnet.id
  }

  frontend_port {
    name = "defaultfrontendport"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "defaultfrontendipconfiguration"
    public_ip_address_id = azurerm_public_ip.gw_ip.id
  }

  backend_address_pool {
    name = "defaultbackendaddresspool"
  }

  backend_http_settings {
    name                  = "defaulthttpSetting"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = "defaulthttpListener"
    frontend_ip_configuration_name = "defaultfrontendipconfiguration"
    frontend_port_name             = "defaultfrontendport"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "httpRoutingRule"
    rule_type                  = "Basic"
    priority                   = "200"
    http_listener_name         = "defaulthttpListener"
    backend_address_pool_name  = "defaultbackendaddresspool"
    backend_http_settings_name = "defaulthttpSetting"
  }
}


