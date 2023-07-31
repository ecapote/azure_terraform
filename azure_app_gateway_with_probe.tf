## Create a public ip for use by the App GW
resource "azurerm_public_ip" "appgw_pip" {
  name                = "appgw-${var.environment}-pip"
  sku                 = "Standard"
  resource_group_name = azurerm_resource_group.appgw_rg.name
  location            = azurerm_resource_group.appgw_rg.location
  allocation_method   = "Static"
}

# Local variables to use for deployment
  backend_address_pool_name              = "beap-${var.environment}-pool"
  http_frontend_port_name                     = "fehttp-${var.environment}"
  https_frontend_port_name = "fehttps-${var.environment}"
  public_frontend_ip_configuration_name  = "feprivip-appGwPublicFrontendIpIPv4-${var.environment}"
  private_frontend_ip_configuration_name = "fepip-appGwPrivateFrontendIpIPv4-${var.environment}"
  https_setting_name                     = "stng-https-${var.environment}"
  http_setting_name                     = "stng-http-${var.environment}"
  public_http_listener_name                   = "${var.environment}-public_http_listener"
  private_http_listener_name                  = "${var.environment}-private_http_listener"
  public_https_listener_name                   = "${var.environment}-public_https_listener"
  private_https_listener_name                  = "${var.environment}-private_https_listener"
  public_routing_rule_name               = "${var.environment}-public-rt"
  private_routing_rule_name              = "${var.environment}-private-rt"
  redirect_configuration_name            = "${var.environment}-rdrcfg"
}

resource "azurerm_application_gateway" "app_gw" {
  name                = "appgw-apimgmt-${var.environment}01-${var.location}"
  resource_group_name = azurerm_resource_group.appgw_rg.name
  location            = azurerm_resource_group.appgw_rg.location

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }
  ssl_certificate {
    name     = "descriptive name of certificate"
    data     = "${filebase64("CERT_FILE.pfx")}"
    password = "certificate PWD"
  }

  autoscale_configuration {
    min_capacity = 0
    max_capacity = 10
  }
  gateway_ip_configuration {
    name      = "gw-ip-configuration"
    subnet_id = data.azurerm_subnet.appgw_frontendip_snet.id
  }
  frontend_port {
    name = local.http_frontend_port_name
    port = 80
  }
  frontend_port {
    name = local.https_frontend_port_name
    port = 443
  }
  frontend_ip_configuration {
    name                 = local.public_frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }
  frontend_ip_configuration {
    name                          = local.private_frontend_ip_configuration_name
    subnet_id                     = data.azurerm_subnet.appgw_frontendip_snet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.frontend_privateIP
  }
  backend_address_pool {
    name  = local.backend_address_pool_name
    fqdns = ["URL of backend pool"]
  }
  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = ""
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }
  backend_http_settings {
    name                  = local.https_setting_name
    cookie_based_affinity = "Disabled"
    path                  = ""
    port                  = 443
    protocol              = "Https"
    request_timeout       = 20
    pick_host_name_from_backend_address = true
    probe_name = "apimgmt_${var.environment}_443_probe"
  }

  http_listener {
    name                           = local.public_https_listener_name
    frontend_ip_configuration_name = local.public_frontend_ip_configuration_name
    frontend_port_name             = local.https_frontend_port_name
    protocol                       = "Https"
    ssl_certificate_name = "wsandcowildcardcert"
  }
  
  http_listener {
    name                           = local.private_https_listener_name
    frontend_ip_configuration_name = local.private_frontend_ip_configuration_name
    frontend_port_name             = local.https_frontend_port_name
    protocol                       = "Https"
    ssl_certificate_name = "descriptive name of certificate as above"
  }


  request_routing_rule {
    name                       = local.public_routing_rule_name
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = local.public_https_listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.https_setting_name
  }

  request_routing_rule {
    name                       = local.private_routing_rule_name
    rule_type                  = "Basic"
    priority                   = 110
    http_listener_name         = local.private_https_listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.https_setting_name
  }

  probe {
      name                = "apimgmt_${var.environment}_443_probe"
      host                = "URL to use for Probe
      interval            = 30
      path                = "/status-0123456789abcdef"
      port                = 443
      timeout             = 30
      unhealthy_threshold = 3
      protocol = "Https"
      match {
      status_code = ["100-399"]
      }
    }

  waf_configuration {
    enabled            = true
    firewall_mode      = "Detection"
    rule_set_type      = "OWASP"
    rule_set_version   = "3.1"
    request_body_check = true
    
  }

}
