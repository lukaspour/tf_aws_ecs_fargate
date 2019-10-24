resource "aws_ecs_cluster" "cluster" {
  name = "${var.name_prefix}-cluster"
}

module "fargate_alb" {
  source  = "telia-oss/loadbalancer/aws"
  version = "3.0.0"

  name_prefix = var.name_prefix
  type        = "application"
  internal    = var.internal_elb
  vpc_id      = var.vpc_id
  subnet_ids  = var.subnet_ids

  tags = var.tags
}


module "ecs-fargate" {
  source = "./fargate/"

  cluster_id             = aws_ecs_cluster.cluster.id
  containers_definitions = var.containers_definitions

  lb_arn             = module.fargate_alb.arn
  vpc_id             = var.vpc_id
  private_subnet_ids = var.subnet_ids
}

