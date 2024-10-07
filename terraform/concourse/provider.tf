provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

terraform {
  backend "gcs" {
    bucket = "arp-concourse-state"
    prefix = "terraform/state"
  }
}
