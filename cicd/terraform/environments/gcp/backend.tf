# Remote State Backend (Google Cloud Storage)
# GCS provides built-in state locking automatically at no extra service fee.
#
# To activate remote state:
# 1. Create the state bucket once (with versioning enabled for safety):
#    gcloud storage buckets create gs://company-bot11-tfstate --project=company-bot11 --location=asia-south1 --uniform-bucket-level-access
#    gcloud storage buckets update gs://company-bot11-tfstate --versioning
# 2. Uncomment the block below and run:
#    terraform init -migrate-state
#
# terraform {
#   backend "gcs" {
#     bucket = "company-bot11-tfstate"
#     prefix = "terraform/state/gcp"
#   }
# }

