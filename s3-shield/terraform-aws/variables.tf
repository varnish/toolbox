variable REGION {
  type = string
  default = "us-west-2"
}

variable VE6_INSTANCE {
  type = string
  default = "t2.micro"
}

# Add your key in Key pairs in AWS and change the name under
variable KEY_NAME {
  type = string
  default = "your_key_pair_name"
}

