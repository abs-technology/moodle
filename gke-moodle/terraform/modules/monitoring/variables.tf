variable "project_id" { type = string }
variable "name" { type = string }
variable "sql_instance_name" { type = string }
variable "notification_email" {
  type    = string
  default = ""
}
