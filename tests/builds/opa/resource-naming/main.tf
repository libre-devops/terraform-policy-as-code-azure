locals {
  rg_name         = "rg-${var.short}-${var.loc}-${terraform.workspace}-04"
  vnet_name       = "vnet-${var.short}-${var.loc}-${terraform.workspace}-04"
  dev_subnet_name = "DevSubnet"
  nsg_name        = "nsg-${var.short}-${var.loc}-${terraform.workspace}-04"
}

module "rg" {
  source = "libre-devops/rg/azurerm"

  rg_name  = local.rg_name
  location = local.location
  tags     = local.tags
}