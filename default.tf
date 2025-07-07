terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

locals {
  folder_id = "b1goij3j17j0ijcoem78"
  cloud_id = "b1gg1cic3r74bfiegr3r"
}

provider "yandex" {
  cloud_id = local.cloud_id
  folder_id = local.folder_id
  service_account_key_file = "/home/kamil/Документы/authorized_key.json"
}


