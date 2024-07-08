provider "azurerm" {
  features {}
  environment                 = "public"
  skip_provider_registration  = true
  subscription_id             = var.azure_subscription_id
  client_id                   = var.azure_client_id
  client_secret               = var.azure_client_secret
}

provider "aws" {
  region     = var.aws_region
  access_key =  var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "azurerm_resource_group" "testkibana" {
  name     = "testkibana-resources"
  location = "East US"  # Update with your preferred Azure region
}

resource "azurerm_virtual_network" "testkibana" {
  name                = "testkibana-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.testkibana.location
  resource_group_name = azurerm_resource_group.testkibana.name
}

resource "azurerm_subnet" "testkibana" {
  name                 = "testkibana-subnet"
  resource_group_name  = azurerm_resource_group.testkibana.name
  virtual_network_name = azurerm_virtual_network.testkibana.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "testkibana" {
  name                = "testkibana-public-ip"
  location            = azurerm_resource_group.testkibana.location
  resource_group_name = azurerm_resource_group.testkibana.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "testkibana" {
  name                = "testkibana-nic"
  location            = azurerm_resource_group.testkibana.location
  resource_group_name = azurerm_resource_group.testkibana.name

  ip_configuration {
    name                          = "testkibana-nic-config"
    subnet_id                     = azurerm_subnet.testkibana.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.testkibana.id
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "testkibana-nsg"
  location            = azurerm_resource_group.testkibana.location
  resource_group_name = azurerm_resource_group.testkibana.name
}

resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "allow_ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.testkibana.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_testkibana" {
  name                        = "allow_testkibana"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5601"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.testkibana.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_https" {
  name                        = "allow_https"
  priority                    = 201
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.testkibana.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_http" {
  name                        = "allow_http"
  priority                    = 202
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.testkibana.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_elasticsearch" {
  name                        = "allow_elasticsearch"
  priority                    = 203
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "9200"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.testkibana.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_interface_security_group_association" "nsgAssociation" {
  network_interface_id      = azurerm_network_interface.testkibana.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "testkibana" {
  name                = "testkibana-vm"
  location            = azurerm_resource_group.testkibana.location
  resource_group_name = azurerm_resource_group.testkibana.name
  size                = "Standard_DS1_v2"
  admin_username      = var.azure_vm_ssh_username
  disable_password_authentication = false
  admin_password      = var.azure_vm_ssh_password
  network_interface_ids = [
    azurerm_network_interface.testkibana.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  depends_on = [
    azurerm_public_ip.testkibana,
    azurerm_network_interface.testkibana,
    azurerm_network_security_rule.allow_ssh,
    azurerm_network_security_rule.allow_testkibana
  ]
}

data "azurerm_public_ip" "testkibana_ip" {
  name                = "testkibana-public-ip"
  resource_group_name = azurerm_resource_group.testkibana.name
  depends_on = [azurerm_public_ip.testkibana, azurerm_linux_virtual_machine.testkibana]
}

resource "aws_route53_record" "testkibana" {
  zone_id = var.aws_route53_record_zone_id
  name    = var.aws_route53_record_domain_name
  type    = "A"
  ttl     = "300"
  records = ["${data.azurerm_public_ip.testkibana_ip.ip_address}"]
  depends_on = [azurerm_linux_virtual_machine.testkibana]
}

# Execute Init Script after Route53 Record creation
resource "null_resource" "init_script_transfer" {
  depends_on = [aws_route53_record.testkibana, azurerm_linux_virtual_machine.testkibana]

  provisioner "file" {
    source      = "/Users/gowrisankar/Projects/AZ_VM/init_script.sh"
    destination = "/tmp/init_script.sh"
    connection {
      type        = "ssh"
      host        = data.azurerm_public_ip.testkibana_ip.ip_address
      user        = "adminuser"
      password    = "b1nch4@*2024"
      agent       = false
      timeout     = "2m"
    }
  }
}

resource "null_resource" "init_script_execution_v1" {
    depends_on = [null_resource.init_script_transfer]

    provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = data.azurerm_public_ip.testkibana_ip.ip_address
      user        = var.azure_vm_ssh_username
      password    = var.azure_vm_ssh_password
      agent       = false
      timeout     = "2m"
    }

    inline = [
      "echo 'Executing init_script.sh after connection'",
      "chmod +x /tmp/init_script.sh",
      "export KIBANA_USERNAME=${var.kibana_username}",
      "export KIBANA_PASSWORD=${var.kibana_password}",
      "export KIBANA_DOMAIN_NAME=${var.aws_route53_record_domain_name}",
      "export ELASTICSEARCH_INDEX=${var.elastic_index}",
      "sudo -E bash /tmp/init_script.sh"
    ]
  }
}