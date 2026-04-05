data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.eks_version}-v*"]
  }
}

locals {
  node_local_dns_ip = var.node_local_dns_ip
  parameter_store_secret_names = [
    "/urecsys/infra/grafana_admin_password",
    "/urecsys/infra/db",
  ]

  mng_list = flatten([
    for name, settings in var.eks_mng_settings : [
      for index, az in tobool(settings.per_az) ? range(1, tonumber(settings.az_qty) + 1) : [1] : {
        key = tobool(settings.per_az) ? "${name}-az${az}" : name
        value = {
          name          = tobool(settings.per_az) ? "mng-eks-${var.env}-${name}-az${az}" : "mng-eks-${var.env}-${name}"
          subnet_ids    = tobool(settings.per_az) ? [var.subnet_ids[index]] : try(slice(var.subnet_ids, 0, tonumber(settings.az_qty)), [])
          capacity_type = settings.capacity_type
          labels = {
            environment   = var.env
            capacity_type = lower(settings.capacity_type)
          }
          min_size     = tonumber(settings.min_size)
          max_size     = tonumber(settings.max_size)
          desired_size = tonumber(settings.desired_size)
          update_config = {
            max_unavailable = tonumber(settings.max_unavailable)
          }

          launch_template_name = tobool(settings.per_az) ? "lt-${var.env}-eks-${name}-az${az}" : "lt-${var.env}-eks-${name}"
          launch_template_tags = merge(var.common_tags, {
            Name = tobool(settings.per_az) ? "i-${var.env}-eks-${name}-az${az}" : "i-${var.env}-eks-${name}"
          })
          iam_role_name              = tobool(settings.per_az) ? "role-${var.env}-eks-mng-${name}-az${az}" : "role-${var.env}-eks-mng-${name}"
          ami_type                   = tobool(settings.use_ami_id) ? null : settings.ami_type
          ami_id                     = tobool(settings.use_ami_id) ? data.aws_ami.eks_default.image_id : null
          enable_bootstrap_user_data = tobool(settings.use_ami_id)
          instance_types             = settings.instance_types
          block_device_mappings = {
            xvda = {
              device_name = "/dev/xvda"
              ebs = {
                volume_size           = tonumber(settings.volume_size)
                iops                  = tonumber(settings.iops)
                volume_type           = "gp3"
                encrypted             = true
                delete_on_termination = true
              }
            }
          }
        }
      }
    ]
  ])

  mng = { for v in local.mng_list : v.key => v.value }
}
