#!/usr/bin/env bash
set -euo pipefail
INFRA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$INFRA_ROOT"
if [[ ! -f .env ]]; then
  echo 'Сначала: cp .env.example .env; затем заполните ADMIN_CIDR и IMAGE_NAME.' >&2
  exit 1
fi
set -a
source .env
set +a
umask 077
mkdir -p .secrets .generated
# Один кэш для bootstrap, основного стека и следующих запусков.
# Пользовательский TF_PLUGIN_CACHE_DIR из .env/окружения имеет приоритет.
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"
need() { command -v "$1" >/dev/null || { echo "Не найдена команда: $1" >&2; exit 1; }; }
load_credentials() {
  [[ -s .secrets/terraform-sa.json && -s .secrets/s3.json ]] || {
    echo 'Сначала выполните scripts/bootstrap.sh.' >&2; exit 1;
  }
  unset YC_TOKEN YC_SERVICE_ACCOUNT_KEY
  export YC_SERVICE_ACCOUNT_KEY_FILE="$INFRA_ROOT/.secrets/terraform-sa.json"
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
  AWS_ACCESS_KEY_ID="$(python3 -c 'import json; print(json.load(open(".secrets/s3.json"))["access_key"])')"
  AWS_SECRET_ACCESS_KEY="$(python3 -c 'import json; print(json.load(open(".secrets/s3.json"))["secret_key"])')"
  # Контрольные суммы AWS SDK новых версий не поддерживаются всеми S3-провайдерами.
  export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
  export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
}
prepare_terraform_cache() {
  # Подхватить пакеты, установленные в этом проекте до включения общего кэша.
  # Копируется весь пакет; проверка его checksum остаётся за Terraform.
  python3 - "$INFRA_ROOT" "$TF_PLUGIN_CACHE_DIR" <<'PY_CACHE'
from pathlib import Path
import os, shutil, sys, tempfile
root, cache = (Path(value).expanduser().resolve() for value in sys.argv[1:])
for stack in ('bootstrap', 'cluster'):
    providers = root / 'terraform' / stack / '.terraform' / 'providers'
    for source in providers.glob('registry.terraform.io/yandex-cloud/yandex/*/*'):
        if not source.is_dir():
            continue
        binaries = [p for p in source.glob('terraform-provider-yandex*')
                    if p.is_file() and p.stat().st_size > 0 and os.access(p, os.X_OK)]
        if not binaries:
            continue
        target = cache / source.relative_to(providers)
        if target.exists() or target.is_symlink():
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = Path(tempfile.mkdtemp(prefix='.provider-import-', dir=cache))
        try:
            shutil.copytree(source, temporary / 'package', symlinks=False)
            if not target.exists() and not target.is_symlink():
                try:
                    (temporary / 'package').rename(target)
                except FileExistsError:
                    continue
                print(f'Terraform: пакет добавлен в кэш из {stack}: {source.relative_to(providers)}')
        finally:
            shutil.rmtree(temporary)
PY_CACHE
}
cluster_init() {
  prepare_terraform_cache
  printf 'Terraform: кэш провайдеров %s\n' "$TF_PLUGIN_CACHE_DIR"
  terraform -chdir=terraform/cluster init -input=false -reconfigure -backend-config=backend.hcl
}
