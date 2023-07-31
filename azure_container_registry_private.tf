resource "azurerm_resource_group" "rg_container_registry" {
  name     = "rg-ben-acr-dev01-westus"
  location = var.location
}

# test Vnet
resource "azurerm_virtual_network" "ec-vnet" {
  name                = "ntt-acr-vnet"
  resource_group_name = azurerm_resource_group.rg_container_registry.name
  location            = azurerm_resource_group.rg_container_registry.location
  address_space       = ["192.168.0.0/16"]
}

# Test Subnet
resource "azurerm_subnet" "test_snet" {
  name                 = "test-snet"
  resource_group_name  = azurerm_resource_group.rg_container_registry.name
  virtual_network_name = azurerm_virtual_network.ec-vnet.name
  address_prefixes     = ["192.168.0.64/28"]
}

resource "azurerm_container_registry" "acr" {
  name                = "ecContainerRegistry001"
  resource_group_name = azurerm_resource_group.rg_container_registry.name
  location            = azurerm_resource_group.rg_container_registry.location
  sku                 = "Premium"
  admin_enabled       = false
  public_network_access_enabled = false
}

# Create azure private endpoint
resource "azurerm_private_endpoint" "acr_private_endpoint" {
  depends_on = [ azurerm_container_registry.acr, azurerm_subnet.test_snet ]
  name                = "${azurerm_container_registry.acr.name}-pe"
  resource_group_name = azurerm_resource_group.rg_container_registry.name
  location            = azurerm_resource_group.rg_container_registry.location
  subnet_id           = azurerm_subnet.test_snet.id
  
  private_service_connection {
    name                           = "${azurerm_container_registry.acr.name}-psc"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names = [
      "registry"
    ]
  }
}
