region = "eu-east-1"

name_prefix = "nonprod"

vpc_cidr = "10.10.0.0/16"

azs = ["eu-west-1a", "eu-west-1b"]

public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]

tags = {
  env     = "nonprod"
  project = "cloud-native-devops-platform"
}