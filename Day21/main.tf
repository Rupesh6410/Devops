// Terraform configuration for Azure Resource Group
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = ""
  resource_provider_registrations="none"
}

resource "azurerm_resource_group" "demo" {
  name     = "demo-rg-1"
  location = "Central India"
}
