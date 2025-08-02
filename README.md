#### Project: Kubernetes with GKE
## This project demonstrates how to deploy a Kubernetes cluster on GCP using GKE, with the infrastructure managed by Terraform, and automated via GitHub Actions.

### Key Components

## Terraform: Infrastructure as Code (IaC) to provision GKE clusters and associated resources.

## GKE (Google Kubernetes Engine): Hosts the Kubernetes workloads.

## WIF (Workload Identity Federation): Enables secure, keyless authentication from GitHub Actions to Google Cloud.

### GitHub Actions:

## Automates terraform apply and terraform destroy.

## Uses pre-approved workflows for CI/CD.