terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.13"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.2.3"
    }

  }

  backend "s3" {
    endpoint = "storage.yandexcloud.net"
    bucket   = "tf-backend"
    region   = "ru-central1"
    key      = "terraform.tfstate"

    shared_credentials_file = "~/.aws/credentials"
    profile                 = "netology-diploma"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}
