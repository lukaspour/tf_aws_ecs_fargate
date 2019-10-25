# A Terraform module to create a Fargate cluster

A terraform module providing a Fargate cluster in AWS.

This module:

- Creates a load balancer
- Populate it with listeners
- Creates target groups
- Creates services with tasks at Fargate cluster

## Usage

```hcl
module "fargate" {
  source = "../"

  name_prefix = "fargate-test-cluster"
  vpc_id      = data.aws_vpc.main.id
  subnet_ids  = data.aws_subnet_ids.main.ids

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

    }
  }
  tags = {
    environment = "dev"
  }
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
