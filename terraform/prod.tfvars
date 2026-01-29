region = "us-east-1"

name_prefix = "prod"

vpc_cidr = "10.20.0.0/16"

azs = ["us-east-1a", "us-east-1b"]

public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]

tags = {
  env     = "prod"
  project = "cloud-native-devops-platform"
}