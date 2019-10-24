provider "aws" {
  region  = "eu-west-3"
}

data "aws_vpc" "main" {
  default = true
}

data "aws_subnet_ids" "main" {
  vpc_id = data.aws_vpc.main.id
}


module "fargate" {
  source = "../"

  name_prefix = "fargate_test_cluster"
  vpc_id = data.aws_vpc.main.id
  subnet_ids = data.aws_subnet_ids.main.ids

  containers_definitions = {
    hello-world = {
      task_container_image = "crccheck/hello-world:latest"
      task_container_assign_public_ip = true
      task_container_port = 8000
      task_container_environment = [
          {
            name = "TEST_VARIABLE"
            value= "TEST_VALUE"
          }
      ]
      health_check = {
        port = "traffic-port"
        path = "/"
      }
      task_tags = {
            environment = "dev"
            terraform   = "True"
      }
    }
    hello-nginx = {
      task_container_image = "nginx:latest"
      task_container_assign_public_ip = true
      task_container_port = 80
      task_container_environment = [
          {
            name = "TEST_VARIABLE"
            value= "TEST_VALUE"
          }
      ]
      health_check = {
        port = "traffic-port"
        path = "/"
      }
      task_tags = {
            environment = "dev"
            terraform   = "True"
      }
    }
  }
}