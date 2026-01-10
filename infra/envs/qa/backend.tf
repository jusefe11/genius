terraform {
  backend "s3" {
    bucket         = "genius-terraform-state"
    key            = "qa/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}