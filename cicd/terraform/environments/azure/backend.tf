# Remote State Backend (Azure Storage Blob)
# Azure Blob Storage provides built-in lease locking at no extra service fee.
#
# To activate remote state:
# 1. Create a resource group, storage account, and blob container once:
#    az group create --name rg-company-bot-tfstate --location centralindia
#    az storage account create --name companybottfstate --resource-group rg-company-bot-tfstate --location centralindia --sku Standard_LRS
#    az storage container create --name tfstate --account-name companybottfstate
# 2. Uncomment the block below and run:
#    terraform init -migrate-state
#
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "rg-company-bot-tfstate"
#     storage_account_name = "companybottfstate"
#     container_name       = "tfstate"
#     key                  = "azure.terraform.tfstate"
#   }
# }

