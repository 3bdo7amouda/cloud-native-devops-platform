region = "us-east-1"

name_prefix = "nonprod"

vpc_cidr = "10.10.0.0/16"

azs = ["us-east-1a", "us-east-1b"]

public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]

tags = {
  env     = "nonprod"
  project = "cloud-native-devops-platform"
}

cluster_name    = "nonprod-eks"
cluster_version = "1.30"

node_desired   = 1
node_min       = 1
node_max       = 2
instance_types = ["t3.medium"]
capacity_type  = "ON_DEMAND"