region = "us-east-1"

name_prefix = "nonprod"
vpc_id       = "vpc-0e98d37ab3160b45f"
vpc_cidr     = "172.30.0.0/16"
azs          = ["us-east-1a", "us-east-1b"]

public_subnet_cidrs  = ["172.30.3.0/24"]
private_subnet_cidrs = ["172.30.11.0/24", "172.30.12.0/24"]

existing_public_subnet_id = "subnet-00d072cc353c72898"
existing_igw_id          = "igw-08e3968f4a400eb1f"

tags = {
  env     = "nonprod"
  project = "cloud-native-devops-platform"
}

cluster_name    = "nonprod-eks"
cluster_version = "1.35" 

endpoint_public_access  = true
endpoint_private_access = false

enabled_cluster_log_types = ["api", "audit", "authenticator"]
log_retention_in_days     = 7

node_desired   = 2
node_min       = 1
node_max       = 3
instance_types = ["t3.medium"]
capacity_type  = "ON_DEMAND"

attach_ssm = true

enable_api_gateway = true
enable_cognito     = true

api_integration_uri = "arn:aws:elasticloadbalancing:us-east-1:430118836758:listener/net/a2d778a7ab3da41f68ba9bb9ae5bd06d/0b9d2951ad584bc0/885063b1b28a33ed"

hosted_zone_id = "Z05131842BXT9H3SPUW3F"