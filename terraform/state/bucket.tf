# Bucket for concourse terraform remote state
# We don't want that state in git as it contains sensitive information

resource "google_storage_bucket" "concourse-tfstate" {
  name     = "arp-concourse-state"
  location = "EU"
  project  = "app-runtime-platform-wg"

  force_destroy               = false
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}
