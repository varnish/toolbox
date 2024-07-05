resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_security_group" "s3shield_sec_22_80_443" {
  name        = "tf_s3shield_allow_22_80_443"
  description = "Allow Trafic in to VE6"
  vpc_id      = aws_default_vpc.default.id
  tags = {
    Name = "s3shield_allow_in_22_80_443"
  }

  dynamic "ingress" {
    iterator = port
    for_each = [22, 80, 443]
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.s3shield_sec_22_80_443.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.s3shield_sec_22_80_443.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
