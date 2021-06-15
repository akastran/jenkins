# check this answer: https://stackoverflow.com/a/53585249
output "vm_ip_association" {
  value = "${zipmap(
              azurerm_resource_group.main.*.name,
              data.azurerm_public_ip.main.*.ip_address)}"
}

output "login_username" {
  value = var.username
}

output "login_password" {
  value = var.password
}