locals {
  subnets = {
    a  = { zone = "ru-central1-a", cidr = "10.10.10.0/24" }
    d1 = { zone = "ru-central1-d", cidr = "10.10.20.0/24" }
    d2 = { zone = "ru-central1-d", cidr = "10.10.30.0/24" }
  }
}
resource "yandex_vpc_network" "cluster" {
  name = "${var.project_name}-vpc"
}
resource "yandex_vpc_subnet" "cluster" {
  for_each       = local.subnets
  name           = "${var.project_name}-${each.key}"
  zone           = each.value.zone
  network_id     = yandex_vpc_network.cluster.id
  v4_cidr_blocks = [each.value.cidr]
}
resource "yandex_vpc_security_group" "cluster" {
  name       = "${var.project_name}-k3s"
  network_id = yandex_vpc_network.cluster.id
  ingress {
    description       = "Обмен между узлами, включая VXLAN и kubelet"
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }
  ingress {
    description    = "SSH только с рабочей машины"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description    = "Приложение и Grafana по HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description    = "Kubernetes API для оператора и CI"
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = var.api_allowed_cidrs
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
