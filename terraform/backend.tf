terraform {
  backend "s3" {
    bucket         = "cloud-native-devops-platform-terraform-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}