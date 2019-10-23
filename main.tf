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
  source  = "./fargate/"

  cluster_id = aws_ecs_cluster.cluster

  health_check = ""
  name_prefix = ""
  task_container_image = ""
  task_container_port = ""

  lb_arn = module.fargate_alb.arn
  vpc_id = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
}

