resource "azurerm_resource_group" "demo" {

  name     = "demo-${terraform.workspace}-rg"

  location = var.location

}