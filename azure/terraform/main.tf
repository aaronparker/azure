## Deploy a vnet and a Linux VM

# Configure the Azure provider
terraform {
    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = ">= 2.26"
        }
    }
}

provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "rg1" {
    name     = "rg-${var.environment}-${var.location}"
    location = var.location
    tags     = var.tags
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet1" {
    name                = "vnet-${var.environment}-${var.location}"
    address_space       = [var.address_space]
    location            = var.location
    resource_group_name = azurerm_resource_group.rg1.name
    tags = var.tags
}

# Create subnet
resource "azurerm_subnet" "subnet1" {
    name                 = "subnet-Servers"
    resource_group_name  = azurerm_resource_group.rg1.name
    virtual_network_name = azurerm_virtual_network.vnet1.name
    address_prefixes     = [var.subnet1]
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg1" {
    name                = "nsg-Servers"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg1.name
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
    tags = var.tags
}

# Create network interface
resource "azurerm_network_interface" "nic1" {
    name                = "nic-${var.vmname}-001"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg1.name
    ip_configuration {
        name                          = "${var.vmname}-nicconfig"
        subnet_id                     = azurerm_subnet.subnet1.id
        private_ip_address_allocation = "dynamic"
    }
    tags = var.tags
}

# Create a Linux virtual machine
resource "azurerm_virtual_machine" "vm" {
    name                  = var.vmname
    location              = var.location
    resource_group_name   = azurerm_resource_group.rg1.name
    network_interface_ids = [azurerm_network_interface.nic1.id]
    vm_size               = var.vmsize
    storage_os_disk {
        name              = "${var.vmname}-disk-001"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }
    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = lookup(var.sku, var.location)
        version   = "latest"
    }
    os_profile {
        computer_name  = var.vmname
        admin_username = var.admin_username
        admin_password = var.admin_password
    }
    os_profile_linux_config {
        disable_password_authentication = false
    }
    tags = var.tags
}
