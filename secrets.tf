data "aws_region" "current" {}

locals {
  namespace                    = "external-secrets"
  cluster_secretstore_name     = "cluster-secretstore-sm"
  cluster_secretstore_sa       = "cluster-secretstore-sa"
  cluster_secretstore_ssm_name = "cluster-secretstore-ssm-sm"
}

data "aws_iam_policy_document" "cluster_secretstore" {
  statement {
    sid    = "ReadManagedParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParameterHistory",
    ]
    resources = [
      for name in local.parameter_store_secret_names :
      "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${name}"
    ]
  }

  dynamic "statement" {
    for_each = length(var.external_secrets_secret_arns) == 0 ? [] : [var.external_secrets_secret_arns]
    content {
      sid    = "ReadExplicitSecretsManagerSecrets"
      effect = "Allow"
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecretVersionIds",
      ]
      resources = statement.value
    }
  }

  dynamic "statement" {
    for_each = length(var.external_secrets_kms_key_arns) == 0 ? [] : [var.external_secrets_kms_key_arns]
    content {
      sid       = "DecryptExplicitKmsKeys"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = statement.value
    }
  }
}

module "cluster_secretstore_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "role-${var.env}-external-secret-sm-irsa"

  role_policy_arns = {
    policy = aws_iam_policy.cluster_secretstore.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.namespace}:${local.cluster_secretstore_sa}"]
    }
  }

}

resource "aws_iam_policy" "cluster_secretstore" {
  name_prefix = "policy-${var.env}-external-secret-sm-irsa"
  policy      = data.aws_iam_policy_document.cluster_secretstore.json
}


resource "kubectl_manifest" "cluster_secretstore_sa" {
  yaml_body  = <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: ${module.cluster_secretstore_role.iam_role_arn}
  name: ${local.cluster_secretstore_sa}
  namespace: ${local.namespace}
YAML
  depends_on = [module.eks_blueprints_addons]
}




resource "kubectl_manifest" "cluster_secretstore" {
  yaml_body  = <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: ${local.cluster_secretstore_name}
spec:
  provider:
    aws:
      service: SecretsManager
      region: ${data.aws_region.current.name}
      auth:
        jwt:
          serviceAccountRef:
            name: ${local.cluster_secretstore_sa}
            namespace: ${local.namespace}
YAML
  depends_on = [module.eks_blueprints_addons]
}


resource "kubectl_manifest" "cluster_secretstore_parameters" {
  yaml_body  = <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: ${local.cluster_secretstore_ssm_name}
spec:
  provider:
    aws:
      service: ParameterStore
      region: ${data.aws_region.current.name}
      auth:
        jwt:
          serviceAccountRef:
            name: ${local.cluster_secretstore_sa}
            namespace: ${local.namespace}
YAML
  depends_on = [module.eks_blueprints_addons]
}

resource "kubectl_manifest" "db_secret" {
  yaml_body  = <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-secret
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: ${local.cluster_secretstore_ssm_name}
    kind: ClusterSecretStore
  dataFrom:
  - extract:
      key: /urecsys/infra/db
YAML
  depends_on = [kubectl_manifest.cluster_secretstore_parameters]
}


