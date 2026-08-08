# Contrato entre os 4 repositórios (F8): cada repo publica o que cria e lê o resto via
# data "aws_ssm_parameter". Nada de ARN/endpoint hardcodado entre repos.

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/fase3/vpc/id"
  type  = "String"
  value = aws_vpc.main.id
}

resource "aws_ssm_parameter" "vpc_cidr" {
  name  = "/fase3/vpc/cidr"
  type  = "String"
  value = aws_vpc.main.cidr_block
}

resource "aws_ssm_parameter" "private_subnets" {
  name  = "/fase3/vpc/private-subnets"
  type  = "StringList"
  value = join(",", aws_subnet.private[*].id)
}

resource "aws_ssm_parameter" "public_subnets" {
  name  = "/fase3/vpc/public-subnets"
  type  = "StringList"
  value = join(",", aws_subnet.public[*].id)
}

resource "aws_ssm_parameter" "cluster_name" {
  name  = "/fase3/eks/cluster-name"
  type  = "String"
  value = aws_eks_cluster.main.name
}

resource "aws_ssm_parameter" "cluster_endpoint" {
  name  = "/fase3/eks/cluster-endpoint"
  type  = "String"
  value = aws_eks_cluster.main.endpoint
}

# Tem que ser o cluster_security_group_id: node group gerenciado sem launch template não tem SG
# próprio, os nós herdam este. Publicar outro valor faz o RDS do Bloco 3 recusar conexão dos pods.
resource "aws_ssm_parameter" "node_sg_id" {
  name  = "/fase3/eks/node-sg-id"
  type  = "String"
  value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

resource "aws_ssm_parameter" "ecr_repo_url" {
  name  = "/fase3/ecr/repo-url"
  type  = "String"
  value = aws_ecr_repository.app.repository_url
}
