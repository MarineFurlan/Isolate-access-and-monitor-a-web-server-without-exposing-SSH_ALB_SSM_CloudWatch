variable "email_address" {
  type = string
  default = "marinefurlan@hotmail.fr"
}

variable "name" {
  type    = string
  default = "webApp"
}

variable "public_subnets" {
  type = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnets" {
  type = list(string)
  default = ["10.0.100.0/24", "10.0.101.0/24"]
}

variable "region" {
  type    = string
  default = "eu-west-3"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}