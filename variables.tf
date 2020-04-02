variable "bucket" {
  type    = string
  default = null
}

variable "bucket_prefix" {
  type    = string
  default = null
}

variable "acl" {
  type    = string
  default = "private"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "region" {
  type    = string
  default = null
}

variable "logging" {
  type    = map(string)
  default = {}
}

variable "lifecycle_rule" {
  type    = any
  default = []
}

variable "replication_configuration" {
  type    = any
  default = {}
}

variable "versioning" {
  type    = map(string)
  default = {}
}

variable "server_side_encryption_configuration" {
  type    = any
  default = {}
}

variable "create_bucket_rw_user" {
  description = "(bool) Create IAM user with R/W access to the bucket."
  type        = bool
  default     = false
}
