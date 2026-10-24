#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
export KUBECONFIG="$INFRA_ROOT/.generated/admin.kubeconfig"
kubectl apply -f kubernetes/rbac/github-deployer.yml
for attempt in {1..30}; do
  kubectl -n app get secret github-deployer-token -o json > .generated/ci-token.json
  if python3 -c 'import json; assert json.load(open(".generated/ci-token.json")).get("data",{}).get("token")' 2>/dev/null; then break; fi
  sleep 2
done
kubectl config view --raw --minify -o json > .generated/ci-cluster.json
python3 - <<'PY_CONFIG'
import base64, json
from pathlib import Path
import yaml
secret = json.loads(Path('.generated/ci-token.json').read_text())
admin = json.loads(Path('.generated/ci-cluster.json').read_text())
config = {'apiVersion':'v1','kind':'Config','current-context':'github',
 'clusters':[{'name':'diplom','cluster':admin['clusters'][0]['cluster']}],
 'contexts':[{'name':'github','context':{'cluster':'diplom','user':'github-deployer','namespace':'app'}}],
 'users':[{'name':'github-deployer','user':{'token':base64.b64decode(secret['data']['token']).decode()}}]}
p = Path('.secrets/ci.kubeconfig')
p.write_text(yaml.safe_dump(config)); p.chmod(0o600)
Path('.secrets/ci-kubeconfig.b64').write_bytes(base64.b64encode(p.read_bytes()))
PY_CONFIG
rm -f .generated/ci-token.json .generated/ci-cluster.json
KUBECONFIG="$INFRA_ROOT/.secrets/ci.kubeconfig" kubectl -n app get deployment diplom-web
echo 'Секрет KUBE_CONFIG_B64 для app: содержимое .secrets/ci-kubeconfig.b64.'
