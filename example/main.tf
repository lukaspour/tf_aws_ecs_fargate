provider "aws" {
  region = "eu-west-3"
}

data "aws_vpc" "main" {
  default = true
}

data "aws_subnet_ids" "main" {
  vpc_id = data.aws_vpc.main.id
}


module "fargate" {
  source = "../"

  name_prefix = "fargate-test-cluster"
  vpc_id      = data.aws_vpc.main.id
  subnet_ids  = data.aws_subnet_ids.main.ids

  internal_elb = false

  containers_definitions = {
    helloworld = {
      task_container_image            = "crccheck/hello-world:latest"
      task_container_assign_public_ip = true
      task_container_port             = 8000
      task_container_environment = [
        {
          name  = "TEST_VARIABLE"
          value = "TEST_VALUE"
        }
      ]
      health_check = {
        port = "traffic-port"
        path = "/"
      }
      task_tags = {
        terraform = "True"
      }
    }
    hellonginx = {
      task_container_image            = "nginx:latest"
      task_container_assign_public_ip = true
      task_container_port             = 80
      task_container_environment = [
        {
          name  = "TEST_VARIABLE"
          value = "TEST_VALUE"
        }
      ]
      health_check = {
        port = "traffic-port"
        path = "/"
      }
      task_tags = {
        terraform = "True"
      }
      scaling_enable = true
    }
  }
  tags = {
    environment = "dev"
  }
}

output "load_balancer_domain" {
  description = "Get DNS record of load balancer"
  value       = module.fargate.load_balancer_domain
}