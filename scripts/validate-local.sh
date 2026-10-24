#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY_CHECK'
import copy, json
from pathlib import Path
import hcl2, yaml
from kubernetes_validate import validate
class Loader(yaml.SafeLoader):
    pass
# GitHub Actions использует YAML 1.2: ключ on не является boolean.
Loader.yaml_implicit_resolvers = copy.deepcopy(Loader.yaml_implicit_resolvers)
for key, resolvers in list(Loader.yaml_implicit_resolvers.items()):
    Loader.yaml_implicit_resolvers[key] = [(tag, regex) for tag, regex in resolvers if tag != 'tag:yaml.org,2002:bool']
for path in sorted(Path('.').rglob('*')):
    if any(part.startswith('.') and part not in ('.github', '.') for part in path.parts):
        continue
    if path.suffix in ('.yml', '.yaml'):
        list(yaml.load_all(path.read_text(), Loader=Loader))
    elif path.suffix == '.tf':
        with path.open() as f: hcl2.load(f)
config = yaml.safe_load(Path('kubernetes/monitoring/dashboard.yml').read_text())
json.loads(config['data']['diplom.json'])
for path in Path('kubernetes').rglob('*.yml'):
    if path.name == 'values.yml':
        continue
    for obj in yaml.safe_load_all(path.read_text().replace('${APP_IMAGE}', 'example/diplom:v1.0.0')):
        if obj:
            validate(obj, desired_version='1.36.0', strict=True)
print('YAML, HCL, JSON дашборда и схемы Kubernetes 1.36: OK')
PY_CHECK
for script in scripts/*.sh app/scripts/*.sh; do bash -n "$script"; done
inventory="$(mktemp)"
trap 'rm -f "$inventory"' EXIT
cat > "$inventory" <<'INVENTORY'
[server]
control-plane ansible_host=192.0.2.10 private_ip=10.10.10.10
[agents]
worker-1 ansible_host=192.0.2.11 private_ip=10.10.20.10
worker-2 ansible_host=192.0.2.12 private_ip=10.10.30.10
[k3s:children]
server
agents
INVENTORY
(cd ansible && ansible-playbook -i "$inventory" site.yml --syntax-check)
echo 'Shell и Ansible syntax-check: OK'
