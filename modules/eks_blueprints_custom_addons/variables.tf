variable "cluster_name" {
  type        = string
  description = "EKS cluster name used in addon role naming."
}

variable "cluster_endpoint" {
  type        = string
  description = "Cluster API endpoint passed through for compatibility with the root module."
}

variable "cluster_version" {
  type        = string
  description = "Cluster Kubernetes version passed through for compatibility with the root module."
}

variable "oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN used to create IRSA roles for custom addons."
}

variable "enable_loki" {
  type        = bool
  default     = false
  description = "Whether to deploy Loki."
}

variable "loki" {
  type        = any
  default     = {}
  description = "Loki Helm release settings including chart version, namespace, and rendered values."
}

variable "loki_s3_bucket_arns" {
  type        = list(string)
  default     = []
  description = "S3 bucket ARNs granted to the Loki IRSA role."
}

variable "enable_promtail" {
  type        = bool
  default     = false
  description = "Whether to deploy Promtail."
}

variable "promtail" {
  type        = any
  default     = {}
  description = "Promtail Helm release settings including chart version, namespace, and rendered values."
}
