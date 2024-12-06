resource "google_compute_network" "vpc_network" {
  name                    = "concourse-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "default" {
  name          = "concourse"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_address" "concourse" {
  name         = "static-concourse-ip"
  address_type = "EXTERNAL"
}

resource "google_dns_record_set" "concourse" {
  name         = "${var.hostname}.${var.dns_zone_fqdn}."
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_zone
  rrdatas      = [google_compute_address.concourse.address]
}

resource "google_compute_disk" "concourse_volume" {
  name = var.data_disk
  type = var.disk_type
  size = var.disk_size
  zone = var.zone
}

resource "google_compute_firewall" "ssh" {
  name = "allow-ssh"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpc_network.id
  priority      = 1
  source_ranges = ["35.235.240.0/20"] # Only access via google IAP gateway
}

resource "google_compute_firewall" "http" {
  name = "allow-http"
  allow {
    ports    = ["80"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpc_network.id
  priority      = 0
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "https" {
  name = "allow-https"
  allow {
    ports    = ["443"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpc_network.id
  priority      = 1
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "concourse" {
  name                      = var.hostname
  machine_type              = var.vm_size
  zone                      = var.zone
  allow_stopping_for_update = true

  # Metadata contains various temporary ssh keys managed by gcloud, don't interfere with that
  lifecycle {
    ignore_changes = [metadata]
  }

  boot_disk {
    initialize_params {
      image = var.os_ver
      size  = 50
    }
  }

  attached_disk {
    source      = google_compute_disk.concourse_volume.id
    device_name = google_compute_disk.concourse_volume.name
  }

  network_interface {
    subnetwork = google_compute_subnetwork.default.id

    access_config {
      nat_ip = google_compute_address.concourse.address
    }
  }
}

# Watch contents of config files so that we can trigger provision on changes
data "local_file" "nginx_conf" {
  filename = "${path.module}/../../nginx/nginx.conf.template"
}

data "local_file" "docker_compose" {
  filename = "${path.module}/../../docker-compose.yml"
}

data "local_file" "docker_versions" {
  filename = "${path.module}/../../docker-versions.sh"
}

resource "terraform_data" "provision_concourse" {
  triggers_replace = [
    google_compute_instance.concourse.id,
    local_sensitive_file.concourse_env.content,
    data.local_file.nginx_conf.id,
    data.local_file.docker_compose.id,
    data.local_file.docker_versions.id,
    sha1(join("", [for f in fileset("../../scripts/", "*") : filesha1("../../scripts/${f}")]))
    # ^^^ Trigger on any script changes
  ]

  provisioner "local-exec" {
    command = <<-CMD
      sleep 30 ; # Allow VM to boot
      gcloud compute ssh ${var.hostname} --zone ${var.zone} --tunnel-through-iap --command "\
        sudo mkdir -p /concourse/scripts/ ;\
        sudo mkdir -p /concourse/db/ ;\
        sudo mkdir -p /concourse/nginx/ ;\
        sudo chmod -R a+rwx /concourse/" --verbosity=error
     CMD
  }

  provisioner "local-exec" {
    command = <<-CMD
      gcloud compute scp --recurse ../../scripts/ ${var.hostname}:/concourse \
        --zone ${var.zone} --tunnel-through-iap --verbosity=error
     CMD
  }

  depends_on = [local_sensitive_file.concourse_env]
  provisioner "local-exec" {
    command = <<-CMD
      gcloud compute scp ../../docker-compose.yml ../../docker-versions.sh .concourse.env ${var.hostname}:/concourse \
       --zone ${var.zone} --tunnel-through-iap --verbosity=error
     CMD
  }

  provisioner "local-exec" {
    command = <<-CMD
      gcloud compute scp ../../nginx/nginx.conf.template ${var.hostname}:/concourse/nginx \
        --zone ${var.zone} --tunnel-through-iap --verbosity=error
     CMD
  }

  provisioner "local-exec" {
    command = <<-CMD
      gcloud compute ssh ${var.hostname} --zone ${var.zone} --tunnel-through-iap --command "\
      sudo /concourse/scripts/install.sh ${var.docker_ver} ${var.data_disk} ;\
      sudo /concourse/scripts/start.sh ${var.hostname}.${var.dns_zone_fqdn} ${var.force_new_cert} ;\
      // cron tab runs every weekend e.g. on Sunday at midnight ;\
      ! grep -q '0 0 * * 0 /concourse/scripts/prune_workers.sh' && echo '0 0 * * 0 /concourse/scripts/prune_workers.sh' | sudo tee -a /etc/crontab" --verbosity=error
     CMD
  }
}

resource "terraform_data" "update_postgres_pw" {
  triggers_replace = [
    random_password.postgres
  ]

  depends_on = [terraform_data.provision_concourse]
  provisioner "local-exec" {
    command = <<-CMD
      gcloud compute ssh ${var.hostname} --zone ${var.zone} --tunnel-through-iap --command "\
      cd /concourse ; source docker-versions.sh ;\
      [ -f /run/systemd/shutdown/scheduled ] && exit 0 ;\
      sudo -E docker -l error compose exec db psql -U concourse_user -d concourse -c \
      \"ALTER USER concourse_user PASSWORD '${random_password.postgres.result}';\" " --verbosity=error
     CMD
  }
}
