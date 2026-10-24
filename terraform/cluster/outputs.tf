output "nodes" {
  value = {
    for name, node in yandex_compute_instance.node : name => {
      id         = node.id
      public_ip  = node.network_interface[0].nat_ip_address
      private_ip = node.network_interface[0].ip_address
      role       = local.nodes[name].worker ? "agent" : "server"
      ssh_user   = var.ssh_user
    }
  }
}
output "app_url" {
  value = "http://${yandex_vpc_address.node["control-plane"].external_ipv4_address[0].address}/"
}
output "grafana_url" {
  value = "http://${yandex_vpc_address.node["control-plane"].external_ipv4_address[0].address}/grafana/"
}
