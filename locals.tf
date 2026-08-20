locals {
  cluster_name = "${var.project}-eks"

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
    Repo      = "fiap-fase3-infra-k8s"
  }

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Sem NAT as subnets privadas não têm rota de saída e o nó nunca completa o registro no control
  # plane — por isso o modo econômico move os nós para as públicas.
  node_subnet_ids = var.enable_nat_gateway ? aws_subnet.private[*].id : aws_subnet.public[*].id
}
