#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
export KUBECONFIG="$INFRA_ROOT/.generated/admin.kubeconfig"
kubectl wait --for=condition=Ready nodes --all --timeout=120s
kubectl get nodes -o wide
kubectl get nodes -o json > .generated/nodes.json
python3 - <<'PY_NODES'
import json
from pathlib import Path
import yaml
wanted = yaml.safe_load(Path('ansible/group_vars/all.yml').read_text())['k3s_version']
nodes = json.loads(Path('.generated/nodes.json').read_text())['items']
assert len(nodes) == 3, 'Ожидаются три узла диплома.'
for node in nodes:
    version = node['status']['nodeInfo']['kubeletVersion']
    assert version == wanted, f"Узел {node['metadata']['name']}: {version}; ожидается {wanted}."
print(f'Все три узла используют {wanted}.')
PY_NODES
kubectl get pods --all-namespaces
kubectl -n app rollout status deployment/diplom-web --timeout=180s
kubectl -n monitoring get pods,pvc
kubectl -n monitoring rollout status deployment -l app.kubernetes.io/name=grafana --timeout=180s
kubectl -n monitoring rollout status statefulset -l app.kubernetes.io/name=prometheus --timeout=180s
kubectl -n monitoring rollout status statefulset -l app.kubernetes.io/name=alertmanager --timeout=180s
app_url="$(python3 -c 'import json; print(json.load(open(".generated/outputs.json"))["app_url"]["value"])')"
curl -fsS --retry 12 --retry-delay 5 --retry-all-errors "${app_url}healthz"
curl -fsS "${app_url}" | grep -q 'DevOps Diploma'
curl -fsS "${app_url}grafana/api/health"
# Проверить наличие метрик, а не только запущенных контейнеров.
for component in prometheus alertmanager; do
  kubectl -n monitoring wait pod -l "app.kubernetes.io/name=$component" --for=condition=Ready --timeout=180s
done
prometheus_name="$(kubectl -n monitoring get prometheus -o jsonpath='{.items[0].metadata.name}')"
prometheus_port=19090
kubectl -n monitoring port-forward "pod/prometheus-${prometheus_name}-0" "$prometheus_port:9090" > .generated/prometheus-port-forward.log 2>&1 &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true' EXIT
curl --retry 20 --retry-delay 1 --retry-connrefused -fsS "http://127.0.0.1:$prometheus_port/-/ready" > /dev/null
curl -fsSG "http://127.0.0.1:$prometheus_port/api/v1/query" \
  --data-urlencode 'query=sum(kube_node_status_condition{condition="Ready",status="true"})' \
  > .generated/node-metrics.json
for exporter in node-exporter kube-state-metrics; do
  curl -fsSG "http://127.0.0.1:$prometheus_port/api/v1/query" \
    --data-urlencode "query=sum(up{job=~\".*${exporter}.*\"})" \
    > ".generated/${exporter}-metrics.json"
done
python3 - <<'PY_METRICS'
import json
from pathlib import Path
result = json.loads(Path('.generated/node-metrics.json').read_text())
assert result['status'] == 'success', result
values = result['data']['result']
assert values and float(values[0]['value'][1]) == 3, 'В Prometheus пока нет метрики трех Ready-узлов. Повторите проверку через 2 минуты.'
for exporter, minimum in [('node-exporter', 3), ('kube-state-metrics', 1)]:
    metrics = json.loads(Path(f'.generated/{exporter}-metrics.json').read_text())
    assert metrics['status'] == 'success', metrics
    values = metrics['data']['result']
    assert values and float(values[0]['value'][1]) >= minimum, f'{exporter}: в Prometheus пока нет {minimum} доступных целей; повторите проверку через 2 минуты.'
print('Метрика трех Ready-узлов и доступность обоих экспортеров подтверждены в Prometheus.')
PY_METRICS
echo
echo "Приложение: $app_url"
echo "Grafana: ${app_url}grafana/"
echo 'Откройте дашборд «Диплом — Kubernetes» через 2–5 минут после установки.'
