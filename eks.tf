# O AWS Academy bloqueia iam:CreateRole: nenhum role é criado neste repo, todos vêm por data source.
# O EKS não usa a LabRole — usa roles próprios, cujos nomes o lab gera com sufixo (ver variables.tf).
data "aws_iam_role" "eks_cluster" {
  name = var.cluster_role_name
}

data "aws_iam_role" "eks_node" {
  name = var.node_role_name
}

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = data.aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.cluster_public_access_cidrs
  }

  access_config {
    # API_AND_CONFIG_MAP mantém o aws-auth como caminho de join dos nós.
    authentication_mode = "API_AND_CONFIG_MAP"

    # Dá admin no cluster a quem roda o apply. É CREATE-ONLY: mudar depois recria o cluster inteiro.
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Sem enabled_cluster_log_types: log de control plane vai para o CloudWatch e custa.

  tags = { Name = local.cluster_name }
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project}-ng"
  node_role_arn   = data.aws_iam_role.eks_node.arn

  # subnet_ids é force-replacement: alternar enable_nat_gateway recria o node group (~10 min).
  subnet_ids = local.node_subnet_ids

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = var.node_instance_types
  disk_size      = var.node_disk_size

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = { Name = "${var.project}-ng" }
}

# vpc-cni e kube-proxy são pré-requisito para o nó ficar Ready, então NÃO podem depender do node
# group. coredns e metrics-server precisam de nó para agendar, e por isso dependem.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.default]
}

# Sem metrics-server o HPA do Bloco 4 fica <unknown> e nunca escala.
resource "aws_eks_addon" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "metrics-server"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.default]
}
