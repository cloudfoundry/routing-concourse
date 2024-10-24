# GCP provider configuration
variable "project_id" {
  type        = string
  description = "id of the project"
  default     = "app-runtime-platform-wg"
}

variable "zone" {
  type        = string
  description = "zone where to deploy concouse vm"
  default     = "europe-west3-a"
}

variable "region" {
  type        = string
  description = "region where to deploy concouse vm"
  default     = "europe-west3"
}

# DNS configuration
variable "dns_zone" {
  type        = string
  description = "zone for concourse hostname"
  default     = "arp-cloudfoundry-org"
}

variable "dns_zone_fqdn" {
  type        = string
  description = "FQDN of arp subdomain"
  default     = "arp.cloudfoundry.org"
}

variable "hostname" {
  type        = string
  description = "hostname in FQDN"
  default     = "concourse"
}

# VM parameters
variable "disk_size" {
  description = "size in GB for concourse volume"
  default     = 600
}

variable "data_disk" {
  description = "Additional disk to hold data"
  default     = "sdb"
}

variable "vmsize" {
  description = "VM type to be used for concourse"
  default     = "e2-standard-4"
}

# Provision options
variable "os_ver" {
  description = "Deployment image and version"
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "docker_ver" {
  description = "Docker version"
  default     = "5:27.2.0-1~ubuntu.22.04~jammy"
}

# Ops options
variable "force_new_cert" {
  description = "Deletes all previous and existing certs and obtains new one. Letsencrypt limit is 5 new certs per week."
  type        = bool
  default     = "false"
}

# Sensitive credentials - need input only on change, otherwise last value re-used
variable "GITHUB_CLIENT_ID" {
  description = "Github client ID from oAuth application config in git to allow concourse use git as auth"
  type        = string
  sensitive   = true
  default     = ""
}

variable "GITHUB_CLIENT_SECRET" {
  description = "Github client secret from oAuth application config in git to allow concourse use git as auth"
  type        = string
  sensitive   = true
  default     = ""
}
