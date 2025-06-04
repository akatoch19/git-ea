resource "aws_vpc_security_group_ingress_rule" "web" {
  security_group_id = var.security_group_id
  from_port         = var.external_port
  to_port           = var.external_port
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_iam_role" "gitea" {
  name = "gitea"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = var.gitea_role_managed_policies
}

resource "aws_iam_instance_profile" "gitea" {
  name = "gitea"
  role = aws_iam_role.gitea.name
}

resource "aws_instance" "gitea" {
  ami                    = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [var.security_group_id]
  user_data              = base64encode(local.user_data)
  iam_instance_profile   = aws_iam_instance_profile.gitea.name
  subnet_id              = var.subnet_id

  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    volume_size = var.volume_size
  }

  tags = {
    Name = var.instance_name
  }

  /* provisioner "local-exec" {
    command = "curl -s http://${self.public_ip}:${var.external_port}/api/healthz; do sleep 5; done"
  } */
}
