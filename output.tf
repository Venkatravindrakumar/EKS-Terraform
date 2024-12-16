output "cluster_id" {
  value = aws_eks_cluster.Primary.id
}

output "node_group_id" {
  value = aws_eks_node_group.Primary.id
}

output "vpc_id" {
  value = aws_vpc.Primary_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.Primary_subnet[*].id
}

