
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraformstatesRG"
    storage_account_name = "terraformstate737"
    container_name       = "tfstateblob"
    key                  = "devops-dojo/new-terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}