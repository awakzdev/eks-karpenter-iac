data "kubectl_file_documents" "nodelocaldns" {
  content = templatefile("${path.module}/resources/manifests/nodelocaldns.yaml.tftpl", {
    cluster_dns_domain     = "cluster.local"
    cluster_dns_service_ip = var.cluster_dns_service_ip
    local_dns_ip           = local.node_local_dns_ip
  })
}

resource "kubectl_manifest" "nodelocaldns" {
  for_each  = data.kubectl_file_documents.nodelocaldns.manifests
  yaml_body = each.value
  depends_on = [
    module.eks,
    module.eks_blueprints_addons,
  ]
}

resource "kubectl_manifest" "nodelocaldns_servicemonitor" {
  yaml_body = <<YAML
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: node-local-dns
  namespace: kube-system
spec:
  endpoints:
  - interval: 30s
    path: /metrics
    port: metrics
    relabelings:
    - action: replace
      replacement: node-local-dns
      targetLabel: source
    scheme: http
  selector:
    matchLabels:
      k8s-app: node-local-dns
  namespaceSelector:
    matchNames:
    - kube-system
YAML
  depends_on = [
    module.eks,
    module.eks_blueprints_addons,
    kubectl_manifest.nodelocaldns,
  ]
}
