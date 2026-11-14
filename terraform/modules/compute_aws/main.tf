# Dynamically fetch the newest official Amazon Linux 2023 AMI for the active AWS region
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Official Amazon Linux AMI owner

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_key_pair" "this" {
  count      = var.ssh_public_key != null ? 1 : 0
  key_name   = "${var.vm_name}-key"
  public_key = var.ssh_public_key

  tags = merge(var.tags, {
    Name = "${var.vm_name}-key"
  })
}

resource "aws_security_group" "allow_jenkins" {
  name        = "${var.vm_name}-allow-jenkins"
  description = "Allow inbound TCP ports 8080 and 22"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "Allow Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.vm_name}-allow-jenkins"
  })
}

# Clean Amazon Linux 2023 EC2 instance (no user-data scripts)
resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.machine_type
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.allow_jenkins.id]
  associate_public_ip_address = true
  key_name                    = var.ssh_public_key != null ? aws_key_pair.this[0].key_name : null

  # Enforce IMDSv2 to prevent SSRF credential theft
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = var.disk_size_gb
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = var.vm_name
  })
}

