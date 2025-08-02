# Объявление переменных для пользовательских параметров

variable "folder_id" {
  type = string
}

variable "vm_user" {
  type = string
}

variable "vm_user_nat" {
  type = string
}

variable "ssh_key_path" {
  type = string
}

# Добавление прочих переменных

locals {
  network_name     = "my-vpc"
  subnet_name1     = "public-subnet"
  subnet_name2     = "private-subnet"
  sg_nat_name      = "nat-instance-sg"
  vm_nat_name      = "nat-instance"
  route_table_name = "nat-instance-route"
}

# Создание облачной сети

resource "yandex_vpc_network" "my-vpc" {
  name = local.network_name
}

# Создание подсетей

resource "yandex_vpc_subnet" "public-subnet" {
  name           = local.subnet_name1
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.my-vpc.id
  v4_cidr_blocks = ["192.168.1.0/24"]
}

resource "yandex_vpc_subnet" "private-subnet" {
  name           = local.subnet_name2
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.my-vpc.id
  v4_cidr_blocks = ["192.168.2.0/24"]
  route_table_id = yandex_vpc_route_table.nat-instance-route.id
}

# Создание группы безопасности

resource "yandex_vpc_security_group" "nat-instance-sg" {
  name       = local.sg_nat_name
  network_id = yandex_vpc_network.my-vpc.id

  egress {
    protocol       = "ANY"
    description    = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = ["22","80","443","179","4789","6443","3389"]
    content {
      from_port = ingress.value
      to_port = ingress.value
      protocol = "TCP"
      v4_cidr_blocks = ["0.0.0.0/0"]
    }
  }

    ingress {
    protocol       = "UDP"
    description    = "BGP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 179
  }

    ingress {
    protocol       = "UDP"
    description    = "VXLAN"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 4789
  }

  ingress {
    protocol       = "ICMP"
    description    = "Allow ping within VPC"
    v4_cidr_blocks = ["192.168.0.0/16"]
  }
}

# Добавление готового образа ВМ

resource "yandex_compute_image" "ubuntu-2404-lts-oslogin" {
  source_family = "ubuntu-2404-lts-oslogin"
}

resource "yandex_compute_image" "nat-instance-ubuntu" {
  source_family = "nat-instance-ubuntu-2204"
}

# Создание загрузочных дисков

resource "yandex_compute_disk" "boot-disk-ubuntu1" {
  name     = "boot-disk-ubuntu1"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = "40"
  image_id = yandex_compute_image.ubuntu-2404-lts-oslogin.id
}

resource "yandex_compute_disk" "boot-disk-ubuntu2" {
  name     = "boot-disk-ubuntu2"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = "40"
  image_id = yandex_compute_image.ubuntu-2404-lts-oslogin.id
}

resource "yandex_compute_disk" "boot-disk-nat" {
  name     = "boot-disk-nat"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = "30"
  image_id = yandex_compute_image.nat-instance-ubuntu.id
}

# Создание ВМ

resource "yandex_compute_instance" "workerNode1" {
  name        = "worker1"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"
  allow_stopping_for_update = true

  resources {
    cores         = 4
    memory        = 8
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-ubuntu1.id
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private-subnet.id
    security_group_ids = [yandex_vpc_security_group.nat-instance-sg.id]
  }

  metadata = {
   user-data = <<EOF
#cloud-config
users:
  - name: ${var.vm_user}
    groups: sudo
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    ssh_authorized_keys:
      - ${file(var.ssh_key_path)}
hostname: workerNode1
EOF
}
}

resource "yandex_compute_instance" "workerNode2" {
  name        = "worker2"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-ubuntu2.id
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private-subnet.id
    security_group_ids = [yandex_vpc_security_group.nat-instance-sg.id]
  }

  metadata = {
user-data = <<EOF
#cloud-config
users:
  - name: ${var.vm_user}
    groups: sudo
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    ssh_authorized_keys:
      - ${file(var.ssh_key_path)}
hostname: workerNode2
EOF
}
}

# Создание ВМ NAT

resource "yandex_compute_instance" "nat-instance" {
  name        = local.vm_nat_name
  platform_id = "standard-v3"
  zone        = "ru-central1-a"
  allow_stopping_for_update = true

  resources {
    cores         = 2
    memory        = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-nat.id
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public-subnet.id
    security_group_ids = [yandex_vpc_security_group.nat-instance-sg.id]
    nat                = true
  }

  metadata = {
user-data = <<EOF
#cloud-config
users:
  - name: ${var.vm_user}
    groups: sudo
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    ssh_authorized_keys:
      - ${file(var.ssh_key_path)}
hostname: masterNode
EOF
}
}

# Создание таблицы маршрутизации и статического маршрута

resource "yandex_vpc_route_table" "nat-instance-route" {
  name       = "nat-instance-route"
  network_id = yandex_vpc_network.my-vpc.id
  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat-instance.network_interface.0.ip_address
  }
}

output "nat_instance_ip" {
  description = "Внешний IP NAT‑инстанса"
  value       = yandex_compute_instance.nat-instance.network_interface.0.nat_ip_address
}