output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint da API do cluster."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group primário do cluster — é o SG efetivo dos nós."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "vpc_id" {
  description = "ID da VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Subnets públicas."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Subnets privadas."
  value       = aws_subnet.private[*].id
}

output "ecr_repository_url" {
  description = "URL do repositório ECR para docker tag/push."
  value       = aws_ecr_repository.app.repository_url
}

output "kubeconfig_command" {
  description = "Comando para configurar o kubectl."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.main.name}"
}

output "node_placement" {
  description = "Onde os nós rodam — confirma o efeito de enable_nat_gateway."
  value       = var.enable_nat_gateway ? "subnets privadas (com NAT)" : "subnets publicas (modo economico, sem NAT)"
}
