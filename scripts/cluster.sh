#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need terraform; need ansible-playbook; need kubectl
load_credentials
cluster_init
terraform -chdir=terraform/cluster apply -input=false -auto-approve
terraform -chdir=terraform/cluster output -json > .generated/outputs.json
python3 scripts/configure.py inventory
(cd ansible && ansible-playbook -i ../.generated/inventory.yml site.yml)
mkdir -p "$HOME/.kube"
chmod 700 "$HOME/.kube"
if [[ -f "$HOME/.kube/config" ]]; then
  cp "$HOME/.kube/config" "$HOME/.kube/config.before-diplom-$(date +%Y%m%d-%H%M%S)"
fi
install -m 600 .generated/admin.kubeconfig "$HOME/.kube/config"
export KUBECONFIG="$INFRA_ROOT/.generated/admin.kubeconfig"
kubectl get nodes -o wide
kubectl get pods --all-namespaces
terraform -chdir=terraform/cluster output app_url
terraform -chdir=terraform/cluster output grafana_url
