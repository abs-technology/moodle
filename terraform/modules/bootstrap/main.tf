# Renders the VM bootstrap script for both clouds from one compose file, so GCP
# and AWS cannot drift apart.
terraform {
  required_version = ">= 1.5"
}

locals {
  acme_caserver = var.acme_staging ? "ACME_CASERVER=https://acme-staging-v02.api.letsencrypt.org/directory" : ""

  env_file = <<-EOT
    MOODLE_DOMAIN=${var.moodle_domain}
    TLS_CERTRESOLVER=${var.tls_certresolver}
    ACME_EMAIL=${var.acme_email}
    ${local.acme_caserver}
    TRAEFIK_HTTP3=true

    MOODLE_USERNAME=admin
    MOODLE_PASSWORD=${var.moodle_admin_password}
    MOODLE_EMAIL=${var.acme_email}
    MOODLE_SITE_NAME=${var.moodle_site_name}

    MARIADB_ROOT_PASSWORD=${var.mariadb_root_password}
    MARIADB_USER=abs_moodle_user
    MARIADB_PASSWORD=${var.mariadb_password}
    MARIADB_DATABASE=abs_moodle_db
  EOT

  readme_traefik = <<-EOT
    # Moodle on this host

    Deployed by Terraform. There is no source tree and nothing is built here: the
    stack runs published images pulled from Docker Hub.

        docker-compose.yml   the stack
        .env                 domain and generated passwords, mode 600
        change-domain.sh     move the site to another domain and certificate
        data/                Moodle code, moodledata and backups, owned by uid 1000
        certs/               your own certificate goes here
        dynamic/             Traefik file provider
        backups/             written by change-domain.sh

        cd /opt/moodle && docker compose ps
        docker compose logs -f moodle

    ## Moving to your own domain and certificate

    The site starts on a nip.io name so it has working TLS from the first boot.
    Once you own a domain and a certificate, point its A record at this host's
    public IP, copy the pair over, and run one command:

        cd /opt/moodle
        sudo ./change-domain.sh --domain lms.example.com \
            --cert /root/fullchain.pem --key /root/privkey.pem

    Editing .env is not enough on a site that already has data. The image writes
    config.php once at install and never rewrites it, and Moodle stores absolute
    URLs across the database, so wwwroot and every stored URL have to move too.
    The script does that in the right order: it validates the certificate against
    the new name, backs up the database, config.php and moodledata, enables
    maintenance mode, rewrites wwwroot, swaps the certificate, runs Moodle's own
    admin/tool/replace over the database, purges caches and sessions, and checks
    the result. Everyone is signed out and the old name stops working.

    Staying on Let's Encrypt for the new domain instead:

        sudo ./change-domain.sh --domain lms.example.com --letsencrypt

    cert.pem must be the full chain with the leaf first, key.pem must have no
    passphrase, and the domain must appear in the certificate SAN. The script
    refuses the change otherwise.

    ## Renewing your own certificate

    Yours to do, and it does not involve the script:

        cp /path/fullchain.pem certs/cert.pem
        cp /path/privkey.pem   certs/key.pem
        docker compose restart traefik

    ## Terraform

    Changes made here are never pushed back or overwritten. The bootstrap script
    is under ignore_changes, so a VM holding live data is not replaced by an
    apply, and the domain recorded in Terraform stops being the truth once
    change-domain.sh has run.
  EOT

  readme_ip = <<-EOT
    # Moodle on this host (IP-direct)

    Deployed by Terraform. First boot is MariaDB + Moodle only — no Traefik and
    no load balancer. Open the site at http://<this-host-public-ip>.

        docker-compose.yml           Moodle on :80
        docker-compose.traefik.yml   used by change-domain.sh, do not start it
        .env                         IP and generated passwords, mode 600
        change-domain.sh             enable Traefik and move to a domain
        data/                        Moodle code, moodledata and backups

        cd /opt/moodle && docker compose ps
        docker compose logs -f moodle

    ## Move to HTTPS (on this VM)

    nip.io + Let's Encrypt, no DNS work:

        sudo ./change-domain.sh --nip

    That serves https://moodle.<public-ip>.nip.io.

    Your own name and certificate (point the A record here first):

        sudo ./change-domain.sh --domain lms.example.com \
            --cert /root/fullchain.pem --key /root/privkey.pem

    Let's Encrypt on a name you already pointed here:

        sudo ./change-domain.sh --domain lms.example.com --letsencrypt

    The script starts Traefik, rewrites wwwroot from http://IP to https://...,
    and replaces stored URLs in the database. Everyone is signed out. After
    that, http://IP stops being the site address.

    ## Terraform

    Changes made here are never pushed back or overwritten. The bootstrap script
    is under ignore_changes, so a VM holding live data is not replaced by an
    apply.
  EOT

  readme_alb = <<-EOT
    # Moodle on this host (ALB)

    Deployed by Terraform. TLS terminates on the load balancer — GCP Global ALB
    or AWS Global Accelerator + ALB. This VM has no public IP. Moodle listens
    on :8080. There is no Traefik.

        docker-compose.yml   MariaDB + Moodle :8080
        .env                 domain and generated passwords, mode 600
        data/                Moodle code, moodledata and backups

        cd /opt/moodle && docker compose ps
        docker compose logs -f moodle

    SSH from the machine that ran Terraform:

        make ssh gcp-alb <name>    # IAP
        make ssh aws-alb <name>    # Session Manager

    change-domain.sh does not apply here. The public name is set at first
    apply (moodle.<anycast-or-global-ip>.nip.io, or moodle_domain in tfvars).

    On AWS, ACM cannot issue for nip.io. A timer on this VM completes Let's
    Encrypt HTTP-01 and imports the cert into ACM (replacing the placeholder).
    First HTTPS minutes may warn in the browser; after that the name is trusted.

    ## Terraform

    Changes made here are never pushed back or overwritten. The bootstrap script
    is under ignore_changes, so a VM holding live data is not replaced by an
    apply.
  EOT

  readme = (
    var.compose_relpath == "ip/docker-compose.yml" ? local.readme_ip :
    var.compose_relpath == "alb/docker-compose.yml" ? local.readme_alb :
    local.readme_traefik
  )
}
