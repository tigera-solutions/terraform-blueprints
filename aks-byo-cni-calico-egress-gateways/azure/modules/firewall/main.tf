resource "azurerm_public_ip" "pip" {
  name                = var.pip_name
  resource_group_name = var.resource_group
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "fw" {
  name                = var.fw_name
  location            = var.location
  resource_group_name = var.resource_group
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "fw_ip_config"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}

# This is the only rule required for successful AKS deployment
resource "azurerm_firewall_application_rule_collection" "fqdntags" {
  name                = "fqdntags"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.resource_group
  priority            = 100
  action              = "Allow"

  rule {
    name             = "allow fqdn tags"
    source_addresses = ["*"]

    fqdn_tags = [
      "AzureKubernetesService",
    ]
  }
}

# Additional FQDNS to allow Calico images and other public images to the AKS cluster
resource "azurerm_firewall_application_rule_collection" "allowed_fqdns" {
  name                = "allowed-fqdns"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.resource_group
  priority            = 101
  action              = "Allow"

  rule {
    name             = "allow access to public fqdns"
    description      = "allow access to public fqdns"
    source_addresses = ["*"]

    target_fqdns = [
      "auth.docker.io",
      "registry-1.docker.io",
      "production.cloudflare.docker.com",
      "quay.io",
      "*.quay.io",
      "downloads.tigera.io"
    ]

    protocol {
      port = "80"
      type = "Http"
    }

    protocol {
      port = "443"
      type = "Https"
    }
  }
}

resource "azurerm_firewall_network_rule_collection" "allowed_network_rules" {
  name                = "allowed-network-rules"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.resource_group
  priority            = 100
  action              = "Allow"

  rule {
    description       = "allow access to public dns"
    name              = "allow access to public dns"
    source_addresses  = ["*"]
    destination_ports = ["53"]
    destination_addresses = [
      "8.8.8.8",
      "8.8.4.4",
    ]
    protocols         = [
      "UDP",
      "TCP",
    ]
  }

  rule {
    description       = "allow access to public https"
    name              = "allow access to public https"
    source_addresses  = ["*"]
    destination_ports = ["443"]
    destination_addresses = ["*"]
    protocols         = ["TCP"]
  }

  rule {
    description       = "allow access to calico cloud"
    name              = "allow access to calico cloud"
    source_addresses  = ["*"]
    destination_ports = ["9000"]
    destination_addresses = ["*"]
    protocols         = ["TCP"]
  }
}
