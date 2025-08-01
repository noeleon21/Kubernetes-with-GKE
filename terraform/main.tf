terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.45.0"
    }
  }

  backend "gcs" {
    bucket = "tf-state-prod-noel"
    prefix = "terraform/state"
  }
}

provider "google" {
  project                     = "calm-library-462811-g0"
  region                      = "us-central1"
  impersonate_service_account = "terraform-deployer@calm-library-462811-g0.iam.gserviceaccount.com"
}

# Service Account used by GKE node pool
resource "google_service_account" "default" {
  account_id   = "service"
  display_name = "Service Account for GKE Nodes"
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name                    = "my-gke-cluster"
  location                = "us-central1"
  remove_default_node_pool = true
  initial_node_count      = 1
  deletion_protection     = false
}

# Node Pool with preemptible nodes
resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "my-node-pool"
  location   = "us-central1"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"
    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# IAM role bindings for node service account
resource "google_project_iam_member" "gke_node_sa_logging" {
  project = "calm-library-462811-g0"
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "gke_node_sa_monitoring" {
  project = "calm-library-462811-g0"
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "gke_node_sa_container" {
  project = "calm-library-462811-g0"
  role    = "roles/container.nodeServiceAccount"
  member  = "serviceAccount:${google_service_account.default.email}"
}

# Workload Identity Pool
resource "google_iam_workload_identity_pool" "pool" {
  workload_identity_pool_id = "example-pool"
  display_name              = "GitHub Actions Identity Pool"
  description               = "OIDC pool for GitHub Actions"
}

# Workload Identity Provider
resource "google_iam_workload_identity_pool_provider" "example" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "example-prvdr"
  display_name                       = "GitHub Provider"
  description                        = "GitHub Actions identity pool provider"
  disabled                           = false

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.aud"        = "assertion.aud"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository_owner_id == '125841793' && attribute.repository == 'noeleon21/Kubernetes-with-GKE' && assertion.ref == 'refs/heads/main' && assertion.ref_type == 'branch'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Service account to be impersonated from GitHub Actions
resource "google_service_account" "terraform" {
  account_id   = "terraform-deployer"
  display_name = "Terraform Deployment Service Account"
}

# Bind the GitHub identity to the Terraform deployer SA using Workload Identity
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.pool.name}/attribute.repository/noeleon21/Kubernetes-with-GKE"
}
