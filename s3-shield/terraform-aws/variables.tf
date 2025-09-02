variable "region" {
  type    = string
  default = "us-west-2"
}

variable "ve6_instance" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type        = string
  description = "Add your key in Key pairs in AWS"
}

variable "ami_owners" {
  type        = list(string)
  default     = ["679593333241"]
  description = "Varnish Software marketplace image"
}
