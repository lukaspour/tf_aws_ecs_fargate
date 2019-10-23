

module "ecs-fargate" {
  source  = "telia-oss/ecs-fargate/aws"
  version = "3.2.0"



  cluster_id = ""
  health_check = ""
  lb_arn = ""
  name_prefix = ""
  private_subnet_ids = ""
  task_container_image = ""
  task_container_port = ""
  vpc_id = ""
}

