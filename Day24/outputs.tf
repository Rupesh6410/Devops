output "workspace_name" {
  value = terraform.workspace
}

output "resource_group_name" {
  value = azurerm_resource_group.demo.name
}