# aws-alb only: Global Accelerator (anycast) → regional ALB → Moodle :8080.
# No Traefik. The VM stays in a private subnet (NAT for egress). Same shape as
# terraform/modules/moodle-gcp/alb.tf — AWS has no global HTTP LB, so Anycast
# is Global Accelerator in front of a regional Application Load Balancer.

locals {
  alb              = var.enable_global_alb
  alb_backend_port = 8080
  alb_name         = substr("${var.name}-alb", 0, 32)

  alb_azs = data.aws_availability_zones.available.names
  alb_az_b = (
    length(local.alb_azs) > 1 && local.alb_azs[0] == local.availability_zone
    ? local.alb_azs[1]
    : local.alb_azs[0]
  )

  alb_private_cidr   = cidrsubnet(var.vpc_cidr, 8, 2)
  alb_private_b_cidr = cidrsubnet(var.vpc_cidr, 8, 11)

  alb_use_arn     = local.alb && var.acm_certificate_arn != ""
  alb_use_route53 = local.alb && !local.alb_use_arn && var.route53_zone_id != "" && var.moodle_domain != ""
  alb_use_import  = local.alb && !local.alb_use_arn && !local.alb_use_route53

  alb_cert_arn = local.alb ? coalesce(
    var.acm_certificate_arn != "" ? var.acm_certificate_arn : null,
    try(aws_acm_certificate_validation.alb[0].certificate_arn, null),
    try(aws_acm_certificate.imported[0].arn, null),
  ) : ""
}

# ---------------------------------------------------------------------------
# Extra subnets: internal ALB needs two AZs. VM is private; NAT stays on
# the existing public subnet (AZ A) so Traefik/IP sites keep their addresses.
# ---------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count             = local.alb ? 1 : 0
  vpc_id            = aws_vpc.moodle.id
  cidr_block        = local.alb_private_cidr
  availability_zone = local.availability_zone

  tags = { Name = "${var.name}-private" }
}

resource "aws_subnet" "private_b" {
  count             = local.alb ? 1 : 0
  vpc_id            = aws_vpc.moodle.id
  cidr_block        = local.alb_private_b_cidr
  availability_zone = local.alb_az_b

  tags = { Name = "${var.name}-private-b" }
}

resource "aws_eip" "nat" {
  count                = local.alb ? 1 : 0
  domain               = "vpc"
  network_border_group = data.aws_availability_zone.selected.network_border_group

  tags = { Name = "${var.name}-nat" }
}

resource "aws_nat_gateway" "alb" {
  count         = local.alb ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id

  tags = { Name = "${var.name}-nat" }

  depends_on = [aws_internet_gateway.moodle]
}

resource "aws_route_table" "private" {
  count  = local.alb ? 1 : 0
  vpc_id = aws_vpc.moodle.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.alb[0].id
  }

  tags = { Name = "${var.name}-private" }
}

resource "aws_route_table_association" "private" {
  count          = local.alb ? 1 : 0
  subnet_id      = aws_subnet.private[0].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_route_table_association" "private_b" {
  count          = local.alb ? 1 : 0
  subnet_id      = aws_subnet.private_b[0].id
  route_table_id = aws_route_table.private[0].id
}

# ---------------------------------------------------------------------------
# Certificate. ACM cannot issue a public cert for nip.io (no DNS you control).
# First boot imports a placeholder so the HTTPS listener exists; the VM then
# completes Let's Encrypt HTTP-01 and re-imports onto the same ACM ARN.
# ---------------------------------------------------------------------------

resource "tls_private_key" "alb" {
  count     = local.alb_use_import ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb" {
  count           = local.alb_use_import ? 1 : 0
  private_key_pem = tls_private_key.alb[0].private_key_pem

  validity_period_hours = 24 * 365 * 2
  early_renewal_hours   = 24 * 30
  dns_names             = [local.moodle_domain]
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]

  subject {
    common_name = local.moodle_domain
  }
}

