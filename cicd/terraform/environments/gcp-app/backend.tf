# Remote State Backend (Google Cloud Storage)
# Critical for Jenkins: ensures Jenkins builds share and persist state across workspace wipes.
#
# To activate:
# 1. Ensure the state bucket exists in GCP:
#    gcloud storage buckets create gs://company-bot11-tfstate --project=company-bot11 --location=asia-south1 --uniform-bucket-level-access
#    gcloud storage buckets update gs://company-bot11-tfstate --versioning
# 2. Uncomment the block below and run:
#    terraform init -migrate-state
#
# terraform {
#   backend "gcs" {
#     bucket = "company-bot11-tfstate"
#     prefix = "terraform/state/gcp-app"
#   }
# }
