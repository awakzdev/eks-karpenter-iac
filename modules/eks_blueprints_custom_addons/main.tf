locals {
  loki_namespace            = try(var.loki.namespace, "loki")
  loki_service_account_name = "loki"
  loki_chart_version        = try(var.loki.chart_version, null)
  loki_values               = try(var.loki.values, [])
  promtail_namespace        = try(var.promtail.namespace, local.loki_namespace)
  promtail_service_account  = "promtail"
  promtail_chart_version    = try(var.promtail.chart_version, null)
  promtail_values           = try(var.promtail.values, [])
}

data "aws_iam_policy_document" "loki_s3" {
  count = var.enable_loki ? 1 : 0

  statement {
    sid = "ListLokiBuckets"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = var.loki_s3_bucket_arns
  }

  statement {
    sid = "ReadWriteLokiObjects"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]
    resources = [for arn in var.loki_s3_bucket_arns : "${arn}/*"]
  }
}

resource "aws_iam_policy" "loki" {
  count       = var.enable_loki ? 1 : 0
  name_prefix = "policy-${var.cluster_name}-loki-"
  policy      = data.aws_iam_policy_document.loki_s3[0].json
}

module "loki_irsa_role" {
  count   = var.enable_loki ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "role-${var.cluster_name}-loki-irsa"

  role_policy_arns = {
    s3 = aws_iam_policy.loki[0].arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${local.loki_namespace}:${local.loki_service_account_name}"]
    }
  }
}

resource "helm_release" "loki" {
  count = var.enable_loki ? 1 : 0

  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = local.loki_chart_version
  namespace        = local.loki_namespace
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  max_history      = 5
  timeout          = 600

  values = concat(local.loki_values, [
    yamlencode({
      serviceAccount = {
        create = true
        name   = local.loki_service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = module.loki_irsa_role[0].iam_role_arn
        }
      }
    })
  ])

  depends_on = [module.loki_irsa_role]
}

resource "helm_release" "promtail" {
  count = var.enable_promtail ? 1 : 0

  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  version          = local.promtail_chart_version
  namespace        = local.promtail_namespace
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  max_history      = 5
  timeout          = 600

  values = concat(local.promtail_values, [
    yamlencode({
      serviceAccount = {
        create = true
        name   = local.promtail_service_account
      }
    })
  ])

  depends_on = [helm_release.loki]
}
