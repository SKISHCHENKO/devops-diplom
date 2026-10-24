output "bucket_name" {
  value = yandex_storage_bucket.state.bucket
}
output "terraform_service_account_id" {
  value = yandex_iam_service_account.terraform.id
}
output "service_account_key" {
  sensitive = true
  value = jsonencode({
    id                 = yandex_iam_service_account_key.terraform.id
    service_account_id = yandex_iam_service_account.terraform.id
    created_at         = yandex_iam_service_account_key.terraform.created_at
    key_algorithm      = yandex_iam_service_account_key.terraform.key_algorithm
    public_key         = yandex_iam_service_account_key.terraform.public_key
    private_key        = yandex_iam_service_account_key.terraform.private_key
  })
}
output "s3_access_key" {
  value     = yandex_iam_service_account_static_access_key.state.access_key
  sensitive = true
}
output "s3_secret_key" {
  value     = yandex_iam_service_account_static_access_key.state.secret_key
  sensitive = true
}
