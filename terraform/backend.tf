
# Terraform S3 Backend Configuration
terraform {
  backend "s3" {
    bucket         = "personio-aws-infra-statebucket"  
    key            = "terraform/state/terraform.tfstate"
    region         = "ap-south-1"            
    encrypt        = true
    acl            = "bucket-owner-full-control"
  }
}