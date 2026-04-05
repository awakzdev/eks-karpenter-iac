variable "env" {
  type        = string
  description = "Short environment name used in resource names."
}

variable "env_type" {
  type        = string
  description = "Environment classification such as production or staging."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the EKS cluster is deployed."
}

variable "cidr" {
  type        = string
  description = "Primary VPC CIDR block allowed to reach the worker nodes."
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN attached to the observability ingresses."
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags applied to resources that support tagging."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs used by the cluster and worker nodes."
}

variable "eks_mng_settings" {
  type        = any
  description = "Managed node group settings keyed by node group name."
}

variable "security_group_instance" {
  type        = string
  description = "Security group ID of the management instance allowed to reach the cluster API."
}

variable "domain_name" {
  type        = string
  description = "Base DNS zone used for Grafana and Prometheus hostnames."
}

variable "zone_id" {
  type        = string
  description = "Route53 hosted zone ID used by ExternalDNS."
}

variable "eks_version" {
  type        = string
  default     = "1.29"
  description = "EKS control plane version."
}

variable "secrets" {
  type        = any
  description = "Secret values required to bootstrap supporting infrastructure."
}

variable "iam_role_instance" {
  type        = string
  description = "IAM role ARN assigned to the bastion or management instance."
}

variable "storage_layer" {
  type        = any
  description = "Storage layer outputs consumed by observability components."
}

variable "external_secrets_secret_arns" {
  type        = list(string)
  default     = []
  description = "Explicit Secrets Manager secret ARNs that External Secrets may read."
}

variable "external_secrets_kms_key_arns" {
  type        = list(string)
  default     = []
  description = "Explicit KMS key ARNs that External Secrets may use for decrypt operations."
}

variable "cluster_dns_service_ip" {
  type        = string
  default     = "10.100.0.10"
  description = "ClusterIP of the kube-dns service used by NodeLocalDNS."
}

variable "node_local_dns_ip" {
  type        = string
  default     = "169.254.20.25"
  description = "Link-local IP exposed by the NodeLocalDNS daemonset."
}
