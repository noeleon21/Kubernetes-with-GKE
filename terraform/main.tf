terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.45.0"
    }
    
  }
    backend "gcs" {
    bucket  = "tf-state-prod-noel"
    prefix  = "terraform/state"

  }
}


provider "google" {
  # Configuration options
  region = "us-central1"
 }

resource "google_service_account" "default" {
  account_id   = "service"
  display_name = "Service Account"
}

resource "google_container_cluster" "primary" {
  name     = "my-gke-cluster"
  location = "us-central1"

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection = false
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "my-node-pool"
  location   = "us-central1"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}