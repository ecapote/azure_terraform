data "azurerm_resource_group" "ec_rg" {
  name = "rg-ec-terraform-test"
}

resource "azurerm_virtual_network" "ec_vnet" {
  name                = "ec_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.ec_rg.location
  resource_group_name = data.azurerm_resource_group.ec_rg.name
}

resource "azurerm_subnet" "ec_snet" {
  name                 = "ec_snet_a"
  resource_group_name  = data.azurerm_resource_group.ec_rg.name
  virtual_network_name = azurerm_virtual_network.ec_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
resource "azurerm_storage_account" "stgacct_woodruff_rds" {
  name                          = lower("stoben${var.environment}01${var.location}")
  resource_group_name           = data.azurerm_resource_group.ec_rg.name
  location                      = data.azurerm_resource_group.ec_rg.location
  account_kind                  = "StorageV2"
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  enable_https_traffic_only     = true
  public_network_access_enabled = true
#   depends_on                    = [azurerm_resource_group.rg_base_auth_app]
  
}

resource "azurerm_storage_container" "workflow_container" {
  name                  = "ecteststgcontainer"
  storage_account_name  = azurerm_storage_account.stgacct_woodruff_rds.name
  container_access_type = "private"
  depends_on            = [azurerm_storage_account.stgacct_woodruff_rds]
}

# Create Private Endpoint
resource "azurerm_private_endpoint" "workflow_func_storage" {
  name                = "ec_test_PE"
  resource_group_name = data.azurerm_resource_group.ec_rg.name
  location            = data.azurerm_resource_group.ec_rg.location
  subnet_id           = azurerm_subnet.ec_snet.id
  depends_on          = [azurerm_storage_account.stgacct_woodruff_rds, azurerm_storage_container.workflow_container]
  
  private_service_connection {
    name                           = "ectest-PE"
    private_connection_resource_id = azurerm_storage_account.stgacct_woodruff_rds.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
}

output "ipv4" {
  value = azurerm_private_endpoint.workflow_func_storage.private_service_connection[0].private_ip_address
}
locals {
  ip_addr = azurerm_private_endpoint.workflow_func_storage.private_service_connection[0].private_ip_address
}
# create the resources
resource "azurerm_private_dns_a_record" "mydnsrecord" {
  name                = lower(azurerm_private_endpoint.workflow_func_storage.name)
  zone_name           = "privatelink.blob.core.windows.net"
  resource_group_name = "mrmac-rg1"
  ttl                 = 300
  records             = [local.ip_addr]
}

