terraform {
  backend "s3" {
    bucket       = "solidarytech-tfstate-<AWS_ACCOUNT_ID>"
    key          = "solidarytech/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
