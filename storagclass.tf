resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" : "true"
    }
  }
  allow_volume_expansion = true
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    type      = "gp3"
    encrypted = "true"
    kmsKeyId  = aws_kms_key.aws-ebs-csi-driver.arn
  }

  depends_on = [
    kubernetes_annotations.gp2_annotations
  ]
}

resource "kubernetes_annotations" "gp2_annotations" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  force       = true
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  depends_on = [
    module.eks
  ]
}

