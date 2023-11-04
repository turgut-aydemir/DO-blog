provider "aws" {
  region = "us-east-1" # Set your region here
}

resource "aws_ecr_repository" "turgut_ecr_repo" {
  name = "turgut-ecr-repo" # Naming your repository
}

resource "aws_ecs_cluster" "turgut_cluster" {
  name = "turgut-cluster" # Naming the cluster
}

# Provide a reference to your default VPC in us-east-1
resource "aws_default_vpc" "turgut_default_vpc" {
}

# Provide references to your default subnets
resource "aws_default_subnet" "turgut_default_subnet_a" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "turgut_default_subnet_b" {
  availability_zone = "us-east-1b"
}

resource "aws_default_subnet" "turgut_default_subnet_c" {
  availability_zone = "us-east-1c"
}

resource "aws_security_group" "turgut_load_balancer_security_group" {
  ingress {
    from_port   = 80 # Allowing traffic in from port 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

resource "aws_alb" "turgut_alb" {
  name               = "turgut-lb" # Naming your load balancer
  load_balancer_type = "application"
  subnets = [aws_default_subnet.turgut_default_subnet_a.id, aws_default_subnet.turgut_default_subnet_b.id, aws_default_subnet.turgut_default_subnet_c.id]
  security_groups = [aws_security_group.turgut_load_balancer_security_group.id]
}

resource "aws_ecs_task_definition" "turgut_task" {
  family = "turgut-task"
  container_definitions = <<DEFINITION
[
  {
    "name": "turgut-task",
    "image": "${aws_ecr_repository.turgut_ecr_repo.repository_url}",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 3000,
        "hostPort": 3000
      }
    ],
    "memory": 512,
    "cpu": 256
  }
]
DEFINITION
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  memory = 512
  cpu = 256
  execution_role_arn = aws_iam_role.turgut_ecsTaskExecutionRole.arn
}

resource "aws_iam_role" "turgut_ecsTaskExecutionRole" {
  name = "turgut-ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.turgut_assume_role_policy.json
}

data "aws_iam_policy_document" "turgut_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "turgut_ecsTaskExecutionRole_policy" {
  role = aws_iam_role.turgut_ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "turgut_service" {
  name            = "turgut-service" # Naming your service
  cluster         = aws_ecs_cluster.turgut_cluster.id
  task_definition = aws_ecs_task_definition.turgut_task.arn
  launch_type     = "FARGATE"
  desired_count   = 3 # Set the number of containers to 3

  load_balancer {
    target_group_arn = aws_lb_target_group.turgut_target_group.arn
    container_name   = aws_ecs_task_definition.turgut_task.family
    container_port   = 3000
  }

  network_configuration {
    subnets          = [aws_default_subnet.turgut_default_subnet_a.id, aws_default_subnet.turgut_default_subnet_b.id, aws_default_subnet.turgut_default_subnet_c.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.turgut_service_security_group.id]
  }
}

resource "aws_security_group" "turgut_service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = [aws_security_group.turgut_load_balancer_security_group.id]
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

resource "aws_lb_target_group" "turgut_target_group" {
  name        = "turgut-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.turgut_default_vpc.id
  health_check {
    matcher = "200,301,302"
    path = "/"
  }
}

resource "aws_lb_listener" "turgut_listener" {
  load_balancer_arn = aws_alb.turgut_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.turgut_target_group.arn
  }
}
