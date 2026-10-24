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
