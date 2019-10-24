# ------------------------------------------------------------------------------
# AWS
# ------------------------------------------------------------------------------
data "aws_region" "current" {}

# ------------------------------------------------------------------------------
# Cloudwatch
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "main" {
  for_each = var.containers_definitions
  name              = each.key
  retention_in_days = lookup(var.containers_definitions[each.key], "task_log_retention_in_days", 30)
  tags              = lookup(var.containers_definitions[each.key], "task_tags", {})
}

# ------------------------------------------------------------------------------
# IAM - Task execution role, needed to pull ECR images etc.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "execution" {
  for_each = var.containers_definitions
  name               = "${each.key}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

resource "aws_iam_role_policy" "task_execution" {
  for_each = var.containers_definitions
  name   = "${each.key}-task-execution"
  role   = aws_iam_role.execution[each.key].id
  policy = data.aws_iam_policy_document.task_execution_permissions.json
}

resource "aws_iam_role_policy" "read_repository_credentials" {
  for_each = { for i, z in var.containers_definitions : i => z if lookup(z, "task_repository_credentials", "") != "" }
  name   = "${lookup(var.containers_definitions[each.key], "task_container_name", each.key)}-read-repository-credentials"
  role   = aws_iam_role.execution[each.key].id
  policy = data.aws_iam_policy_document.read_repository_credentials.json
}

# ------------------------------------------------------------------------------
# IAM - Task role, basic. Users of the module will append policies to this role
# when they use the module. S3, Dynamo permissions etc etc.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "task" {
  for_each = var.containers_definitions
  name               = "${each.key}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

resource "aws_iam_role_policy" "log_agent" {
  for_each = var.containers_definitions
  name   = "${each.key}-log-permissions"
  role   = aws_iam_role.task[each.key].id
  policy = data.aws_iam_policy_document.task_permissions.json
}

# ------------------------------------------------------------------------------
# Security groups
# ------------------------------------------------------------------------------
resource "aws_security_group" "ecs_service" {
  for_each = var.containers_definitions
  vpc_id      = var.vpc_id
  name        = "${each.key}-ecs-service-sg"
  description = "Fargate service security group"
  tags = merge(
    lookup(var.containers_definitions[each.key], "task_tags", {}),
    {
      Name = "${each.key}-sg"
    },
  )
}

resource "aws_security_group_rule" "egress_service" {
  for_each = var.containers_definitions
  security_group_id = aws_security_group.ecs_service[each.key].id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

# ------------------------------------------------------------------------------
# LB Target group
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "task" {
  for_each = var.containers_definitions
  vpc_id      = var.vpc_id
  protocol    = lookup(var.containers_definitions[each.key], "task_container_protocol", null)
  port        = lookup(var.containers_definitions[each.key], "task_container_port", null)
  target_type = "ip"

  health_check {
      enabled             = lookup(var.containers_definitions[each.key]["health_check"], "enabled", null)
      healthy_threshold   = lookup(var.containers_definitions[each.key]["health_check"], "healthy_threshold", null)
      interval            = lookup(var.containers_definitions[each.key]["health_check"], "interval", null)
      matcher             = lookup(var.containers_definitions[each.key]["health_check"], "matcher", null)
      path                = lookup(var.containers_definitions[each.key]["health_check"], "path", null)
      port                = lookup(var.containers_definitions[each.key]["health_check"], "port", null)
      protocol            = lookup(var.containers_definitions[each.key]["health_check"], "protocol", null)
      timeout             = lookup(var.containers_definitions[each.key]["health_check"], "timeout", null)
      unhealthy_threshold = lookup(var.containers_definitions[each.key]["health_check"], "unhealthy_threshold", null)
  }

  # NOTE: TF is unable to destroy a target group while a listener is attached,
  # therefor we have to create a new one before destroying the old. This also means
  # we have to let it have a random name, and then tag it with the desired name.
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    lookup(var.containers_definitions[each.key], "task_tags", {}),
    {
      Name = "${each.key}-target-lookup-${lookup(var.containers_definitions[each.key], "task_container_port", "")}"
    },
  )
}

# ------------------------------------------------------------------------------
# ECS Task/Service
# ------------------------------------------------------------------------------
locals {
  for_each = var.containers_definitions
  task_environment = [
    for k, v in lookup(var.containers_definitions[each.key], "task_container_environment", {}) : {
      name  = k
      value = v
    }
  ]
}

