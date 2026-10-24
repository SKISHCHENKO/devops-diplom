variable "cloud_id" {
  type = string
}
variable "folder_id" {
  type = string
}
variable "project_name" {
  type    = string
  default = "devops-diplom"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,24}$", var.project_name))
    error_message = "project_name: 3–25 строчных букв, цифр и дефисов, начиная с буквы."
  }
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}
variable "ssh_public_key" {
  type = string
}
variable "admin_cidr" {
  type = string
  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && can(regex("/32$", var.admin_cidr))
    error_message = "Укажите внешний IPv4 рабочей машины с маской /32."
  }
}
variable "api_allowed_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "API доступен GitHub-hosted runners; доступ к Kubernetes защищен TLS и RBAC."
}
variable "server_memory" {
  type    = number
  default = 4
}
variable "worker_memory" {
  type    = number
  default = 2
}
variable "core_fraction" {
  type    = number
  default = 20
}
