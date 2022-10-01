# Не забудьте установить переменную окружения YC_TOKEN

# По абсолютно непонятной причине ИНОГДА подсеть с route_table_id не создается. 
# Поэтому мы вынуждены воспользоваться CLI и `provisioner "local-exec"`
# Это лишает нас возможности вносить изменения без полного пересоздания 
# инфраструктуры, так как терраформ заметит появление route_table_id и удалит ее, 
# а провизионера повторно не запустит, ибо при update in-place они не запускаются.
# So much for idempotency. Или привязывать таблицы маршрутизации вручную после отработки
# terraform apply. 

# Имеющиеся каталоги: 
# +----------------------+-----------------------+--------+--------+
# |          ID          |         NAME          | LABELS | STATUS |
# +----------------------+-----------------------+--------+--------+
# | b1ggier8f3m51vu1sktu | default               |        | ACTIVE |
# | b1g8ok924udnrjpvt6e2 | netology-diploma      |        | ACTIVE |
# | b1gqei70aff6i0as1u4h | netology-diploma-prod |        | ACTIVE |
# +----------------------+-----------------------+--------+--------+
#
# netology-diploma-prod - каталог для "продакшен".
# Для развертывания инфраструктуры в этом каталоге нужно переключить workspace на 
# "prod". Для развертывания инфраструктуры в каталоге netology-diploma - на "stage".

variable "folder_id_stage" {
  type    = string
  default = "b1g8ok924udnrjpvt6e2"
}
variable "folder_id_prod" {
  type    = string
  default = "b1gqei70aff6i0as1u4h"
}
variable "cloud_id" {
  type    = string
  default = "b1g474fnftkc2uanhkrp"
}
variable "zone" {
  type    = string
  default = "ru-central1-a"
}
provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = "${terraform.workspace == "stage" ? var.folder_id_stage : var.folder_id_prod}"
  zone      = var.zone
}

resource "yandex_vpc_address" "app_ip_address" {
  name        = "app_ip_address"
  description = "Статический адрес для веб-сервера"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}
output "app_ip_address" {
  value = yandex_vpc_address.app_ip_address.external_ipv4_address[0].address
}

resource "yandex_vpc_network" "network1" {
  name = "network1"
}

resource "yandex_dns_zone" "dev-cbg-ru" {
  name             = "dev-cbg-ru"
  description      = "dev.cbg.ru"
  zone             = "dev.cbg.ru."
  public           = true
  private_networks = [yandex_vpc_network.network1.id]
}

locals {
  domain_names = ["www", "app", "gitlab", "prometheus", "grafana", "alertmanager"]
}

resource "yandex_dns_recordset" "rs" {
  for_each = toset(local.domain_names)

  zone_id = yandex_dns_zone.dev-cbg-ru.id
  name    = "${each.value}.${yandex_dns_zone.dev-cbg-ru.zone}"
  type    = "A"
  ttl     = 600
  data    = [yandex_vpc_address.app_ip_address.external_ipv4_address[0].address]
}

resource "yandex_vpc_gateway" "nat-gateway" {
  name = "nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "nat-route" {
  network_id = yandex_vpc_network.network1.id
  name       = "nat-route"
  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat-gateway.id
  }
}

resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  v4_cidr_blocks = ["192.168.30.0/24"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network1.id
  route_table_id = yandex_vpc_route_table.nat-route.id
  #provisioner "local-exec" {
  #  command = "yc vpc subnet update ${self.name} --route-table-id ${yandex_vpc_route_table.nat-route.id} --folder-id ${var.folder_id}"
  #}
}

resource "yandex_vpc_subnet" "subnet-b" {
  name           = "subnet-b"
  v4_cidr_blocks = ["192.168.31.0/24"]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network1.id
  route_table_id = yandex_vpc_route_table.nat-route.id
  #provisioner "local-exec" {
  #  command = "yc vpc subnet update ${self.name} --route-table-id ${yandex_vpc_route_table.nat-route.id} --folder-id ${var.folder_id}"
  #}
}