resource "aws_acm_certificate" "imported" {
  count            = local.alb_use_import ? 1 : 0
  private_key      = tls_private_key.alb[0].private_key_pem
  certificate_body = tls_self_signed_cert.alb[0].cert_pem

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "public" {
  count             = local.alb_use_route53 ? 1 : 0
  domain_name       = var.moodle_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert" {
  for_each = local.alb_use_route53 ? {
    for dvo in aws_acm_certificate.public[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "alb" {
  count                   = local.alb_use_route53 ? 1 : 0
  certificate_arn         = aws_acm_certificate.public[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert : r.fqdn]
}

# ---------------------------------------------------------------------------
# Internal ALB. Only the Global Accelerator anycast IPs are public (GCP-like).
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  count       = local.alb ? 1 : 0
  name        = "${var.name}-alb"
  description = "Global Accelerator / internet to the ALB"
  vpc_id      = aws_vpc.moodle.id

  ingress {
    description = "HTTP, redirected to HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Moodle :8080 and health checks"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-alb" }
}

resource "aws_lb" "alb" {
  count              = local.alb ? 1 : 0
  name               = local.alb_name
  load_balancer_type = "application"
  internal           = true
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = [aws_subnet.private[0].id, aws_subnet.private_b[0].id]
  idle_timeout       = 60
  ip_address_type    = "ipv4"

  enable_http2               = true
  enable_deletion_protection = var.vm_deletion_protection
  desync_mitigation_mode     = "defensive"
  drop_invalid_header_fields = true

  tags = { Name = "${var.name}-alb" }

  lifecycle {
    precondition {
      condition     = length(local.alb_azs) >= 2
      error_message = "aws-alb needs two Availability Zones in this region."
    }
    precondition {
      condition     = var.availability_zone == "" || data.aws_availability_zone.selected.opt_in_status == "opt-in-not-required"
      error_message = "aws-alb uses regional AZs only. Leave availability_zone empty."
    }
    precondition {
      condition     = !(var.enable_direct_ip && var.enable_global_alb)
      error_message = "enable_direct_ip and enable_global_alb cannot both be true."
    }
  }
}

resource "aws_lb_target_group" "moodle" {
  count                = local.alb ? 1 : 0
  name                 = local.alb_name
  port                 = local.alb_backend_port
  protocol             = "HTTP"
  vpc_id               = aws_vpc.moodle.id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/readyz"
    port                = tostring(local.alb_backend_port)
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "${var.name}-moodle" }
}

resource "aws_lb_target_group_attachment" "moodle" {
  count            = local.alb ? 1 : 0
  target_group_arn = aws_lb_target_group.moodle[0].arn
  target_id        = aws_instance.moodle.id
  port             = local.alb_backend_port
}

resource "aws_lb_target_group" "acme" {
  count                = local.alb_use_import ? 1 : 0
  name                 = substr("${var.name}-acme", 0, 32)
  port                 = 8081
  protocol             = "HTTP"
  vpc_id               = aws_vpc.moodle.id
  target_type          = "instance"
  deregistration_delay = 10

  health_check {
    enabled             = true
    path                = "/healthz"
    port                = "8081"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "${var.name}-acme" }
}

resource "aws_lb_target_group_attachment" "acme" {
  count            = local.alb_use_import ? 1 : 0
  target_group_arn = aws_lb_target_group.acme[0].arn
  target_id        = aws_instance.moodle.id
  port             = 8081
}

resource "aws_lb_listener" "http" {
  count             = local.alb ? 1 : 0
  load_balancer_arn = aws_lb.alb[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Let's Encrypt must stay on HTTP. A blanket 80→443 redirect would send the
# HTTP-01 probe to the placeholder cert and fail.
resource "aws_lb_listener_rule" "acme" {
  count        = local.alb_use_import ? 1 : 0
  listener_arn = aws_lb_listener.http[0].arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.acme[0].arn
  }

  condition {
    path_pattern {
      values = ["/.well-known/acme-challenge/*"]
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.alb ? 1 : 0
  load_balancer_arn = aws_lb.alb[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.alb_cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.moodle[0].arn
  }
}

# ---------------------------------------------------------------------------
# Anycast. Created first so moodle.<ip>.nip.io is known before the VM boots.
# ---------------------------------------------------------------------------

resource "aws_globalaccelerator_accelerator" "alb" {
  count           = local.alb ? 1 : 0
  name            = var.name
  ip_address_type = "IPV4"
  enabled         = true

  attributes {
    flow_logs_enabled = false
  }
}

resource "aws_globalaccelerator_listener" "http" {
  count           = local.alb ? 1 : 0
  accelerator_arn = aws_globalaccelerator_accelerator.alb[0].id
  protocol        = "TCP"
  client_affinity = "NONE"

  port_range {
    from_port = 80
    to_port   = 80
  }
}

resource "aws_globalaccelerator_listener" "https" {
  count           = local.alb ? 1 : 0
  accelerator_arn = aws_globalaccelerator_accelerator.alb[0].id
  protocol        = "TCP"
  client_affinity = "SOURCE_IP"

  port_range {
    from_port = 443
    to_port   = 443
  }
}

resource "aws_globalaccelerator_endpoint_group" "http" {
  count                         = local.alb ? 1 : 0
  listener_arn                  = aws_globalaccelerator_listener.http[0].id
  health_check_protocol         = "TCP"
  health_check_port             = 80
  health_check_interval_seconds = 30

  endpoint_configuration {
    endpoint_id                    = aws_lb.alb[0].arn
    weight                         = 100
    client_ip_preservation_enabled = true
  }
}

resource "aws_globalaccelerator_endpoint_group" "https" {
  count                         = local.alb ? 1 : 0
  listener_arn                  = aws_globalaccelerator_listener.https[0].id
  health_check_protocol         = "TCP"
  health_check_port             = 443
  health_check_interval_seconds = 30

  endpoint_configuration {
    endpoint_id                    = aws_lb.alb[0].arn
    weight                         = 100
    client_ip_preservation_enabled = true
  }
}
