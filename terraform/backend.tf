
# Terraform S3 Backend Configuration
terraform {
  backend "s3" {
    bucket         = "personio-aws-infra-statebucket"  # Replace with your actual S3 bucket name
    key            = "terraform/state/terraform.tfstate"
    region         = "ap-south-1"            # Replace with your AWS region
    encrypt        = true
    acl            = "bucket-owner-full-control"
  }
}