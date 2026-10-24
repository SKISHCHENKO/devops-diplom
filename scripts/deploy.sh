#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need kubectl; need helm; need openssl
[[ "$IMAGE_NAME" != YOUR_* ]] || { echo 'Заполните IMAGE_NAME в .env.' >&2; exit 1; }
export KUBECONFIG="$INFRA_ROOT/.generated/admin.kubeconfig"
[[ -s "$KUBECONFIG" ]] || { echo 'Сначала scripts/cluster.sh.' >&2; exit 1; }
kubectl -n kube-system rollout status deployment/traefik --timeout=300s
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
if [[ ! -s .secrets/grafana-password ]]; then openssl rand -hex 16 | tr -d '\n' > .secrets/grafana-password; fi
kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin --from-file=admin-password=.secrets/grafana-password \
  --dry-run=client -o yaml | kubectl apply -f -
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update
python3 - <<'PY_EXTERNAL'
import json
from pathlib import Path
import yaml
url = json.loads(Path('.generated/outputs.json').read_text())['grafana_url']['value']
Path('.generated/external-values.yml').write_text(yaml.safe_dump({'grafana': {'grafana.ini': {'server': {'root_url': url}}}}))
PY_EXTERNAL
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --version 92.10.1 \
  --values kubernetes/monitoring/values.yml --values .generated/external-values.yml --wait --timeout 15m
kubectl apply -f kubernetes/monitoring/dashboard.yml -f kubernetes/monitoring/ingress.yml
kubectl apply -f kubernetes/app/namespace.yml
export APP_IMAGE="$IMAGE_NAME:$IMAGE_TAG"
# Рендерим только APP_IMAGE; nginx-переменные и чужие env не подставляются.
python3 - <<'PY_RENDER'
import os
from pathlib import Path
text = Path('kubernetes/app/deployment.yml').read_text()
Path('.generated/deployment.yml').write_text(text.replace('${APP_IMAGE}', os.environ['APP_IMAGE']))
PY_RENDER
kubectl apply -f .generated/deployment.yml
kubectl apply -f kubernetes/app/service.yml -f kubernetes/app/ingress.yml
kubectl -n app rollout status deployment/diplom-web --timeout=300s
bash scripts/create-ci-kubeconfig.sh
echo 'Мониторинг и приложение установлены. Логин Grafana: admin.'
echo 'Пароль: локальный файл .secrets/grafana-password.'
