resource "azurerm_public_ip" "pip" {
  name                = "vm-pip"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "vm_sg" {
  name                = "vm-sg"
  location            = var.location
  resource_group_name = var.resource_group

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "vm-nic"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                          = "vmNicConfiguration"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "sg_association" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_sg.id
}

locals {
  custom_data = <<CUSTOM_DATA
#cloud-config
runcmd:
 - sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2
 - curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
 - echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
 - sudo apt-get update
 - sudo apt-get install -y kubectl
 - curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
CUSTOM_DATA
}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                  = "jumpboxvm"
  location              = var.location
  resource_group_name   = var.resource_group
  network_interface_ids = [azurerm_network_interface.vm_nic.id]
  size                  = "Standard_DS1_v2"
  computer_name         = "jumpboxvm"
  admin_username        = var.admin_username
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_key
  }
  disable_password_authentication = true

  os_disk {
    name                 = "jumpboxOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  custom_data = base64encode(local.custom_data)
}

resource "azurerm_private_dns_zone_virtual_network_link" "hublink" {
  for_each = { for each in var.dns_links : each.name => each }

  name                  = each.value.name
  resource_group_name   = each.value.zone_resource_group
  private_dns_zone_name = each.value.zone_name
  virtual_network_id    = var.vnet_id
}
