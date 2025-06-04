variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "runner_instance_type" {
  description = "Runner EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "instance_name" {
  description = "EC2 instance name"
  type        = string
  default     = "gitea"
}

variable "image" {
  description = "Gitea docker image"
  type        = string
  default     = "public.ecr.aws/cloudacademy-labs/cloudacademy/labs/gitea:1.22.1-57a63cf"
}

variable "username" {
  description = "Gitea username"
  type        = string
  default     = "student"
}

variable "password" {
  description = "Gitea password"
  type        = string
  default     = "LabPassword123"
}

variable "email" {
  description = "Gitea email"
  type        = string
  default     = "student@platform.qa.com"
}

variable "create_empty_repo" {
  description = "Create an empty repository"
  type        = bool
  default     = false
}

variable "empty_repo_name" {
  description = "Gitea repository name"
  type        = string
  default     = "lab-repo"
}

variable "empty_repo_description" {
  description = "Gitea repository description"
  type        = string
  default     = "Lab Repository"
}

variable "external_port" {
  description = "Gitea external port"
  type        = number
  default     = 3000
}

variable "ssh_port" {
  description = "Gitea SSH port"
  type        = number
  default     = 222
}

variable "jwt_secret" {
  description = "JWT secret"
  type        = string
  default     = "kU9i_JAtfZ0z9yqnBks3ZQfjT0GAjU81zQz1sH6lraQ"
}

variable "key_pair_name" {
  description = "Key pair name"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "volume_size" {
  description = "Root volume size"
  type        = number
  default     = 50
}

variable "create_cloned_repo" {
  description = "Create a cloned repository"
  type        = bool
  default     = false
}

variable "cloned_repo_source" {
  description = "Command to clone the repository"
  type        = string
  default     = "https://github.com/cloudacademy/python-flask-microservices.git"
}

variable "docker_version" {
  description = "Docker version in the DNF repository"
  type        = string
  default     = "docker-25.0.6-1.amzn2023.0.1.x86_64"
}

variable "runner_binary_url" {
  description = "URL to download the runner binary"
  type        = string
  default     = "https://assets.labs.platform.qa.com/terraform-module-aws-gitea/act_runner-0.2.10-linux-amd64"
}

variable "runner_image" {
  description = "Docker image used by the gitea runner when running jobs"
  type        = string
  default     = "public.ecr.aws/cloudacademy-labs/cloudacademy/labs/gitea-runner-ubuntu"
}

variable "gitea_role_managed_policies" {
  description = "List of ARNs of managed policies to attach to the Gitea role"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

variable "create_secret" {
  description = "Create a secret"
  type        = bool
  default     = false
}

variable "secret_name" {
  description = "Secret name"
  type        = string
  default     = "GITEACREDS"
}

variable "secret_value" {
  description = "Secret value"
  type        = string
  default     = "student:LabPassword123"
}

variable "create_runner" {
  description = "Create a runner"
  type        = bool
  default     = false
}
