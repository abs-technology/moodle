data "aws_availability_zones" "available" {
  state = "available"

  # Chỉ dùng cho giá trị mặc định: Local Zone đã opt-in sort trước AZ thường, chọn
  # nhầm sẽ lệch network border group. Muốn Local Zone thì đặt var.availability_zone.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  availability_zone = var.availability_zone != "" ? var.availability_zone : data.aws_availability_zones.available.names[0]
  break_glass       = length(var.ssh_allowed_cidrs) > 0
  # Keep keys in sync with modules/moodle-gcp (same var.os values).
  os = {
    "debian-13" = {
      ami_owners = ["136693071363"]
      ami_name   = "debian-13-amd64-*"
      ssm_arch   = "debian_amd64"
      ssh_user   = "admin"
    }
    "debian-12" = {
      ami_owners = ["136693071363"]
      ami_name   = "debian-12-amd64-*"
      ssm_arch   = "debian_amd64"
      ssh_user   = "admin"
    }
    "ubuntu-24.04" = {
      ami_owners = ["099720109477"]
      ami_name   = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      ssm_arch   = "debian_amd64"
      ssh_user   = "ubuntu"
    }
  }[var.os]
}

# Khoá sinh tại chỗ, ghi ra break-glass.pem để không phải quản lý key pair thủ công.
resource "tls_private_key" "break_glass" {
  count     = local.break_glass ? 1 : 0
  algorithm = "ED25519"
}

resource "aws_key_pair" "break_glass" {
  count      = local.break_glass ? 1 : 0
  key_name   = "${var.name}-break-glass"
  public_key = tls_private_key.break_glass[0].public_key_openssh
}

resource "local_sensitive_file" "break_glass" {
  count           = local.break_glass ? 1 : 0
  filename        = "${path.root}/break-glass.pem"
  content         = tls_private_key.break_glass[0].private_key_openssh
  file_permission = "0600"
}

data "aws_availability_zone" "selected" {
  name = local.availability_zone
}

