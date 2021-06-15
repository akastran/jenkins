# Configure the Microsoft Azure Provider.
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
    features {}
}

# Create resource group with workspace name
resource "azurerm_resource_group" "main" {
  count = var.instances
  name     = count.index == 0 ? "testing-jenkins" : "testing-java-${count.index}"
  location = var.location
}


# Create virtual network
resource "azurerm_virtual_network" "virtual_network" {
    count = var.instances
    name                = "virtual_network"
    address_space       = ["10.0.0.0/16"]
    location            = azurerm_resource_group.main[count.index].location
    resource_group_name = azurerm_resource_group.main[count.index].name
}

# Create subnet
resource "azurerm_subnet" "sub_network" {
    count = var.instances
    name                 = "sub_network"
    resource_group_name  = azurerm_resource_group.main[count.index].name
    virtual_network_name = azurerm_virtual_network.virtual_network[count.index].name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "public_ip" {
    count = var.instances
    name                         = "public_ip"
    location                     = azurerm_resource_group.main[count.index].location
    resource_group_name          = azurerm_resource_group.main[count.index].name
    allocation_method            = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "security_group" {
    count = var.instances
    name                = "security_group"
    location            = azurerm_resource_group.main[count.index].location
    resource_group_name = azurerm_resource_group.main[count.index].name

    security_rule {
        name                       = "SSH"
        priority                   = 1000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "TESTING"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8080"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

# Create network interface
resource "azurerm_network_interface" "network_interface" {
    count = var.instances
    name                      = "network_interface"
    location                  = azurerm_resource_group.main[count.index].location
    resource_group_name       = azurerm_resource_group.main[count.index].name

    ip_configuration {
        name                          = "ip_configuration"
        subnet_id                     = azurerm_subnet.sub_network[count.index].id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "ni_sg_association" {
    count = var.instances
    network_interface_id      = azurerm_network_interface.network_interface[count.index].id
    network_security_group_id = azurerm_network_security_group.security_group[count.index].id
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "virtual_machine" {
    count = var.instances
    name                  = "virtual_machine"
    location              = azurerm_resource_group.main[count.index].location
    resource_group_name   = azurerm_resource_group.main[count.index].name
    network_interface_ids = [azurerm_network_interface.network_interface[count.index].id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "os_disk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = count.index == 0 ? "jenkins-vm" : "java-${count.index}"
    admin_username = var.username
    admin_password = var.password
    disable_password_authentication = false

  # It's easy to transfer files or templates using Terraform.
  provisioner "file" {
    source      = count.index == 0 ? "files/setup_java_and_jenkins.sh" : "files/setup_java_only.sh"
    destination = "/home/${var.username}/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.username}/setup.sh",
      "sudo /home/${var.username}/setup.sh",
    ]
  }

    connection {
      type     = "ssh"
      user     = var.username
      password = var.password
      host     = self.public_ip_address
    }
}

data "azurerm_public_ip" "main" {
  count = var.instances
  name                = element(azurerm_public_ip.public_ip.*.name, count.index)
  resource_group_name = element(azurerm_linux_virtual_machine.virtual_machine.*.resource_group_name, count.index)
}

