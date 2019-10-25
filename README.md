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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| vpc_id | VPC ID | string | null | yes |
| name_prefix | Name prefix for fargate cluster | string | null | yes |
| tags | A map of tags (key-value pairs) passed to resources | map(string) | {} | no |
| internal_elb | If used, load balancer will be only for internal use | bool | false | no |
| subnet_ids | Subnet IDs used for load balancer | map(string) | [] | yes |
| certificate_arn | ARN for certificate at ACM required for HTTPS listener | string | "" | no |

## containers_definitions

This is a special map of arguments needed for definition of tasks and services:

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| tags_tags | A map of tags (key-value pairs) passed to resources | map(string) | {} | no |
| task_log_retention_in_days | Days TTL before logs are dropped from cloudwatch | number | 30 | no |
| task_container_name | Name of container, if not used, key of service is used | string | key of container_definitions | no |
| task_container_image | Name of image used for task | string | nginx | no |
| task_definition_cpu | Amount of CPU units for a task | number | 256 | no |
| task_definition_memory | Amount of memory units for a task | number | 1024 | no |
| task_container_command | Docker command of a task | list(string) | [] | no | 
| task_container_environment | Docker ENV variables of a task | list(string) | [] | no |
| task_repository_credentials | KMS credentials for access to docker image registry | string | null | no |
| task_container_assign_public_ip | If task should have public IP address | bool | null | no |
| task_container_port | Port to be exported from container | number | null | yes |
| deployment_minimum_healthy_percent | Minimum healthy tasks in deployment | number | 50 | no |
| deployment_maximum_percent | Maximum healthy tasks in deployment | number | 200 | no |
| health_check_grace_period_seconds | Health check grace period | number | 300 | no |
| task_desired_count | Desired count of running tasks | number | 1 | no |
| service_registry_arn | See resource aws_ecs_service service_registries | string | null | no |
| deployment_controller_type | See resource aws_ecs_service deployment_controller_type | string | ECS | no | 
| rule_field | Listener rule field used in load balancer listener | string | host-header | no |
| rule_values | Listener rule value used in load balancer listener | string | "${each.key}.com" | no |
| health_check | Map of health check attributes, see aws_lb_target_group health_check resource | map(string) | {} | no |


## Outputs

| Name | Description |
|------|-------------|
| target_group_arn | Map of target groups' ARNs |
| target_group_name | Map of target groups' names |
| task_role_arn | Map of tasks' ARNs |
| task_role_name |  Map of tasks' names |
| service_sg_id | Map of services' SGs id |
| service_name | Map of services' names |
| service_arn | Map of services' ARNs |
| log_group_name | Map of lgo groups' names |








