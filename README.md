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
| vpc\_id | VPC ID | string | null | yes |
| name\_prefix | Name prefix for fargate cluster | string | null | yes |
| tags | A map of tags (key-value pairs) passed to resources | map(string) | {} | no |
| internal\_elb | If used, load balancer will be only for internal use | bool | false | no |
| subnet\_ids | Subnet IDs used for load balancer | map(string) | [] | yes |
| certificate\_arn | ARN for certificate at ACM required for HTTPS listener | string | "" | no |

## containers\_definitions

This is a special map of arguments needed for definition of tasks and services:

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| tags\_tags | A map of tags (key-value pairs) passed to resources | map(string) | {} | no |
| task\_log\_retention\_in\_days | Days TTL before logs are dropped from cloudwatch | number | 30 | no |
| task\_container\_name | Name of container, if not used, key of service is used | string | key of container\_definitions | no |
| task\_container\_image | Name of image used for task | string | nginx | no |
| task\_definition\_cpu | Amount of CPU units for a task | number | 256 | no |
| task\_definition\_memory | Amount of memory units for a task | number | 1024 | no |
| task\_container\_command | Docker command of a task | list(string) | [] | no | 
| task\_container\_environment | Docker ENV variables of a task | list(string) | [] | no |
| task\_repository\_credentials | KMS credentials for access to docker image registry | string | null | no |
| task\_container\_assign\_public\_ip | If task should have public IP address | bool | null | no |
| task\_container\_port | Port to be exported from container | number | null | yes |
| deployment\_minimum\_healthy\_percent | Minimum healthy tasks in deployment | number | 50 | no |
| deployment\_maximum\_percent | Maximum healthy tasks in deployment | number | 200 | no |
| health\_check\_grace\_period\_seconds | Health check grace period | number | 300 | no |
| task\_desired\_count | Desired count of running tasks | number | 1 | no |
| service\_registry\_arn | See resource aws\_ecs\_service service\_registries | string | null | no |
| deployment\_controller\_type | See resource aws\_ecs\_service deployment\_controller\_type | string | ECS | no | 
| rule\_field | Listener rule field used in load balancer listener | string | host-header | no |
| rule\_values | Listener rule value used in load balancer listener | string | "${each.key}.com" | no |
| health\_check | Map of health check attributes, see aws\_lb\_target\_group health\_check resource | map(string) | {} | no |
| scaling\_enable | Enable scaling for the task | bool | false | no |
| scaling\_max\_capacity | Scaling max task number | number | 4 | no |
| scaling\_min\_capacity | Scaling min task number | number | 1 | no |
| scaling\_metric | Enable scaling for the task | string ECSServiceAverageCPUUtilization or ECSServiceAverageMemoryUtilization | ECSServiceAverageCPUUtilization | no |
| scaling\_target\_value | Threshold to be reached to scale up/down | number | 70 | no |


## Outputs

| Name | Description |
|------|-------------|
| target\_group\_arn | Map of target groups' ARNs |
| target\_group\_name | Map of target groups' names |
| task\_role\_arn | Map of tasks' ARNs |
| task\_role\_name |  Map of tasks' names |
| service\_sg\_id | Map of services' SGs id |
| service\_name | Map of services' names |
| service\_arn | Map of services' ARNs |
| log\_group\_name | Map of lgo groups' names |








