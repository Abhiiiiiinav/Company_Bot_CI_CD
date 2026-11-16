# Remote State Backend (Amazon S3)
# Terraform >= 1.10 supports native S3 state locking (use_lockfile = true)
# without needing a separate DynamoDB table.
#
# To activate remote state:
# 1. Create an encrypted, versioned S3 bucket once:
#    aws s3api create-bucket --bucket company-bot-tfstate --region ap-south-1 --create-bucket-configuration LocationConstraint=ap-south-1
#    aws s3api put-bucket-versioning --bucket company-bot-tfstate --versioning-configuration Status=Enabled
# 2. Uncomment the block below and run:
#    terraform init -migrate-state
#
# terraform {
#   backend "s3" {
#     bucket       = "company-bot-tfstate"
#     key          = "terraform/state/aws/terraform.tfstate"
#     region       = "ap-south-1"
#     encrypt      = true
#     use_lockfile = true
#   }
# }

