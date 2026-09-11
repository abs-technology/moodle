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

    MOODLE_USERNAME=${var.moodle_admin_user}
    MOODLE_PASSWORD=${var.moodle_admin_password}
    MOODLE_EMAIL=${var.acme_email}
    MOODLE_SITE_NAME=${var.moodle_site_name}

    MARIADB_ROOT_PASSWORD=${var.mariadb_root_password}
    MARIADB_USER=abs_moodle_user
    MARIADB_PASSWORD=${var.mariadb_password}
    MARIADB_DATABASE=abs_moodle_db
  EOT

  readme = <<-EOT
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
}
