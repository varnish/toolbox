data "aws_ami" "ubuntu-ve6" {
  most_recent = true

  filter {
    name   = "name"
    values = ["*circleci_VE_6_ubuntu_20.04*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"] # Varnish Software marketplace image
}

resource "aws_instance" "tf-ve6" {
  ami                    = data.aws_ami.ubuntu-ve6.id
  instance_type          = "${var.VE6_INSTANCE}"
  key_name               = "${var.KEY_NAME}"
  vpc_security_group_ids = [aws_security_group.s3shield_sec_22_80_443.id]
  #user_data             = data.template_file.user_data_ve6.rendered
  user_data              = "${file("../cloud-init/cloud-init-s3-shield.yaml")}"
  tags = {
    Project = "varnish-s3-shield"
    Name = "varnish-s3-shield"
  }
}
