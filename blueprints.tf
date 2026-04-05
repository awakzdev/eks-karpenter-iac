data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.us-east-1
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.12.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  create_delay_dependencies = [for prof in module.eks.eks_managed_node_groups : prof.node_group_arn]

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      service_account_role_arn = module.vpc_cni_ipv4_irsa_role.iam_role_arn
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = 1
        }
      })
    }
    kube-proxy = {
      most_recent = true
    }
  }

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    chart_version = "1.5.4"
  }

  enable_metrics_server = true
  metrics_server = {
    chart_version = "3.10.0"
  }

  enable_karpenter = true
  karpenter = {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
  }
  karpenter_enable_spot_termination          = true
  karpenter_enable_instance_profile_creation = true
  karpenter_node = {
    iam_role_use_name_prefix = false
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  enable_external_secrets = true

  enable_external_dns = true
  external_dns = {
    chart_version = "1.13.0"
  }
  external_dns_route53_zone_arns = ["arn:aws:route53:::hostedzone/${var.zone_id}"]
  enable_kube_prometheus_stack   = true
  kube_prometheus_stack = {
    chart_version = "47.0.1"
    values = [
      templatefile("${path.module}/resources/values/kube_prometheus_stack.yaml", {
        acm_arn                = var.acm_certificate_arn
        grafana_host           = "grafana.${var.domain_name}"
        prometheus_host        = "prometheus.${var.domain_name}"
        grafana_admin_password = random_password.grafana_admin_password.result
        env                    = var.env
      })
    ]
  }

}

resource "random_password" "grafana_admin_password" {
  length = 32
}

resource "aws_ssm_parameter" "parameter_store_secrets" {
  for_each = {
    "/urecsys/infra/grafana_admin_password" : random_password.grafana_admin_password.result
    "/urecsys/infra/db" : jsonencode({
      username = var.secrets.db.user,
      password = var.secrets.db.password
    })
  }

  name  = each.key
  type  = "SecureString"
  value = each.value
  tags  = var.common_tags
}

locals {
  logging_namespace = "loki"
}
module "eks_blueprints_custom_addons" {
  source = "./modules/eks_blueprints_custom_addons"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_loki = true
  loki = {
    chart_version = "5.36.0"
    namespace     = local.logging_namespace
    values = [
      templatefile("${path.module}/resources/values/loki.yaml", {
        aws_region                 = data.aws_region.current.name
        storage_chunks_bucket_name = var.storage_layer.s3["loki-chunks"].s3_bucket_id
        storage_ruler_bucket_name  = var.storage_layer.s3["loki-ruler"].s3_bucket_id
      })
    ]
  }
  loki_s3_bucket_arns = [
    for k, v in var.storage_layer.s3 : v.s3_bucket_arn
    if contains(["loki-chunks", "loki-ruler", ], k)
  ]

  enable_promtail = true
  promtail = {
    chart_version = "6.15.3"
    namespace     = local.logging_namespace
    values = [
      templatefile("${path.module}/resources/values/promtail.yaml", {
        loki_namespace = local.logging_namespace
      })
    ]
  }

  depends_on = [module.eks_blueprints_addons]
}

resource "kubectl_manifest" "vpc_cni_podmonitor" {
  yaml_body = <<YAML
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: aws-cni-metrics
  namespace: kube-system
  labels:
    prometheus: "true"
    release: kube-prometheus-stack
spec:
  jobLabel: k8s-app
  namespaceSelector:
    matchNames:
    - kube-system
  podMetricsEndpoints:
  - interval: 30s
    path: /metrics
    port: metrics
  selector:
    matchLabels:
      k8s-app: aws-node
YAML
  depends_on = [
    module.eks,
    module.eks_blueprints_addons,
    kubectl_manifest.nodelocaldns,
  ]
}
