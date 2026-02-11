output "cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}

output "node_role_arn" {
  value = aws_iam_role.eks_node_role.arn
}

output "fargate_pod_execution_role_arn" {
  description = "ARN of the Fargate Pod Execution Role"
  value       = aws_iam_role.fargate_pod_execution_role.arn
}
