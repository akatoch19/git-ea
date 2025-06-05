module "vpc-gitea" {
  source  = "terraform-aws-modules/vpc/aws"
  name    = "gitea-vpc"
  cidr    = "20.0.0.0/16"
  azs     = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["20.0.1.0/24", "20.0.2.0/24"]
  private_subnets = ["20.0.3.0/24", "20.0.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}
