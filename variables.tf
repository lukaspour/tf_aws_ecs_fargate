variable "vpc_id" {
  type = string
  description = "VPC ID"
}

variable "name_prefix" {
  type = string
  description = "Name prefix for fargate cluster"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}

variable "internal_elb" {
  default = false
  type = bool
  description = "If used terraform should be internal or not"
}

variable "containers_definitions" {
  type = map(map(string))
  description = "Container setting which is than passed to fargate ecs service"
  default = {}
}

variable "subnet_ids" {
  type = list(string)
  description = "Subnet IDs used for load balancer"
  default = []
}