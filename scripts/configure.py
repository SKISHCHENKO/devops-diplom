#!/usr/bin/env python3
"""Генерирует локальные параметры из .env и outputs, не записывает секреты в git."""
import ipaddress
import json
import os
import sys
from pathlib import Path
import yaml
ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
def write_json(path, obj):
    Path(path).write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')
    Path(path).chmod(0o600)
def config():
    return dict(cloud_id=os.environ['YC_CLOUD_ID'], folder_id=os.environ['YC_FOLDER_ID'],
                project_name=os.environ['PROJECT_NAME'])
def main():
    action = sys.argv[1]
    if action == 'bootstrap':
        cidr = ipaddress.ip_network(os.environ['ADMIN_CIDR'], strict=True)
        if cidr.version != 4 or cidr.prefixlen != 32:
            raise ValueError('ADMIN_CIDR должен быть IPv4/32')
        public_key = Path(os.environ['SSH_PUBLIC_KEY_PATH']).expanduser().read_text().strip()
        if not public_key.startswith(('ssh-ed25519 ', 'ssh-rsa ', 'ecdsa-sha2-')):
            raise ValueError('Некорректный открытый SSH-ключ')
        write_json('terraform/bootstrap/config.auto.tfvars.json', config())
        write_json('terraform/cluster/config.auto.tfvars.json', dict(
            **config(), ssh_user=os.environ['SSH_USER'], ssh_public_key=public_key,
            admin_cidr=str(cidr)))
    elif action == 'credentials':
        outputs = json.loads(Path('.secrets/bootstrap-outputs.json').read_text())
        write_json('.secrets/terraform-sa.json', json.loads(outputs['service_account_key']['value']))
        write_json('.secrets/s3.json', dict(access_key=outputs['s3_access_key']['value'],
                                         secret_key=outputs['s3_secret_key']['value']))
        backend = Path('terraform/cluster/backend.hcl.example').read_text()
        backend = backend.replace('devops-diplom-state-b1gcaq8clab0al7c1qhs', outputs['bucket_name']['value'])
        Path('terraform/cluster/backend.hcl').write_text(backend)
    elif action == 'inventory':
        nodes = json.loads(Path('.generated/outputs.json').read_text())['nodes']['value']
        groups = {'server': {'hosts': {}}, 'agents': {'hosts': {}}}
        for name, node in nodes.items():
            group = 'server' if node['role'] == 'server' else 'agents'
            groups[group]['hosts'][name] = dict(
                ansible_host=node['public_ip'], private_ip=node['private_ip'],
                ansible_user=node['ssh_user'],
                ansible_ssh_private_key_file=str(Path(os.environ['SSH_PRIVATE_KEY_PATH']).expanduser().resolve()))
        inventory = {'all': {'children': {'k3s': {'children': groups}}}}
        Path('.generated/inventory.yml').write_text(yaml.safe_dump(inventory, sort_keys=False))
    else:
        raise ValueError('Неизвестное действие')
if __name__ == '__main__':
    main()
