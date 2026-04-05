# eks-karpenter-iac

Terraform for a production-oriented EKS platform with:

- EKS managed node groups and Karpenter
- VPC CNI prefix delegation
- AWS Load Balancer Controller and ExternalDNS
- External Secrets backed by SSM and optional Secrets Manager ARNs
- kube-prometheus-stack, Loki, Promtail, and Grafana
- KMS-encrypted EBS via the EBS CSI driver
- NodeLocalDNS and observability monitors

## Repository status

This repo is self-contained again:

- Fixed the Karpenter apply failure caused by a self-reference in `depends_on`
- Fixed the NodeLocalDNS document reference
- Added the missing local `eks_blueprints_custom_addons` module
- Added the missing Helm values templates for Loki, Promtail, and kube-prometheus-stack
- Enabled EKS secrets encryption
- Scoped the External Secrets IAM policy away from `"*"` resources

## Requirements

- Terraform 1.x
- AWS credentials available through the standard AWS provider chain
- `aws` CLI available locally for Kubernetes, Helm, and kubectl auth
- Network access to Terraform Registry, AWS APIs, and the Grafana Helm repository during `terraform init` / `terraform apply`

## Key inputs

Important root variables:

- `env`: short environment name used in resource names
- `vpc_id`: target VPC ID
- `subnet_ids`: private subnet IDs for the cluster and workers
- `cidr`: primary VPC CIDR allowed to reach worker nodes
- `eks_mng_settings`: managed node group configuration map
- `acm_certificate_arn`: certificate used by Grafana and Prometheus ingresses
- `domain_name` and `zone_id`: DNS inputs used by ExternalDNS and observability ingresses
- `iam_role_instance` and `security_group_instance`: bastion or management instance access
- `storage_layer`: storage outputs, including `s3["loki-chunks"]` and `s3["loki-ruler"]`
- `secrets`: bootstrap secret object, including `secrets.db.user` and `secrets.db.password`
- `external_secrets_secret_arns`: optional explicit Secrets Manager ARNs for External Secrets
- `external_secrets_kms_key_arns`: optional explicit KMS key ARNs used by External Secrets
- `cluster_dns_service_ip`: defaults to `10.100.0.10`; override if the cluster uses a custom service CIDR
- `node_local_dns_ip`: defaults to `169.254.20.25`

Example shapes for the composite inputs:

```hcl
eks_mng_settings = {
  core = {
    per_az          = true
    az_qty          = 3
    capacity_type   = "ON_DEMAND"
    min_size        = 1
    max_size        = 3
    desired_size    = 2
    max_unavailable = 1
    use_ami_id      = false
    ami_type        = "AL2_x86_64"
    instance_types  = ["m6i.large"]
    volume_size     = 50
    iops            = 3000
  }
}

secrets = {
  db = {
    user     = "app"
    password = "replace-me"
  }
}

storage_layer = {
  s3 = {
    loki-chunks = {
      s3_bucket_id  = "my-loki-chunks"
      s3_bucket_arn = "arn:aws:s3:::my-loki-chunks"
    }
    loki-ruler = {
      s3_bucket_id  = "my-loki-ruler"
      s3_bucket_arn = "arn:aws:s3:::my-loki-ruler"
    }
  }
}
```

## Deploy

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

## Notes

- The default AWS provider uses the ambient region from your AWS profile or environment. An aliased `us-east-1` provider is configured for the ECR Public Karpenter auth token.
- The local custom addons module installs Loki and Promtail directly with Helm and uses IRSA for Loki S3 access.
- The kube-prometheus-stack values expose Grafana and Prometheus through the AWS Load Balancer Controller with ExternalDNS hostnames.
