terraform {
  required_version = ">= 1.6"

  backend "local" {
    # Keep this GCP lab isolated from the copied kind state files.
    path = "terraform-gcp.tfstate"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}
