# Bootstrap выполняется от пользователя CLI. Основной стек — только от terraform SA.
resource "yandex_iam_service_account" "terraform" {
  name      = "${var.project_name}-tf"
  folder_id = var.folder_id
}
resource "yandex_resourcemanager_folder_iam_member" "terraform" {
  for_each  = toset(["compute.editor", "vpc.admin"])
  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.terraform.id}"
}
resource "yandex_iam_service_account_key" "terraform" {
  service_account_id = yandex_iam_service_account.terraform.id
  key_algorithm      = "RSA_2048"
}
# Отдельная учетная запись S3: права выдаются ACL только на бакет state.
resource "yandex_iam_service_account" "state" {
  name      = "${var.project_name}-state"
  folder_id = var.folder_id
}
resource "yandex_iam_service_account_static_access_key" "state" {
  service_account_id = yandex_iam_service_account.state.id
  description        = "Terraform S3 backend"
}
resource "yandex_storage_bucket" "state" {
  bucket        = "${var.project_name}-state-${var.folder_id}"
  folder_id     = var.folder_id
  force_destroy = true
  max_size      = 1073741824
  grant {
    type        = "CanonicalUser"
    id          = yandex_iam_service_account.state.id
    permissions = ["FULL_CONTROL"]
  }
  anonymous_access_flags {
    read        = false
    list        = false
    config_read = false
  }
  versioning {
    enabled = true
  }
}