resource "aws_ecs_task_definition" "task" {
  for_each = var.containers_definitions

  family                   = lookup(var.containers_definitions[each.key], "task_container_name", each.key)
  execution_role_arn       = aws_iam_role.execution.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = lookup(var.containers_definitions[each.key], "task_definition_cpu", 100)
  memory                   = lookup(var.containers_definitions[each.key], "task_definition_memory", 1024)
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = <<EOF
[{
    "name": "${lookup(var.containers_definitions[each.key], "task_container_name", each.key)}",
    "image": "${lookup(var.containers_definitions[each.key], "task_container_image", "")}",
    %{if lookup(var.containers_definitions[each.key], "task_repository_credentials", "") != ""~}
    "repositoryCredentials": {
        "credentialsParameter": "${lookup(var.containers_definitions[each.key], "task_repository_credentials", null)}"
    },
    %{~endif}
    "essential": true,
    "portMappings": [
        {
            "containerPort": ${lookup(var.containers_definitions[each.key], "task_container_port", null)},
            "hostPort": ${lookup(var.containers_definitions[each.key], "task_container_port", null)},
            "protocol":"tcp"
        }
    ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${each.key}",
            "awslogs-region": "${data.aws_region.current.name}",
            "awslogs-stream-prefix": "container"
        }
    },
    "command": ${jsonencode(lookup(var.containers_definitions[each.key], "task_container_command", null))},
    "environment": ${jsonencode(local.task_environment[each.key])}
}]
EOF
}

resource "aws_ecs_service" "service_with_no_service_registries" {
  for_each = { for i, z in var.containers_definitions : i => z if lookup(z, "service_registry_arn", "") != "" }

  depends_on                         = [null_resource.lb_exists]
  name                               = each.key
  cluster                            = var.cluster_id
  task_definition                    = aws_ecs_task_definition.task[each.key].arn
  desired_count                      = lookup(var.containers_definitions[each.key], "task_desired_count", 1)
  launch_type                        = "FARGATE"
  deployment_minimum_healthy_percent = lookup(var.containers_definitions[each.key], "deployment_minimum_healthy_percent", 50)
  deployment_maximum_percent         = lookup(var.containers_definitions[each.key], "deployment_maximum_percent", 200)
  health_check_grace_period_seconds  = lookup(var.containers_definitions[each.key], "health_check_grace_period_seconds", 300)

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = lookup(var.containers_definitions[each.key], "task_container_assign_public_ip", null)
  }

  load_balancer {
    container_name   = lookup(var.containers_definitions[each.key], "task_container_name", null)
    container_port   = lookup(var.containers_definitions[each.key], "task_container_port", null)
    target_group_arn = aws_lb_target_group.task[each.key].arn
  }

  deployment_controller {
    # The deployment controller type to use. Valid values: CODE_DEPLOY, ECS.
    type = lookup(var.containers_definitions[each.key], "deployment_controller_type", "ECS")
  }

  service_registries {
      registry_arn   = lookup(var.containers_definitions[each.key], "service_registry_arn", null)
      container_port = lookup(var.containers_definitions[each.key], "task_container_port", null)
      container_name = lookup(var.containers_definitions[each.key], "task_container_name", each.key)
  }
}

resource "aws_ecs_service" "service" {
  for_each = { for i, z in var.containers_definitions : i => z if lookup(z, "service_registry_arn", "") == "" }

  depends_on                         = [null_resource.lb_exists]
  name                               = each.key
  cluster                            = var.cluster_id
  task_definition                    = aws_ecs_task_definition.task[each.key].arn
  desired_count                      = lookup(var.containers_definitions[each.key], "task_desired_count", 1)
  launch_type                        = "FARGATE"
  deployment_minimum_healthy_percent = lookup(var.containers_definitions[each.key], "deployment_minimum_healthy_percent", 50)
  deployment_maximum_percent         = lookup(var.containers_definitions[each.key], "deployment_maximum_percent", 200)
  health_check_grace_period_seconds  = lookup(var.containers_definitions[each.key], "health_check_grace_period_seconds", 300)

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = var.task_container_assign_public_ip
  }

  load_balancer {
    container_name   = lookup(var.containers_definitions[each.key], "task_container_name", null)
    container_port   = lookup(var.containers_definitions[each.key], "task_container_port", null)
    target_group_arn = aws_lb_target_group.task[each.key].arn
  }

  deployment_controller {
    # The deployment controller type to use. Valid values: CODE_DEPLOY, ECS.
    type = lookup(var.containers_definitions[each.key], "deployment_controller_type", "ECS")
  }
}

# HACK: The workaround used in ecs/service does not work for some reason in this module, this fixes the following error:
# "The target group with targetGroupArn arn:aws:elasticloadbalancing:... does not have an associated load balancer."
# see https://github.com/hashicorp/terraform/issues/12634.
# Service depends on this resources which prevents it from being created until the LB is ready
resource "null_resource" "lb_exists" {
  triggers = {
    alb_name = var.lb_arn
  }
}

