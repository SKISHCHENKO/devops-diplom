data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}
locals {
  nodes = {
    control-plane = { subnet = "a", ip = "10.10.10.10", worker = false }
    worker-1      = { subnet = "b", ip = "10.10.20.10", worker = true }
    worker-2      = { subnet = "d", ip = "10.10.30.10", worker = true }
  }
}
# Стабильные публичные адреса сохраняются при остановке прерываемых workers.
resource "yandex_vpc_address" "node" {
  for_each = local.nodes
  name     = "${var.project_name}-${each.key}"
  external_ipv4_address {
    zone_id = local.subnets[each.value.subnet].zone
  }
}
resource "yandex_compute_instance" "node" {
  for_each    = local.nodes
  name        = "${var.project_name}-${each.key}"
  hostname    = each.key
  zone        = local.subnets[each.value.subnet].zone
  platform_id = "standard-v3"
  resources {
    cores         = 2
    memory        = each.value.worker ? var.worker_memory : var.server_memory
    core_fraction = var.core_fraction
  }
  scheduling_policy {
    preemptible = each.value.worker
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-ssd"
      size     = each.value.worker ? 20 : 32
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.cluster[each.value.subnet].id
    ip_address         = each.value.ip
    nat                = true
    nat_ip_address     = yandex_vpc_address.node[each.key].external_ipv4_address[0].address
    security_group_ids = [yandex_vpc_security_group.cluster.id]
  }
  metadata = {
    user-data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      ssh_user = var.ssh_user, ssh_public_key = var.ssh_public_key
    })
  }
  labels = { project = var.project_name, role = each.value.worker ? "worker" : "server" }
}
