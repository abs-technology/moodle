variable "project_id" { type = string }
variable "location" { type = string }
variable "repository_id" {
  type    = string
  default = "moodle"
}
variable "cmek_key" {
  type    = string
  default = ""
}