# Jump host for ssh access to internal network.
resource "yandex_compute_instance" "jump" {
  name        = "jump"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"
  hostname    = "jump"
  resources {
    cores         = 2
    memory        = 1
    core_fraction = 5
  }
  boot_disk {
    initialize_params {
      image_id = "fd8le2jsge1bop4m18ts" # Debian 11
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = true
  }
  metadata = {
    user-data = "${file("cloud-config.yml")}"
  }
  scheduling_policy {
    preemptible = true
  }
}
output "jump_host_ip" {
  value = yandex_compute_instance.jump.network_interface.0.nat_ip_address
}


# NGINX host with an external IP address.
resource "yandex_compute_instance" "nginx" {
  allow_stopping_for_update = true
  name                      = "nginx"
  platform_id               = "standard-v1"
  zone                      = "ru-central1-a"
  hostname                  = "nginx"
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
  boot_disk {
    initialize_params {
      image_id = "fd8le2jsge1bop4m18ts" # Debian 11
    }
  }
  network_interface {
    subnet_id      = yandex_vpc_subnet.subnet-a.id
    ip_address     = "192.168.30.8"
    nat_ip_address = yandex_vpc_address.app_ip_address.external_ipv4_address[0].address

    #    nat            = true
  }
  metadata = {
    user-data = "${file("cloud-config.yml")}"
  }
  scheduling_policy {
    preemptible = true
  }
}

# Database host db01
resource "yandex_compute_instance" "db01" {
  allow_stopping_for_update = true
  name                      = "db01"
  platform_id               = "standard-v1"
  zone                      = "ru-central1-b"
  hostname                  = "db01"
  resources {
    cores         = 4
    memory        = 4
    core_fraction = 20
  }
  boot_disk {
    initialize_params {
      image_id = "fd8le2jsge1bop4m18ts" # Debian 11
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-b.id
    nat       = false
  }
  metadata = {
    user-data = "${file("cloud-config.yml")}"
  }
  scheduling_policy {
    preemptible = true
  }
}

# Database host db02
resource "yandex_compute_instance" "db02" {
  allow_stopping_for_update = true
  name                      = "db02"
  platform_id               = "standard-v1"
  zone                      = "ru-central1-a"
  hostname                  = "db02"
  resources {
    cores         = 4
    memory        = 4
    core_fraction = 20
  }
  boot_disk {
    initialize_params {
      image_id = "fd8le2jsge1bop4m18ts" # Debian 11
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = false
  }
  metadata = {
    user-data = "${file("cloud-config.yml")}"
  }
  scheduling_policy {
    preemptible = true
  }
}

# Gitlab host
resource "yandex_compute_instance" "gitlab" {
  allow_stopping_for_update = true
  name                      = "gitlab"
  platform_id               = "standard-v1"
  zone                      = "ru-central1-a"
  hostname                  = "gitlab"
  resources {
    cores         = 4
    memory        = 4
    core_fraction = 20
  }
  boot_disk {
    initialize_params {
      image_id = "fd8mf4ur8epk3qdq3jlk" # Gitlab 15.3
      size     = 40
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = false
  }
  metadata = {
    user-data = "${file("cloud-config.yml")}"
  }
  scheduling_policy {
    preemptible = true
  }
}

# Gitlab runner host
resource "yandex_compute_instance" "runner" {
  allow_stopping_for_update = true
  name                      = "runner"
  platform_id               = "standard-v1"
  zone                      = "ru-central1-a"
  hostname                  = "runner"
  resources {
    cores         = 2
    memory        = 1
    core_fraction = 5
  }
  boot_disk {
    initialize_params {
      image_id = "fd8le2jsge1bop4m18ts" # Debian 11
      size     = 40
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = false
  }
  metadata = {
    user-data = "${file("cloud-config.yml")}"
  }
  scheduling_policy {
    preemptible = true
  }
}

# Wordpress host.
resource "yandex_compute_instance" "app" {
  allow_stopping_for_update = true
  name                      = "app"
  platform_id               = "standard-v1"
  zone                      = "ru-central1-a"
  hostname                  = "app"
  resources {
    cores         = 4
    memory        = 4
    core_fraction = 20
  }
  boot_disk {
    initialize_params {
      image_id = "fd8le2jsge1bop4m18ts" # Debian 11
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = false
  }
  metadata = {
    user-data = "${file("cloud-config.yml")}"
  }
  scheduling_policy {
    preemptible = true
  }
}

# Monitoring host 
resource "yandex_compute_instance" "monitoring" {
  allow_stopping_for_update = true
  name                      = "monitoring"
  platform_id               = "standard-v1"
  zone                      = "ru-central1-b"
  hostname                  = "monitoring"
  resources {
    cores         = 4
    memory        = 4
    core_fraction = 5
  }
  boot_disk {
    initialize_params {
      image_id = "fd8le2jsge1bop4m18ts" # Debian 11
      size     = 40
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-b.id
    nat       = false
  }
  metadata = {
    user-data = "${file("cloud-config.yml")}"
  }
  scheduling_policy {
    preemptible = false
  }
}