data "aws_ami" "os" {
  most_recent = true
  owners      = local.os.ami_owners

  filter {
    name   = "name"
    values = [local.os.ami_name]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_vpc" "moodle" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "moodle" {
  vpc_id = aws_vpc.moodle.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.moodle.id
  cidr_block        = var.subnet_cidr
  availability_zone = local.availability_zone

  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.moodle.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.moodle.id
  }

  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Bình thường không có inbound 22: Session Manager đi qua kết nối agent tự mở ra.
resource "aws_security_group" "moodle" {
  name        = "${var.name}-sg"
  description = "Moodle web traffic only"
  vpc_id      = aws_vpc.moodle.id

  # Break-glass: chỉ tồn tại khi ssh_allowed_cidrs không rỗng.
  dynamic "ingress" {
    for_each = local.break_glass ? [1] : []

    content {
      description = "Break-glass SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
    }
  }

  dynamic "ingress" {
    for_each = local.alb ? [] : [1]

    content {
      description = "HTTP, redirected to HTTPS by Traefik"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = local.alb ? [] : [1]

    content {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = local.alb ? [] : [1]

    content {
      description = "HTTP/3 (QUIC)"
      from_port   = 443
      to_port     = 443
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = local.alb ? [1] : []

    content {
      description     = "Moodle from the ALB"
      from_port       = local.alb_backend_port
      to_port         = local.alb_backend_port
      protocol        = "tcp"
      security_groups = [aws_security_group.alb[0].id]
    }
  }

  dynamic "ingress" {
    for_each = local.alb_use_import ? [1] : []

    content {
      description     = "ACME HTTP-01 from the ALB"
      from_port       = 8081
      to_port         = 8081
      protocol        = "tcp"
      security_groups = [aws_security_group.alb[0].id]
    }
  }

  ingress {
    description = "ICMP (ping and Path MTU)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Docker Hub, apt, ACME and the SSM endpoints"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-sg" }
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.name}-ssm"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "acm_import" {
  count = local.alb_use_import ? 1 : 0

  statement {
    actions   = ["acm:ImportCertificate", "acm:DescribeCertificate"]
    resources = [aws_acm_certificate.imported[0].arn]
  }
}

resource "aws_iam_role_policy" "acm_import" {
  count  = local.alb_use_import ? 1 : 0
  name   = "${var.name}-acm-import"
  role   = aws_iam_role.ssm.id
  policy = data.aws_iam_policy_document.acm_import[0].json
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name}-ssm"
  role = aws_iam_role.ssm.name
}

resource "aws_eip" "moodle" {
  count  = local.alb ? 0 : 1
  domain = "vpc"

  # Local Zone có network border group riêng; cấp sai group thì không gắn được vào
  # interface trong zone đó.
  network_border_group = data.aws_availability_zone.selected.network_border_group

  tags = { Name = "${var.name}-ip" }
}

# The address is attached to an interface before the VM launches, so the VM boots
# already holding its final public IP and the nip.io name resolves immediately.
resource "aws_network_interface" "moodle" {
  subnet_id       = local.alb ? aws_subnet.private[0].id : aws_subnet.public.id
  security_groups = [aws_security_group.moodle.id]

  tags = { Name = "${var.name}-eni" }
}

resource "aws_eip_association" "moodle" {
  count                = local.alb ? 0 : 1
  allocation_id        = aws_eip.moodle[0].id
  network_interface_id = aws_network_interface.moodle.id
}

resource "random_password" "moodle_admin" {
  length      = 24
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
  # Docker Compose interpolates .env values, so $ ` " ' \ # must not appear.
  override_special = "!@%^*-_=+"
}

resource "random_password" "mariadb_root" {
  length           = 28
  override_special = "!@%^*-_=+"
}

resource "random_password" "mariadb_user" {
  length           = 28
  override_special = "!@%^*-_=+"
}

locals {
  # try(): do not index alb[0] / eip[0] when that resource's count is 0.
  public_ipv4 = coalesce(
    try(aws_globalaccelerator_accelerator.alb[0].ip_sets[0].ip_addresses[0], null),
    try(aws_eip.moodle[0].public_ip, null),
  )
  moodle_domain = var.enable_direct_ip ? local.public_ipv4 : (
    var.moodle_domain != "" ? var.moodle_domain : "moodle.${local.public_ipv4}.nip.io"
  )

  # Debian AMIs ship without the SSM agent, and Session Manager is the only way in.
  ssm_agent = <<-EOT
    tmp=$(mktemp -d)
    curl -fsSL -o "$tmp/amazon-ssm-agent.deb" \
      "https://s3.${var.region}.amazonaws.com/amazon-ssm-${var.region}/latest/${local.os.ssm_arch}/amazon-ssm-agent.deb"
    dpkg -i "$tmp/amazon-ssm-agent.deb"
    systemctl enable --now amazon-ssm-agent
    rm -rf "$tmp"
  EOT

  alb_acme_setup = !local.alb_use_import ? "" : templatefile("${path.module}/alb-acme-setup.sh.tftpl", {
    acme_email          = var.acme_email
    moodle_domain       = local.moodle_domain
    acm_certificate_arn = aws_acm_certificate.imported[0].arn
    region              = var.region
    acme_staging        = var.acme_staging ? "yes" : "no"
  })
}

module "bootstrap" {
  source = "../bootstrap"

  moodle_domain    = local.moodle_domain
  acme_email       = var.acme_email
  acme_staging     = var.acme_staging
  tls_certresolver = var.enable_global_alb || var.enable_direct_ip ? "" : "le"
  compose_relpath = (
    var.enable_global_alb ? "alb/docker-compose.yml" :
    var.enable_direct_ip ? "ip/docker-compose.yml" :
    "traefik/docker-compose.yml"
  )
  moodle_site_name      = "ABS Technology Moodle LMS"
  moodle_admin_user     = var.moodle_admin_user
  moodle_admin_password = random_password.moodle_admin.result
  mariadb_root_password = random_password.mariadb_root.result
  mariadb_password      = random_password.mariadb_user.result
  extra_bootstrap       = join("\n", compact([local.ssm_agent, local.alb_acme_setup]))
  compose_up_extra      = local.alb_use_import ? "--profile aws-le" : ""
  issue_acm_cert        = local.alb_use_import ? file("${path.module}/../../../examples/alb/issue-acm-cert.sh") : ""
  timezone              = var.timezone
}

resource "aws_instance" "moodle" {
  ami                  = data.aws_ami.os.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ssm.name
  # EC2 caps user_data at 16 KB and the bootstrap payload is past that. cloud-init
  # detects the gzip magic bytes and decompresses before running it.
  user_data_base64 = base64gzip(module.bootstrap.script)
  key_name         = local.break_glass ? aws_key_pair.break_glass[0].key_name : null

  # Provider 6.x: network_interface is deprecated. Same ENI, device index 0.
  primary_network_interface {
    network_interface_id = aws_network_interface.moodle.id
  }

  root_block_device {
    volume_size = var.disk_gb
    volume_type = "gp3"
    encrypted   = var.root_volume_encrypted
  }

  disable_api_termination = var.vm_deletion_protection

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = var.name }

  # DLM selects volumes by this tag. default_tags from the root provider merge in.
  volume_tags = {
    Name          = "${var.name}-root"
    absi-snapshot = var.name
  }

  # Bootstrap needs egress the moment it starts, and data.aws_ami rolls forward
  # weekly, which would otherwise replace a VM holding live Moodle data.
  # Traefik/IP need the EIP before first boot (nip.io). ALB needs NAT first.
  depends_on = [
    aws_route_table_association.public,
    aws_eip_association.moodle,
    aws_nat_gateway.alb,
    aws_route_table_association.private,
  ]

  lifecycle {
    ignore_changes = [user_data_base64, ami]
  }
}
