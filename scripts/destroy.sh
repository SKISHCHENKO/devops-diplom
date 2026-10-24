#!/usr/bin/env bash
# Удаляет только основной стек. Bootstrap и его state остаются для нового apply.
source "$(dirname "$0")/common.sh"
load_credentials
cluster_init
terraform -chdir=terraform/cluster destroy -input=false -auto-approve
