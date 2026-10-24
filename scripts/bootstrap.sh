#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
need yc; need terraform; need python3
# Не меняем активный CLI-профиль: явно передаем --profile.
actual_cloud="$(yc --profile "$YC_PROFILE" config get cloud-id)"
actual_folder="$(yc --profile "$YC_PROFILE" config get folder-id)"
[[ "$actual_cloud" == "$YC_CLOUD_ID" && "$actual_folder" == "$YC_FOLDER_ID" ]] || {
  echo 'Cloud/folder выбранного CLI-профиля не совпадают с .env.' >&2; exit 1;
}
python3 scripts/configure.py bootstrap
unset YC_SERVICE_ACCOUNT_KEY_FILE YC_SERVICE_ACCOUNT_KEY
export YC_TOKEN
YC_TOKEN="$(yc --profile "$YC_PROFILE" iam create-token)"
prepare_terraform_cache
printf 'Terraform: кэш провайдеров %s\n' "$TF_PLUGIN_CACHE_DIR"
terraform -chdir=terraform/bootstrap init -input=false
terraform -chdir=terraform/bootstrap apply -input=false -auto-approve
terraform -chdir=terraform/bootstrap output -json > .secrets/bootstrap-outputs.json
python3 scripts/configure.py credentials
unset YC_TOKEN
# Последующие операции Terraform работают от сервисного аккаунта.
load_credentials
cluster_init
echo 'Bootstrap готов. Следующий шаг: scripts/cluster.sh'
