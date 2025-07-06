locals {
  rg_name         = "rg-${var.short}-${var.loc}-${terraform.workspace}-04"
  vnet_name       = "vnet-${var.short}-${var.loc}-${terraform.workspace}-04"
  dev_subnet_name = "DevSubnet"
  nsg_name        = "nsg-${var.short}-${var.loc}-${terraform.workspace}-04"
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "1.0.0"

  #checkov:skip=CKV_TF_1:Commit hashes aren't needed when we are using terraform registry modules

  rg_name  = local.rg_name
  location = local.location
  tags     = local.tags
}