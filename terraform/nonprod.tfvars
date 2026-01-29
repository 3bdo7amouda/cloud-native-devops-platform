region = "us-east-1"

name_prefix = "nonprod"

vpc_cidr = "10.10.0.0/16"

azs = ["us-east-1a"]

public_subnet_cidrs  = ["10.10.1.0/24"]
private_subnet_cidrs = ["10.10.11.0/24"]

tags = {
  env     = "nonprod"
  project = "cloud-native-devops-platform"
}