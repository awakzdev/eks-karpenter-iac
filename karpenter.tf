resource "kubectl_manifest" "karpenter_default_ec2_node_class" {
  yaml_body = <<YAML
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: "${module.eks_blueprints_addons.karpenter.node_iam_role_name}"
  amiFamily: AL2 
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: "eks-${var.env}"
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: "eks-${var.env}"
  tags:
    karpenter-node-pool-name: default
    intent: apps
    karpenter.sh/discovery: "eks-${var.env}"
    Name: "i-${var.env}-eks-karpenter-default"
YAML
  depends_on = [
    module.eks,
    module.eks_blueprints_addons,
  ]
}

resource "kubectl_manifest" "karpenter_default_node_pool" {
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default 
spec:  
  limits:
    cpu: "1000"
  template:
    metadata:
      labels:
        intent: apps
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["4", "8", "16", "32"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: [ "on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
      kubelet:
        clusterDNS: ["${local.node_local_dns_ip}"]
        maxPods: 110
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 300s

YAML
  depends_on = [
    module.eks,
    module.eks_blueprints_addons,
    kubectl_manifest.karpenter_default_ec2_node_class,
  ]
}
